//
//  MIODataModelEditorApp.swift
//  MIODataModelEditor
//
//  Created by Ale Mohamad on 19/08/2026.
//

import SwiftUI

@main
struct MIODataModelEditorApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: MIODataModelEditorDocument()) { file in
            ContentView(document: file.$document)
        }
        .defaultSize(width: EditorLayout.windowDefaultWidth,
                     height: EditorLayout.windowDefaultHeight)
        // Without this the window is free to shrink below the content's
        // minimum, and a three-column editor then clips the sidebar and the
        // inspector off the edges rather than refusing to get smaller.
        // `.contentMinSize` keeps the floor while still allowing any size above
        // it, which `.contentSize` would not.
        .windowResizability(.contentMinSize)
        .commands { EditorCommands() }

        Window("Keyboard Shortcuts", id: EditorCommands.shortcutsWindowID) {
            KeyboardShortcutsView()
        }
        .defaultSize(width: 380, height: 900)
        .windowResizability(.contentMinSize)
    }
}
