//
//  KeyboardShortcutsView.swift
//  MIODataModelEditor
//
//  Created by MIO Research Labs on 2026.
//

import SwiftUI

/// The Help menu's shortcut list.
///
/// This replaces the stock "Data Model Editor Help", which opens an alert saying
/// help is not available: the app ships no help book, and a development tool
/// does not need one. A cheat sheet is the useful thing to put in its place.
///
/// The rows are written out rather than derived from ``EditorCommands``, because
/// a `Commands` body cannot be walked at runtime. Keep the two in step by hand.
struct KeyboardShortcutsView: View {
    private struct Shortcut: Identifiable {
        var id: String { keys + action }
        let keys: String
        let symbol: String
        let action: String
    }

    private struct Group: Identifiable {
        var id: String { title }
        let title: String
        let shortcuts: [Shortcut]
    }

    private static let groups = [
        Group(title: "File", shortcuts: [
            Shortcut(keys: "⇧⌘N", symbol: "cylinder.split.1x2.fill", action: "New model"),
            Shortcut(keys: "⌘O", symbol: "arrow.up.forward", action: "Open..."),
            Shortcut(keys: "⌘S", symbol: "square.and.arrow.down", action: "Save"),
            Shortcut(keys: "⇧⌘R", symbol: "arrow.counterclockwise", action: "Revert to saved")
        ]),
        Group(title: "Edit", shortcuts: [
            Shortcut(keys: "⌘Z", symbol: "arrow.uturn.backward", action: "Undo"),
            Shortcut(keys: "⇧⌘Z", symbol: "arrow.uturn.forward", action: "Redo"),
            Shortcut(keys: "⌘⌫", symbol: "trash", action: "Delete the selected entity or property"),
            Shortcut(keys: "⌘F", symbol: "line.3.horizontal.decrease", action: "Filter entities")
        ]),
        Group(title: "Editor", shortcuts: [
            Shortcut(keys: "⌘N", symbol: "e.square.fill", action: "Add entity"),
            Shortcut(keys: "⌥⌘A", symbol: "a.square.fill", action: "Add attribute"),
            Shortcut(keys: "⌥⌘R", symbol: "arrow.left.arrow.right.square.fill",
                     action: "Add relationship"),
            Shortcut(keys: "⇧⌘C", symbol: "checkmark.circle.fill", action: "Set current version")
        ]),
        Group(title: "View", shortcuts: [
            Shortcut(keys: "⌘1", symbol: "sidebar.leading", action: "Toggle the navigator"),
            Shortcut(keys: "⌘2", symbol: "sidebar.trailing", action: "Toggle the inspector"),
            Shortcut(keys: "⌘L", symbol: "list.bullet.indent", action: "Toggle the outline style")
        ]),
        // This window's own shortcut. Reaching it from the Help menu with the
        // mouse is the case where knowing the key is worth something.
        Group(title: "Help", shortcuts: [
            Shortcut(keys: "⌘/", symbol: "command", action: "Keyboard shortcuts")
        ])
    ]

    var body: some View {
        Form {
            ForEach(Self.groups) { group in
                Section {
                    ForEach(group.shortcuts) { shortcut in
                        LabeledContent {
                            // Monospaced so ⌘N and ⇧⌘N line up down the column.
                            Text(shortcut.keys)
                                .bold()
                                .foregroundStyle(.secondary)
                        } label: {
                            Label(shortcut.action, systemImage: shortcut.symbol)
                        }
                    }
                } header: {
                    Text(group.title)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }
}

#Preview {
    KeyboardShortcutsView()
        .frame(width: 380, height: 900)
}
