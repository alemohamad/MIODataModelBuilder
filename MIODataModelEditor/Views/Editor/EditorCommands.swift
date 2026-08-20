//
//  EditorCommands.swift
//  MIODataModelEditor
//
//  Created by MIO Research Labs on 2026.
//

import AppKit
import SwiftUI

/// What the menu bar can ask the focused editor window to do.
///
/// Menu commands live in the `App` scene and cannot reach a window's state
/// directly, so the window publishes this through `focusedSceneValue` and the
/// commands read it back. `nil` means no editor window has focus, which is what
/// greys the items out.
struct EditorActions {
    var toggleSidebar: () -> Void = {}
    var toggleInspector: () -> Void = {}
    /// Switches the sidebar between the flat list and the inheritance outline.
    var toggleOutlineStyle: () -> Void = {}
    /// Which of the two the sidebar is showing, so the menu can carry the same
    /// icon as the segmented control in the sidebar footer.
    var isOutlineStyle = false
    var addEntity: () -> Void = {}
    var addConfiguration: () -> Void = {}
    /// `nil` when the sidebar is not on an entity, because a property has to go
    /// on something. Selecting a configuration greys all three out.
    var addAttribute: (() -> Void)?
    var addRelationship: (() -> Void)?
    var addFetchedProperty: (() -> Void)?
    var focusFilter: () -> Void = {}

    /// `nil` for a bare `.xcdatamodel`, which has no package to add a version
    /// to. Xcode cannot version one either.
    var addModelVersion: (() -> Void)?
    /// Writes `.xccurrentversion` so the viewed version becomes the one every
    /// consumer of the package compiles against. `nil` when it already is,
    /// which is also the whole point of it being a separate action: switching
    /// the picker only changes what this window shows.
    var setCurrentVersion: (() -> Void)?
    /// `nil` for a bare `.xcdatamodel`, whose only version is the document
    /// file itself and cannot be renamed from inside it.
    var renameModelVersion: (() -> Void)?
    /// `nil` for the last version and for the current one, which would leave
    /// the package unloadable or move the marker behind your back.
    var deleteModelVersion: (() -> Void)?

    /// `nil` when there is nothing deletable selected, which disables the item
    /// rather than leaving a command that silently does nothing.
    var deleteSelection: (() -> Void)?
    /// Names what Delete would remove, so the menu reads "Delete Entity" or
    /// "Delete Attribute" rather than a bare "Delete".
    var deleteTitle = "Delete"
}

private struct EditorActionsKey: FocusedValueKey {
    typealias Value = EditorActions
}

extension FocusedValues {
    var editorActions: EditorActions? {
        get { self[EditorActionsKey.self] }
        set { self[EditorActionsKey.self] = newValue }
    }
}

/// The editor's menu bar commands.
struct EditorCommands: Commands {
    @FocusedValue(\.editorActions) private var actions
    @Environment(\.openWindow) private var openWindow

    /// The Help menu's window, declared in the app scene.
    static let shortcutsWindowID = "keyboard-shortcuts"

    /// The one line the About panel shows under the version, centred to match
    /// the panel's own layout.
    private static var credits: NSAttributedString {
        let credits = NSMutableAttributedString(string: "miolabs.com")
        let whole = NSRange(location: 0, length: credits.length)

        let centred = NSMutableParagraphStyle()
        centred.alignment = .center
        credits.addAttributes([.paragraphStyle: centred,
                               .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)],
                              range: whole)

        if let site = URL(string: "https://www.miolabs.com") {
            credits.addAttribute(.link, value: site, range: whole)
        }
        return credits
    }

    var body: some Commands {
        // The stock About panel already shows the icon, name, version and the
        // copyright from the Info.plist. Credits is the one slot it leaves for
        // anything else, which is enough for a development tool.
        CommandGroup(replacing: .appInfo) {
            Button("About Data Model Editor") {
                NSApp.orderFrontStandardAboutPanel(options: [.credits: Self.credits])
            }
        }

        // Command-N belongs to Add Entity, over in the Editor menu, so the stock
        // New has to be rebuilt by hand on a different key. File > New is about
        // documents; making an entity is not one.
        CommandGroup(replacing: .newItem) {
            Button { NSDocumentController.shared.newDocument(nil) } label: {
                Label("New Model", systemImage: "cylinder.split.1x2.fill")
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
        }

        // Revert is a document command AppKit already implements. Sending the
        // selector down the responder chain reaches the focused document's own
        // implementation, which brings the confirmation sheet with it.
        //
        // Anchored to Save rather than to Undo so it lands in File, under the
        // save commands, which is where every Mac app keeps it.
        CommandGroup(after: .saveItem) {
            Button {
                NSApp.sendAction(#selector(NSDocument.revertToSaved(_:)), to: nil, from: nil)
            } label: {
                Label("Revert to Saved", systemImage: "arrow.counterclockwise")
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
        }

        CommandGroup(replacing: .sidebar) {
            Button { actions?.toggleSidebar() } label: {
                Label("Toggle Navigator", systemImage: "sidebar.leading")
            }
            .keyboardShortcut("1", modifiers: .command)
            .disabled(actions == nil)

            Button { actions?.toggleInspector() } label: {
                Label("Toggle Inspector", systemImage: "sidebar.trailing")
            }
            .keyboardShortcut("2", modifiers: .command)
            .disabled(actions == nil)

            // Carries whichever icon the sidebar's segmented control is showing.
            Button { actions?.toggleOutlineStyle() } label: {
                Label("Toggle Outline Style",
                      systemImage: actions?.isOutlineStyle == true ? "list.bullet.indent" : "list.bullet")
            }
            .keyboardShortcut("l", modifiers: .command)
            .disabled(actions == nil)

            Divider()
        }

        CommandGroup(after: .pasteboard) {
            Divider()

            // Command is what keeps this safe. A bare Delete equivalent would be
            // offered the key before the responder chain and swallow backspace
            // everywhere, including while renaming an attribute.
            Button { actions?.deleteSelection?() } label: {
                Label(actions?.deleteTitle ?? "Delete", systemImage: "trash")
            }
            .keyboardShortcut(.delete, modifiers: .command)
            .disabled(actions?.deleteSelection == nil)
        }

        // Everything that adds to the model, which is what Xcode's own Editor
        // menu holds for this editor. The four property and configuration
        // commands were reachable only through the `+` under each table before,
        // so the menu is also the first keyboard route to them.
        //
        // Only the two that get used constantly carry a key. A shortcut for a
        // command reached once per model is clutter, and every free combination
        // spent here is one the model editing itself cannot have.
        CommandMenu("Editor") {
            // Three groups, by what the command acts on: the model, the
            // selected entity, then the package of versions around both.
            Button { actions?.addEntity() } label: {
                Label("Add Entity", systemImage: "e.square.fill")
            }
            .keyboardShortcut("n", modifiers: .command)
            .disabled(actions == nil)

            Button { actions?.addConfiguration() } label: {
                Label("Add Configuration", systemImage: "c.square.fill")
            }
            .disabled(actions == nil)

            Divider()

            Button { actions?.addAttribute?() } label: {
                Label("Add Attribute", systemImage: "a.square.fill")
            }
            .keyboardShortcut("a", modifiers: [.command, .option])
            .disabled(actions?.addAttribute == nil)

            Button { actions?.addRelationship?() } label: {
                Label("Add Relationship", systemImage: "arrow.left.arrow.right.square.fill")
            }
            .keyboardShortcut("r", modifiers: [.command, .option])
            .disabled(actions?.addRelationship == nil)

            Button { actions?.addFetchedProperty?() } label: {
                Label("Add Fetched Property", systemImage: "line.3.horizontal.decrease.circle.fill")
            }
            .disabled(actions?.addFetchedProperty == nil)

            Divider()

            Button { actions?.addModelVersion?() } label: {
                Label("Add Model Version...", systemImage: "plus.rectangle.on.rectangle")
            }
            .disabled(actions?.addModelVersion == nil)

            Button { actions?.renameModelVersion?() } label: {
                Label("Rename Version...", systemImage: "pencil")
            }
            .disabled(actions?.renameModelVersion == nil)

            Button { actions?.deleteModelVersion?() } label: {
                Label("Delete Version...", systemImage: "trash")
            }
            .disabled(actions?.deleteModelVersion == nil)

            Button { actions?.setCurrentVersion?() } label: {
                Label("Set Current Version", systemImage: "checkmark.circle.fill")
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])
            .disabled(actions?.setCurrentVersion == nil)
        }

        CommandGroup(after: .textEditing) {
            Button { actions?.focusFilter() } label: {
                Label("Filter Entities", systemImage: "line.3.horizontal.decrease")
            }
            .keyboardShortcut("f", modifiers: .command)
            .disabled(actions == nil)
        }

        // Replaces "Data Model Editor Help", which opens an alert saying help
        // is not available: there is no help book to open, and a shortcut list
        // is more use than a dead menu item.
        CommandGroup(replacing: .help) {
            Button { openWindow(id: Self.shortcutsWindowID) } label: {
                Label("Keyboard Shortcuts", systemImage: "command")
            }
            .keyboardShortcut("/", modifiers: .command)
        }
    }
}
