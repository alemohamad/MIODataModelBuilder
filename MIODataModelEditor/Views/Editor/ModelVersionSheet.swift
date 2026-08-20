//
//  ModelVersionSheet.swift
//  MIODataModelEditor
//
//  Created by MIO Research Labs on 2026.
//

import SwiftUI

/// Editor > Add Model Version and Editor > Rename Version.
///
/// One sheet for both, because they ask the same question and differ only in
/// whether there is a version to copy from. What neither offers is making the
/// version current: that is the separate action that writes
/// `.xccurrentversion`, and folding it in here is exactly the conflation this
/// editor set out to undo.
struct ModelVersionSheet: View {
    enum Mode {
        /// Copy an existing version under a new name, Xcode's own dialog.
        case add
        /// Give the version the window is showing a different name.
        case rename

        var title: String { self == .add ? "Add Model Version" : "Rename Model Version" }
        var confirmLabel: String { self == .add ? "Add" : "Rename" }

        var explanation: String {
            switch self {
            case .add:
                "The new version is a copy of the one it is based on. The current version does not change."
            case .rename:
                "The version keeps its contents. If it is the current version, the package's marker follows the new name."
            }
        }
    }

    let mode: Mode
    let versions: [ModelVersion]
    /// The version being copied, or the one being renamed.
    let subject: String
    /// What the name field starts as for a given subject: the next free number
    /// when adding, the version's own name when renaming.
    let nameForSubject: (String) -> String
    let canUse: (String) -> Bool
    let onConfirm: (_ name: String, _ subject: String) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var subjectFileName: String
    @FocusState private var nameFocused: Bool

    init(mode: Mode,
         versions: [ModelVersion],
         subject: String,
         nameForSubject: @escaping (String) -> String,
         canUse: @escaping (String) -> Bool,
         onConfirm: @escaping (String, String) -> Void) {
        self.mode = mode
        self.versions = versions
        self.subject = subject
        self.nameForSubject = nameForSubject
        self.canUse = canUse
        self.onConfirm = onConfirm
        _name = State(initialValue: nameForSubject(subject))
        _subjectFileName = State(initialValue: subject)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespaces)
    }

    private var isUsable: Bool {
        canUse(trimmedName)
    }

    /// Only shown once something is actually wrong, so the sheet does not open
    /// already complaining, and renaming a version to the name it already has
    /// reads as "nothing to do" rather than as an error.
    private var problem: String? {
        guard !isUsable, !trimmedName.isEmpty else { return nil }
        if mode == .rename, trimmedName == nameForSubject(subjectFileName) { return nil }
        if versions.contains(where: { $0.displayName == trimmedName }) {
            return "A version named \(trimmedName) already exists."
        }
        return "That is not a usable version name."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(mode.title)
                .font(.headline)

            Form {
                TextField("Version name:", text: $name)
                    .focused($nameFocused)

                if mode == .add {
                    Picker("Based on model:", selection: $subjectFileName) {
                        ForEach(versions) { version in
                            Text(version.displayName).tag(version.fileName)
                        }
                    }
                }
            }
            .formStyle(.columns)
            // Changing the base renames along with it, which is what makes the
            // suggestion useful: picking "Model 5" offers "Model 6".
            .onChange(of: subjectFileName) { _, new in
                name = nameForSubject(new)
            }

            Text(problem ?? mode.explanation)
                .font(.caption)
                .foregroundStyle(problem == nil ? .secondary : Color.red)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(mode.confirmLabel) { confirm() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isUsable)
            }
        }
        .padding(20)
        .frame(width: 400)
        .onAppear { nameFocused = true }
    }

    private func confirm() {
        guard isUsable else { return }
        onConfirm(trimmedName, subjectFileName)
        dismiss()
    }
}

private let sampleVersions = [ModelVersion(fileName: "DualLinkDB.xcdatamodel", model: DataModel()),
                              ModelVersion(fileName: "DualLinkDB 2.xcdatamodel", model: DataModel())]

#Preview("Add a version") {
    ModelVersionSheet(mode: .add,
                      versions: sampleVersions,
                      subject: "DualLinkDB 2.xcdatamodel",
                      nameForSubject: { _ in "DualLinkDB 3" },
                      canUse: { !$0.isEmpty && $0 != "DualLinkDB" },
                      onConfirm: { _, _ in })
}

#Preview("Name already taken") {
    ModelVersionSheet(mode: .add,
                      versions: sampleVersions,
                      subject: "DualLinkDB 2.xcdatamodel",
                      nameForSubject: { _ in "DualLinkDB" },
                      canUse: { !$0.isEmpty && $0 != "DualLinkDB" },
                      onConfirm: { _, _ in })
}

#Preview("Rename a version") {
    ModelVersionSheet(mode: .rename,
                      versions: sampleVersions,
                      subject: "DualLinkDB 2.xcdatamodel",
                      nameForSubject: { _ in "DualLinkDB 2" },
                      canUse: { $0 != "DualLinkDB 2" && $0 != "DualLinkDB" && !$0.isEmpty },
                      onConfirm: { _, _ in })
}
