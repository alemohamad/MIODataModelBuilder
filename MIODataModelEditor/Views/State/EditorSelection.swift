//
//  EditorSelection.swift
//  MIODataModelEditor
//
//  Created by MIO Research Labs on 2026.
//

import Observation

/// What the editor is currently showing.
///
/// Pure view state, which is what `@Observable` is for here. The document is a
/// value type and needs no observation of its own.
///
/// Everything is keyed by name rather than by identifier so it survives an
/// undo, which restores a previous value of the document rather than mutating
/// the current one.
@Observable
final class EditorSelection {
    /// A row in the sidebar. Entities and configurations share one list, so
    /// they share one selection.
    enum SidebarItem: Equatable, Hashable {
        case entity(String)
        case configuration(String)

        var entityName: String? {
            if case .entity(let name) = self { return name }
            return nil
        }

        var configurationName: String? {
            if case .configuration(let name) = self { return name }
            return nil
        }
    }

    enum PropertyKind: Equatable, Hashable { case attribute, relationship, fetchedProperty }

    struct PropertyKey: Equatable, Hashable {
        var name: String
        var kind: PropertyKind
    }

    var item: SidebarItem?
    var property: PropertyKey?

    /// Set when the user has explicitly deselected inside the detail pane, by
    /// clicking one of the blank rows under a table.
    ///
    /// The entity stays open in the editor, so the tables are still there to
    /// click; only the inspector empties. Clearing `item` instead would take
    /// the tables away along with the row that was just clicked.
    private(set) var isCleared = false

    /// Bumped to ask the sidebar to put the keyboard in the filter field.
    /// A counter rather than a flag, so two requests in a row both land.
    private(set) var filterFocusRequests = 0

    /// Sidebar mode: the flat alphabetical list, or the parent/child outline.
    var outlineStyle: Bool = false
    var searchText: String = ""

    init(item: SidebarItem? = nil, property: PropertyKey? = nil) {
        self.item = item
        self.property = property
    }

    /// Convenience for the common case of selecting an entity by name.
    convenience init(entityName: String?, property: PropertyKey? = nil) {
        self.init(item: entityName.map { .entity($0) }, property: property)
    }

    var entityName: String? { item?.entityName }
    var configurationName: String? { item?.configurationName }

    func select(entityNamed name: String) {
        item = .entity(name)
        clearProperty()
    }

    func select(configurationNamed name: String) {
        item = .configuration(name)
        clearProperty()
    }

    func select(propertyNamed name: String, kind: PropertyKind) {
        property = PropertyKey(name: name, kind: kind)
        isCleared = false
    }

    /// What the sidebar list's selection binding writes through.
    ///
    /// Picking a sidebar row always drops the property selection, or the
    /// inspector would go on showing an attribute of the entity the user just
    /// navigated away from.
    func selectSidebarItem(_ newItem: SidebarItem?) {
        item = newItem
        clearProperty()
    }

    /// Nothing selected at all: the detail pane keeps its tables, the inspector
    /// shows "No Selection".
    func deselectAll() {
        property = nil
        isCleared = true
    }

    func clearProperty() {
        property = nil
        isCleared = false
    }

    func focusFilter() {
        filterFocusRequests += 1
    }

    func isSelected(_ name: String, _ kind: PropertyKind) -> Bool {
        property == PropertyKey(name: name, kind: kind)
    }
}
