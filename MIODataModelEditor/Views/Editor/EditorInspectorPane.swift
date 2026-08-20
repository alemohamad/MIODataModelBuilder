//
//  EditorInspectorPane.swift
//  MIODataModelEditor
//
//  Created by MIO Research Labs on 2026.
//

import SwiftUI

/// The inspector column: the inspector for the current selection.
struct EditorInspectorPane: View {
    @Binding var model: DataModel
    @Bindable var selection: EditorSelection
    let entityNames: [String]
    let relationshipNames: (String) -> [String]
    let attributesInEntity: (String) -> [ModelAttribute]

    var body: some View {
        if selection.isCleared {
            // Deselected inside the detail pane: the entity is still open there,
            // but the inspector has nothing to show.
            noSelection
        } else {
            target
        }
    }

    @ViewBuilder
    private var target: some View {
        switch selection.item {
        case .entity(let name):
            if let index = model.index(ofEntityNamed: name) {
                InspectorPanel(entity: $model.entities[index],
                               selection: selection,
                               entityNames: entityNames,
                               relationshipNames: relationshipNames,
                               attributesInEntity: attributesInEntity,
                               renameEntity: { rename(name, to: $0) })
            } else {
                noSelection
            }

        case .configuration(let name):
            Form {
                ConfigurationInspector(model: $model, configurationName: name)
            }
            .formStyle(.grouped)

        case nil:
            noSelection
        }
    }

    /// Renames the entity everywhere it is named, and keeps it selected.
    ///
    /// The selection is held by name, so without the second line the rename
    /// deselects the entity: the sidebar row loses its highlight and this
    /// inspector falls back to "No Selection" the moment the rename commits.
    private func rename(_ oldName: String, to newName: String) {
        model.renameEntity(named: oldName, to: newName)
        selection.select(entityNamed: newName)
    }

    private var noSelection: some View {
        Text("No Selection")
            .font(.title3)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview("Entity selected") {
    @Previewable @State var model = PreviewSamples.model

    EditorInspectorPane(model: $model,
                        selection: EditorSelection(entityName: "Employee"),
                        entityNames: PreviewSamples.entityNames,
                        relationshipNames: PreviewSamples.relationshipNames,
                        attributesInEntity: PreviewSamples.attributes(inEntityNamed:))
        .frame(width: 340, height: 700)
}

#Preview("Configuration selected") {
    @Previewable @State var model = PreviewSamples.model

    EditorInspectorPane(model: $model,
                        selection: EditorSelection(item: .configuration(ModelConfiguration.defaultName)),
                        entityNames: PreviewSamples.entityNames,
                        relationshipNames: PreviewSamples.relationshipNames,
                        attributesInEntity: PreviewSamples.attributes(inEntityNamed:))
        .frame(width: 340, height: 400)
}

#Preview("Nothing selected") {
    @Previewable @State var model = PreviewSamples.model

    EditorInspectorPane(model: $model,
                        selection: EditorSelection(),
                        entityNames: [],
                        relationshipNames: { _ in [] },
                        attributesInEntity: { _ in [] })
        .frame(width: 340, height: 400)
}
