//
//  EntityNode.swift
//  MIODataModelEditor
//
//  Created by MIO Research Labs on 2026.
//

import Foundation

/// One node of the sidebar's inheritance outline.
///
/// A plain value tree rather than a recursive view, because `OutlineGroup`
/// reaches children through a key path and a self-referential `@ViewBuilder`
/// function cannot be type-checked: its opaque return type would be defined in
/// terms of itself.
struct EntityNode: Identifiable {
    var entity: ModelEntity
    var children: [EntityNode]?

    /// The entity name doubles as the selection key.
    var id: String { entity.name }
}

extension DataModel {
    /// The entity inheritance tree, sorted at every level.
    ///
    /// A malformed model can name itself, or a cycle, as its own parent. The
    /// visited set keeps that from hanging the sidebar.
    var entityOutline: [EntityNode] {
        var visited: Set<String> = []

        func build(_ entity: ModelEntity) -> EntityNode {
            guard visited.insert(entity.name).inserted else {
                return EntityNode(entity: entity, children: nil)
            }
            let children = self.children(of: entity)
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
                .map(build)
            return EntityNode(entity: entity, children: children.isEmpty ? nil : children)
        }

        return rootEntities
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            .map(build)
    }
}
