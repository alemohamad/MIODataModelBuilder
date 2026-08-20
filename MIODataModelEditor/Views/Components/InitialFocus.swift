//
//  InitialFocus.swift
//  MIODataModelEditor
//
//  Created by MIO Research Labs on 2026.
//

import AppKit
import SwiftUI

extension View {
    /// Opens the window with nothing focused.
    ///
    /// AppKit hands a new window's first responder to the first view in its key
    /// view loop. Here that is the name field of the first attribute of the
    /// first entity, so opening a model lands with that name selected and one
    /// keystroke away from renaming a property nobody meant to touch. The
    /// document is not even dirty yet.
    ///
    /// Cleared once, when the view first reaches a window. Focus the user asks
    /// for afterwards is untouched, including the sidebar filter, which is only
    /// ever focused on an explicit Find.
    func clearsInitialFocus() -> some View {
        background(InitialFocusClearer().frame(width: 0, height: 0))
    }
}

private struct InitialFocusClearer: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { Clearer() }

    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class Clearer: NSView {
        private var hasCleared = false

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard hasCleared == false, let window else { return }
            hasCleared = true

            // Asynchronously, because AppKit assigns the initial first
            // responder as part of making the window key, which has not
            // happened yet at this point. Clearing now would be undone.
            DispatchQueue.main.async { [weak window] in
                guard let window else { return }
                // Only if nobody has since chosen for themselves. A window
                // restored with a field already focused, or a very fast click,
                // both count as chosen.
                guard window.firstResponder is NSText || window.firstResponder is NSTextField
                else { return }
                window.makeFirstResponder(nil)
            }
        }
    }
}
