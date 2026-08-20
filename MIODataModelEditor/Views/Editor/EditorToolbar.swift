//
//  EditorToolbar.swift
//  MIODataModelEditor
//
//  Created by MIO Research Labs on 2026.
//

import SwiftUI

/// The window toolbar: version picker, issue count, inspector toggle.
///
/// A `ToolbarContent` type rather than a `@ToolbarContentBuilder` property, so
/// it composes and previews like any other piece of the editor.
struct EditorToolbar: ToolbarContent {
    /// Which version the window is showing. This is view state, not document
    /// state: switching it must never change what the package's consumers
    /// compile against.
    @Binding var viewedVersionName: String
    /// The version the `.xccurrentversion` marker names, shown so the picker
    /// says which one that is. Changed only through Set Current Version.
    let currentVersionName: String
    let versions: [ModelVersion]
    let issueCount: Int
    let onShowIssues: () -> Void
    let onToggleInspector: () -> Void

    private var currentDisplayName: String {
        versions.first { $0.fileName == currentVersionName }?.displayName ?? currentVersionName
    }

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            // A single-version model has nothing to switch between, and Xcode
            // hides the control in that case too.
            if versions.count > 1 {
                Picker("Version", selection: $viewedVersionName) {
                    ForEach(versions) { version in
                        // The marker goes inside the title rather than into a
                        // `Label` icon, because the popup renders its rows as
                        // menu items: a `Label` would put the glyph in the
                        // image slot and indent every titled row past the ones
                        // without an image. Interpolated into the `Text`, it
                        // trails the name and the column stays straight.
                        //
                        // Filled rather than a bare checkmark, so it cannot be
                        // read as the popup's own tick for the selected row.
                        Text(version.fileName == currentVersionName
                             ? "\(version.displayName) \(Image(systemName: "checkmark.circle.fill"))"
                             : "\(version.displayName)")
                            .tag(version.fileName)
                    }
                }
                .help("Viewing a model version. \(currentDisplayName) is the current version.")
            }
        }

        ToolbarItem {
            Button(action: onShowIssues) {
                Label("Issues", systemImage: issueCount == 0 ? "checkmark.circle" : "exclamationmark.triangle")
            }
            .help(issueCount == 0 ? "No issues" : "^[\(issueCount) issue](inflect: true)")
        }

        ToolbarItem {
            Button(action: onToggleInspector) {
                Label("Inspector", systemImage: "sidebar.right")
            }
            .help("Toggle the inspector")
        }
    }
}

#Preview("Several versions, with issues") {
    @Previewable @State var viewed = "Model 3.xcdatamodel"

    NavigationStack {
        Text("Editor")
            .frame(width: 600, height: 260)
            .toolbar {
                EditorToolbar(viewedVersionName: $viewed,
                              currentVersionName: "Model 2.xcdatamodel",
                              versions: [ModelVersion(fileName: "Model.xcdatamodel", model: DataModel()),
                                         ModelVersion(fileName: "Model 2.xcdatamodel", model: DataModel()),
                                         ModelVersion(fileName: "Model 3.xcdatamodel", model: DataModel())],
                              issueCount: 784,
                              onShowIssues: {},
                              onToggleInspector: {})
            }
    }
}

#Preview("One version, clean") {
    @Previewable @State var viewed = "Model.xcdatamodel"

    NavigationStack {
        Text("Editor")
            .frame(width: 600, height: 260)
            .toolbar {
                EditorToolbar(viewedVersionName: $viewed,
                              currentVersionName: "Model.xcdatamodel",
                              versions: [ModelVersion(fileName: "Model.xcdatamodel", model: DataModel())],
                              issueCount: 0,
                              onShowIssues: {},
                              onToggleInspector: {})
            }
    }
}
