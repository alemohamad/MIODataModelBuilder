//
//  EntitySidebar.swift
//  MIODataModelEditor
//
//  Created by MIO Research Labs on 2026.
//

import SwiftUI

/// The model outline: entities in either the flat or the inheritance style,
/// followed by the configurations.
struct EntitySidebar: View {
    @Binding var model: DataModel
    @Bindable var selection: EditorSelection

    @FocusState private var filterFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            List(selection: sidebarSelection) {
                Section {
                    if selection.outlineStyle && selection.searchText.isEmpty {
                        EntityOutlineRows(nodes: model.entityOutline,
                                          selection: selection,
                                          onDelete: deleteEntity)
                    } else {
                        ForEach(filteredEntities) { entity in
                            EntityRow(entity: entity,
                                      onDelete: { deleteEntity(entity) },
                                      onClick: { selection.select(entityNamed: entity.name) })
                        }
                    }
                } header: {
                    Text("ENTITIES")
                        .padding(.leading, 20)
                }

                Section {
                    ForEach(model.sidebarConfigurations) { configuration in
                        ConfigurationRow(configuration: configuration,
                                         onClick: { selection.select(configurationNamed: configuration.name) })
                    }
                } header: {
                    Text("CONFIGURATIONS")
                        .padding(.leading, 20)
                }
            }
            .listStyle(.sidebar)

            Divider()
            SidebarStyleBar(outlineStyle: $selection.outlineStyle, onAddEntity: addEntity)
        }
        .searchable(text: $selection.searchText, placement: .sidebar, prompt: "Filter entities")
        .searchFocused($filterFocused)
        .onChange(of: selection.filterFocusRequests) { filterFocused = true }
    }

    /// Wraps the list's selection so picking a row also drops the property
    /// selection. See `EditorSelection.selectSidebarItem`.
    private var sidebarSelection: Binding<EditorSelection.SidebarItem?> {
        Binding(get: { selection.item },
                set: { selection.selectSidebarItem($0) })
    }

    private var filteredEntities: [ModelEntity] {
        let all = model.entities.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        guard !selection.searchText.isEmpty else { return all }
        return all.filter { $0.name.localizedCaseInsensitiveContains(selection.searchText) }
    }

    private func deleteEntity(_ entity: ModelEntity) {
        let name = entity.name
        model.entities.removeAll { $0.name == name }
        if selection.entityName == name { selection.selectSidebarItem(nil) }
    }

    private func addEntity() {
        selection.select(entityNamed: model.addEntity())
    }
}

#Preview("Flat") {
    @Previewable @State var model = PreviewSamples.model

    EntitySidebar(model: $model, selection: EditorSelection(entityName: "Employee"))
        .frame(width: 260, height: 460)
}

#Preview("Outline") {
    @Previewable @State var model = PreviewSamples.model
    let selection = EditorSelection(entityName: "Employee")
    selection.outlineStyle = true

    return EntitySidebar(model: $model, selection: selection)
        .frame(width: 260, height: 460)
}

#Preview("Configuration selected") {
    @Previewable @State var model = PreviewSamples.model

    EntitySidebar(model: $model,
                  selection: EditorSelection(item: .configuration(ModelConfiguration.defaultName)))
        .frame(width: 260, height: 460)
}

#Preview("Empty model") {
    @Previewable @State var model = DataModel()

    EntitySidebar(model: $model, selection: EditorSelection())
        .frame(width: 260, height: 460)
}
