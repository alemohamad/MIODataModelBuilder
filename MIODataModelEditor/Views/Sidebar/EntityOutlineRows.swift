//
//  EntityOutlineRows.swift
//  MIODataModelEditor
//
//  Created by MIO Research Labs on 2026.
//

import SwiftUI

/// The inheritance outline, expanded on open.
///
/// `OutlineGroup` is shorter but always starts collapsed, and takes no argument
/// to change that. Two mutually recursive views do the same job: the recursion
/// type-checks because each side is a concrete nominal type, which is exactly
/// what a self-referential `@ViewBuilder` *function* lacks.
struct EntityOutlineRows: View {
    let nodes: [EntityNode]
    let selection: EditorSelection
    var onDelete: ((ModelEntity) -> Void)? = nil

    var body: some View {
        ForEach(nodes) { node in
            if let children = node.children, !children.isEmpty {
                EntityOutlineBranch(node: node, children: children, selection: selection, onDelete: onDelete)
            } else {
                EntityOutlineLeaf(entity: node.entity, selection: selection, onDelete: onDelete)
            }
        }
    }
}

/// An entity with subentities: a disclosure group holding the row.
private struct EntityOutlineBranch: View {
    let node: EntityNode
    let children: [EntityNode]
    let selection: EditorSelection
    var onDelete: ((ModelEntity) -> Void)?

    /// The outline exists to show the hierarchy. Opening it collapsed shows
    /// less than the flat list it replaced, so every branch starts open and
    /// stays wherever the user puts it afterwards.
    @State private var isExpanded = true

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            EntityOutlineRows(nodes: children, selection: selection, onDelete: onDelete)
        } label: {
            EntityOutlineLeaf(entity: node.entity, selection: selection, onDelete: onDelete)
        }
    }
}

/// One row, wherever it sits in the tree.
private struct EntityOutlineLeaf: View {
    let entity: ModelEntity
    let selection: EditorSelection
    var onDelete: ((ModelEntity) -> Void)?

    var body: some View {
        EntityRow(entity: entity,
                  onDelete: onDelete.map { delete in { delete(entity) } },
                  onClick: { selection.select(entityNamed: entity.name) })
    }
}

#Preview("Outline, expanded on open") {
    @Previewable @State var model = PreviewSamples.model

    List(selection: .constant(EditorSelection.SidebarItem?.none)) {
        EntityOutlineRows(nodes: model.entityOutline, selection: EditorSelection())
    }
    .listStyle(.sidebar)
    .frame(width: 260, height: 320)
}
