//
//  RelationshipRow.swift
//  MIODataModelEditor
//
//  Created by MIO Research Labs on 2026.
//

import SwiftUI

/// One row of the Relationships table: badge, editable name, destination and
/// inverse popups.
struct RelationshipRow: View {
    @Binding var relationship: ModelRelationship
    @Bindable var selection: EditorSelection
    let entityNames: [String]
    let relationshipNames: (String) -> [String]
    
    static let nameWidth: CGFloat = 200
    static let popupWidth: CGFloat = 140
    
    var body: some View {
        PropertyRow(isSelected: selection.isSelected(relationship.name, .relationship),
                    onSelect: { selection.select(propertyNamed: relationship.name, kind: .relationship) }) {
            HStack(spacing: 6) {
                TypeBadge(style: .relationship(toMany: relationship.isToMany))
                CommittingTextField("Name", value: relationship.name) { newName in
                    relationship.name = newName
                    selection.select(propertyNamed: newName, kind: .relationship)
                }
                .textFieldStyle(.plain)
            }
            .frame(width: Self.nameWidth, alignment: .leading)
            
            Picker("", selection: $relationship.destination) {
                Text("No Destination").tag("")
                ForEach(entityNames, id: \.self) { name in
                    Text(name).tag(name)
                }
            }
            .buttonStyle(.borderless)
            .padding(.leading, -10)
            .frame(width: Self.popupWidth, alignment: .leading)
            
            Picker("", selection: $relationship.inverse) {
                Text("No Inverse").tag("")
                ForEach(relationshipNames(relationship.destinationEntityName ?? ""), id: \.self) { name in
                    Text(name).tag(name)
                }
            }
            .buttonStyle(.borderless)
            .padding(.leading, -10)
            .frame(width: Self.popupWidth, alignment: .leading)
        }
    }
}

extension Binding where Value == ModelRelationship {
    /// The destination as a plain string, clearing the inverse when it changes.
    ///
    /// The inverse names a relationship on the *old* target, so leaving it in
    /// place after a retarget would leave a dangling reference behind.
    var destination: Binding<String> {
        Binding<String>(get: { wrappedValue.destinationEntityName ?? "" },
                        set: { newValue in
                            wrappedValue.destinationEntityName = newValue.isEmpty ? nil : newValue
                            wrappedValue.inverseName = nil
                            wrappedValue.inverseEntityName = nil
                        })
    }

    /// The inverse as a plain string, keeping `inverseEntity` in step with it.
    var inverse: Binding<String> {
        Binding<String>(get: { wrappedValue.inverseName ?? "" },
                        set: { newValue in
                            wrappedValue.inverseName = newValue.isEmpty ? nil : newValue
                            wrappedValue.inverseEntityName =
                                newValue.isEmpty ? nil : wrappedValue.destinationEntityName
                        })
    }
}

#Preview("To one and to many") {
    @Previewable @State var entity = PreviewSamples.entity
    let selection = EditorSelection()
    selection.select(propertyNamed: "reports", kind: .relationship)

    return VStack(alignment: .leading, spacing: 0) {
        ForEach($entity.relationships) { $relationship in
            RelationshipRow(relationship: $relationship,
                            selection: selection,
                            entityNames: PreviewSamples.entityNames,
                            relationshipNames: PreviewSamples.relationshipNames)
        }
    }
    .padding()
}

#Preview("No Value") {
    @Previewable @State var relationship = ModelRelationship(name: "orphan")

    RelationshipRow(relationship: $relationship,
                    selection: EditorSelection(),
                    entityNames: PreviewSamples.entityNames,
                    relationshipNames: PreviewSamples.relationshipNames)
        .padding()
}
