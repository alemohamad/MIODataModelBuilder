//
//  FetchedPropertyInspector.swift
//  MIODataModelEditor
//
//  Created by MIO Research Labs on 2026.
//

import SwiftUI

/// Inspector for the selected fetched property.
struct FetchedPropertyInspector: View {
    @Binding var property: ModelFetchedProperty
    let entityNames: [String]

    var body: some View {
        Section("Fetched Property") {
            LabeledContent("Name") {
                CommittingTextField("Name", value: property.name) { property.name = $0 }
            }
            Toggle("Optional", isOn: $property.optional.asFlag)
        }

        Section("Fetch Request") {
            LabeledContent("Request Name") {
                CommittingTextField("Request Name", value: property.fetchRequestName ?? "", prompt: "No Name") {
                    property.fetchRequestName = $0.isEmpty ? nil : $0
                    property.hasFetchRequestElement = true
                }
            }
            Picker("Target", selection: $property.fetchTargetEntityName.orEmpty) {
                Text("No Entity").tag("")
                ForEach(entityNames, id: \.self) { name in
                    Text(name).tag(name)
                }
            }
            LabeledContent("Predicate") {
                CommittingTextField("Predicate", value: property.predicateString ?? "", prompt: "Predicate") {
                    property.predicateString = $0.isEmpty ? nil : $0
                    // The predicate lives on a nested <fetchRequest>, so setting
                    // one has to bring the element into existence.
                    property.hasFetchRequestElement = true
                }
            }
        }

        Section("User Info") {
            UserInfoTable(userInfo: $property.userInfo)
        }
    }
}

#Preview("With a predicate") {
    @Previewable @State var property = PreviewSamples.fetchedProperty

    Form { FetchedPropertyInspector(property: $property, entityNames: PreviewSamples.entityNames) }
        .formStyle(.grouped)
        .frame(width: 340, height: 460)
}

#Preview("Blank") {
    @Previewable @State var property = ModelFetchedProperty(name: "fetchedProperty")

    Form { FetchedPropertyInspector(property: $property, entityNames: PreviewSamples.entityNames) }
        .formStyle(.grouped)
        .frame(width: 340, height: 460)
}
