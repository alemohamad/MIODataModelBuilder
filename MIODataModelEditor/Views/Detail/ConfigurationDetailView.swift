//
//  ConfigurationDetailView.swift
//  MIODataModelEditor
//
//  Created by MIO Research Labs on 2026.
//

import SwiftUI

/// The Entities table Xcode shows when a configuration is selected.
///
/// For `Default` this is simply every entity in the model, since the implicit
/// configuration contains all of them. For a named configuration the leading
/// checkbox is the membership toggle, which is the whole point of having one.
struct ConfigurationDetailView: View {
    @Binding var model: DataModel
    @Bindable var selection: EditorSelection
    let configurationName: String

    @State private var isExpanded = true

    static let nameWidth: CGFloat = 220
    static let abstractWidth: CGFloat = 70
    static let classWidth: CGFloat = 220

    private var isDefault: Bool { configurationName == ModelConfiguration.defaultName }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                PropertySection(title: "Entities",
                                isExpanded: $isExpanded,
                                columns: columns,
                                onAdd: addEntity,
                                onRemove: nil) {
                    ForEach($model.entities.sorted) { $entity in
                        ConfigurationEntityRow(entity: $entity,
                                               selection: selection,
                                               membership: isDefault ? nil : membership(for: entity.name),
                                               renameEntity: { rename(entity.name, to: $0) })
                    }
                    ForEach(EmptyPropertyRow.padding(for: model.entities.count), id: \.self) { _ in
                        EmptyPropertyRow()
                    }
                }
            }
            .padding(16)
            // A ScrollView centres content narrower than itself. Collapsing every
            // section leaves only the headers, which is narrow enough to drift to
            // the middle of the pane, so the content is stretched and pinned
            // leading instead.
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(configurationName)
    }

    private var columns: [PropertyColumn] {
        var columns = [PropertyColumn]()
        if !isDefault { columns.append(PropertyColumn("In", 30)) }
        columns.append(PropertyColumn("Entity", Self.nameWidth))
        columns.append(PropertyColumn("Abstract", Self.abstractWidth))
        columns.append(PropertyColumn("Class", Self.classWidth))
        return columns
    }

    private func addEntity() {
        selection.select(entityNamed: model.addEntity())
    }

    /// Membership of a named configuration, as a toggle.
    /// Renames the entity everywhere it is named, and keeps it selected: the
    /// selection is held by name, so the row would otherwise deselect itself.
    private func rename(_ oldName: String, to newName: String) {
        model.renameEntity(named: oldName, to: newName)
        selection.select(entityNamed: newName)
    }

    private func membership(for entityName: String) -> Binding<Bool> {
        Binding(get: {
            model.configuration(named: configurationName)?.memberEntityNames.contains(entityName) ?? false
        }, set: { included in
            guard let index = model.indexOfConfiguration(named: configurationName) else { return }
            if included {
                if !model.configurations[index].memberEntityNames.contains(entityName) {
                    model.configurations[index].memberEntityNames.append(entityName)
                }
            } else {
                model.configurations[index].memberEntityNames.removeAll { $0 == entityName }
            }
        })
    }
}

private extension Binding where Value == [ModelEntity] {
    /// The entities in display order, still writable through the original
    /// array so the rows stay editable.
    var sorted: [Binding<ModelEntity>] {
        wrappedValue.indices
            .sorted { wrappedValue[$0].name.localizedStandardCompare(wrappedValue[$1].name) == .orderedAscending }
            .map { index in
                Binding<ModelEntity>(get: { wrappedValue[index] },
                                     set: { wrappedValue[index] = $0 })
            }
    }
}

#Preview("Default") {
    @Previewable @State var model = PreviewSamples.model

    ConfigurationDetailView(model: $model,
                            selection: EditorSelection(),
                            configurationName: ModelConfiguration.defaultName)
        .frame(width: 700, height: 420)
}

#Preview("Named configuration with membership") {
    @Previewable @State var model: DataModel = {
        var model = PreviewSamples.model
        var remote = ModelConfiguration(name: "Remote")
        remote.memberEntityNames = ["Employee"]
        model.configurations = [remote]
        return model
    }()

    ConfigurationDetailView(model: $model,
                            selection: EditorSelection(),
                            configurationName: "Remote")
        .frame(width: 740, height: 420)
}

#Preview("Empty model") {
    @Previewable @State var model = DataModel()

    ConfigurationDetailView(model: $model,
                            selection: EditorSelection(),
                            configurationName: ModelConfiguration.defaultName)
        .frame(width: 700, height: 360)
}
