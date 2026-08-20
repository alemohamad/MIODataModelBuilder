//
//  ConfigurationEntityRow.swift
//  MIODataModelEditor
//
//  Created by MIO Research Labs on 2026.
//

import SwiftUI

/// One row of the Entities table shown for a configuration.
///
/// Clicking the row selects the entity, which is how Xcode lets you jump from
/// the configuration overview into editing an entity.
struct ConfigurationEntityRow: View {
    @Binding var entity: ModelEntity
    @Bindable var selection: EditorSelection
    /// `nil` for `Default`, which contains every entity and has nothing to
    /// toggle.
    let membership: Binding<Bool>?
    /// Renaming touches every reference to the entity, so the owner does it.
    let renameEntity: (String) -> Void

    var body: some View {
        PropertyRow(isSelected: selection.entityName == entity.name,
                    onSelect: { selection.select(entityNamed: entity.name) }) {
            if let membership {
                Toggle("", isOn: membership)
                    .labelsHidden()
                    .frame(width: 30, alignment: .leading)
            }

            HStack(spacing: 6) {
                TypeBadge(style: .entity)
                CommittingTextField("Name", value: entity.name) { renameEntity($0) }
                .textFieldStyle(.plain)
            }
            .frame(width: ConfigurationDetailView.nameWidth, alignment: .leading)

            Toggle("", isOn: $entity.isAbstract.asFlag)
                .labelsHidden()
                .frame(width: ConfigurationDetailView.abstractWidth, alignment: .leading)

            CommittingTextField("Class", value: entity.representedClassName ?? "", prompt: entity.name) {
                entity.representedClassName = $0.isEmpty ? nil : $0
            }
            .textFieldStyle(.plain)
            .frame(width: ConfigurationDetailView.classWidth, alignment: .leading)
        }
    }
}

#Preview("Default, no membership column") {
    @Previewable @State var entity = PreviewSamples.entity

    ConfigurationEntityRow(entity: $entity,
                           selection: EditorSelection(entityName: "Employee"),
                           membership: nil,
                           renameEntity: { _ in })
        .padding()
        .frame(width: 620)
}

#Preview("Named configuration, with membership") {
    @Previewable @State var entity = PreviewSamples.entity
    @Previewable @State var included = true

    ConfigurationEntityRow(entity: $entity,
                           selection: EditorSelection(),
                           membership: $included,
                           renameEntity: { _ in })
        .padding()
        .frame(width: 660)
}
