//
//  RelationshipInspector.swift
//  MIODataModelEditor
//
//  Created by MIO Research Labs on 2026.
//

import SwiftUI

/// Inspector for the selected relationship.
struct RelationshipInspector: View {
    @Binding var relationship: ModelRelationship
    let entityNames: [String]
    let relationshipNames: (String) -> [String]

    var body: some View {
        Section("Relationship") {
            LabeledContent("Name") {
                CommittingTextField("Name", value: relationship.name) { relationship.name = $0 }
                    .textFieldStyle(.plain)
                    .labelsHidden()
            }
            Picker("Destination", selection: $relationship.destination) {
                Text("No Value").tag("")
                ForEach(entityNames, id: \.self) { name in
                    Text(name).tag(name)
                }
            }
            Picker("Inverse", selection: $relationship.inverse) {
                Text("No Inverse").tag("")
                ForEach(relationshipNames(relationship.destinationEntityName ?? ""), id: \.self) { name in
                    Text(name).tag(name)
                }
            }
            Toggle("Optional", isOn: $relationship.optional.asFlag)
            Toggle("Transient", isOn: $relationship.transient.asFlag)
        }

        Section("Cardinality") {
            Picker("Type", selection: cardinality) {
                Text("To One").tag(false)
                Text("To Many").tag(true)
            }
            .pickerStyle(.segmented)

            if relationship.isToMany {
                Toggle("Ordered", isOn: $relationship.ordered.asFlag)
                LabeledContent("Count") {
                    HStack {
                        CommittingTextField("Min", value: relationship.minCount ?? "", prompt: "No Min") {
                            relationship.minCount = $0.isEmpty ? nil : $0
                        }
                        CommittingTextField("Max", value: relationship.maxCount ?? "", prompt: "No Max") {
                            relationship.maxCount = $0.isEmpty ? nil : $0
                        }
                    }
                }
            }

            Picker("Delete Rule", selection: $relationship.deletionRule) {
                ForEach(DeletionRule.allCases) { rule in
                    Text(rule.rawValue).tag(rule)
                }
            }
        }

        Section("Advanced") {
            Toggle("Index in Spotlight", isOn: $relationship.spotlightIndexingEnabled.asFlag)
        }

        Section("User Info") {
            UserInfoTable(userInfo: $relationship.userInfo)
        }

        VersioningSection(versionHashModifier: $relationship.versionHashModifier,
                          renamingIdentifier: $relationship.renamingIdentifier)
    }

    /// One mutation through the binding, so the two fields the file couples
    /// cannot be written separately. See `ModelRelationship.setToMany`.
    private var cardinality: Binding<Bool> {
        Binding(get: { relationship.isToMany },
                set: { relationship.setToMany( $0 ) })
    }
}

#Preview("To one") {
    @Previewable @State var relationship = PreviewSamples.entity.relationships[0]

    Form {
        RelationshipInspector(relationship: $relationship,
                              entityNames: PreviewSamples.entityNames,
                              relationshipNames: PreviewSamples.relationshipNames)
    }
    .formStyle(.columns)
    .padding(.horizontal, 14)
    .frame(width: 340, height: 640, alignment: .top)
}

#Preview("To many") {
    @Previewable @State var relationship = PreviewSamples.entity.relationships[1]

    Form {
        RelationshipInspector(relationship: $relationship,
                              entityNames: PreviewSamples.entityNames,
                              relationshipNames: PreviewSamples.relationshipNames)
    }
    .formStyle(.grouped)
    .frame(width: 340, height: 640)
}
