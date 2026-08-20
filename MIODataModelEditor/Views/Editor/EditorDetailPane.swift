//
//  EditorDetailPane.swift
//  MIODataModelEditor
//
//  Created by MIO Research Labs on 2026.
//

import SwiftUI

/// The detail column: the tables for whatever the sidebar has selected.
struct EditorDetailPane: View {
    @Binding var model: DataModel
    @Bindable var selection: EditorSelection
    let entityNames: [String]
    let relationshipNames: (String) -> [String]

    var body: some View {
        content
            .frame(minWidth: EditorLayout.detailMinWidth)
    }

    @ViewBuilder
    private var content: some View {
        switch selection.item {
        case .entity(let name):
            if let index = model.index(ofEntityNamed: name) {
                EntityDetailView(entity: $model.entities[index],
                                 selection: selection,
                                 entityNames: entityNames,
                                 relationshipNames: relationshipNames)
            } else {
                // The selected entity was renamed or deleted out from under us.
                ContentUnavailableView("Entity Not Found",
                                       systemImage: "questionmark.square.dashed",
                                       description: Text("\(name) is no longer in this model."))
            }

        case .configuration(let name):
            ConfigurationDetailView(model: $model,
                                    selection: selection,
                                    configurationName: name)

        case nil:
            ContentUnavailableView("Nothing Selected",
                                   systemImage: "square.stack.3d.up",
                                   description: Text("Pick an entity or a configuration in the sidebar."))
        }
    }
}

#Preview("Entity selected") {
    @Previewable @State var model = PreviewSamples.model

    EditorDetailPane(model: $model,
                     selection: EditorSelection(entityName: "Employee"),
                     entityNames: PreviewSamples.entityNames,
                     relationshipNames: PreviewSamples.relationshipNames)
        .frame(width: 820, height: 560)
}

#Preview("Configuration selected") {
    @Previewable @State var model = PreviewSamples.model

    EditorDetailPane(model: $model,
                     selection: EditorSelection(item: .configuration(ModelConfiguration.defaultName)),
                     entityNames: PreviewSamples.entityNames,
                     relationshipNames: PreviewSamples.relationshipNames)
        .frame(width: 820, height: 560)
}

#Preview("Nothing selected") {
    @Previewable @State var model = PreviewSamples.model

    EditorDetailPane(model: $model,
                     selection: EditorSelection(),
                     entityNames: [],
                     relationshipNames: { _ in [] })
        .frame(width: 820, height: 560)
}
