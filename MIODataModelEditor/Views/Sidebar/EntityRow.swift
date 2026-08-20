//
//  EntityRow.swift
//  MIODataModelEditor
//
//  Created by MIO Research Labs on 2026.
//

import SwiftUI

/// One entity in the sidebar list.
struct EntityRow: View {
    let entity: ModelEntity
    /// Right-click actions. Optional so the previews stay one-liners.
    var onDelete: (() -> Void)? = nil
    /// Called on every click, including one on the row that is already
    /// selected. Optional so the previews stay one-liners.
    var onClick: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 6) {
            TypeBadge(style: .entity)
            Text(entity.name.isEmpty ? "Untitled" : entity.name)
                .lineLimit(1)
                .truncationMode(.tail)
                .italic(entity.isAbstract == true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .tag(EditorSelection.SidebarItem.entity(entity.name))
        // List's selection binding only fires when the value CHANGES, so
        // clicking the entity that is already selected never reaches it and an
        // attribute stays selected in the inspector. This runs on every click.
        // Simultaneous, so the list still gets the click it needs for keyboard
        // navigation and range selection.
        .simultaneousGesture(TapGesture().onEnded { onClick?() })
        .contextMenu {
            if let onDelete {
                Button("Delete Entity", systemImage: "trash", role: .destructive, action: onDelete)
                    .keyboardShortcut(.delete, modifiers: .command)
            }
        }
    }
}

#Preview("Concrete, abstract and unnamed") {
    List {
        EntityRow(entity: PreviewSamples.model.entities[1])
        EntityRow(entity: PreviewSamples.model.entities[0])
        EntityRow(entity: ModelEntity())
    }
    .frame(width: 240, height: 140)
}

#Preview("Concrete, abstract and unnamed") {
    List {
        EntityRow(entity: PreviewSamples.model.entities[1])
        EntityRow(entity: PreviewSamples.model.entities[0])
        EntityRow(entity: ModelEntity())
    }
    .frame(width: 240, height: 140)
    .listStyle(.sidebar)
}
