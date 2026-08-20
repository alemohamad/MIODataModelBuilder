//
//  CommittingTextField.swift
//  MIODataModelEditor
//
//  Created by MIO Research Labs on 2026.
//

import SwiftUI

/// A text field that edits a local copy and only writes back on Return or when
/// focus leaves.
///
/// Writing straight through the document binding would register one undo step
/// per keystroke. Committing on submit and on blur is both what Xcode does and
/// what makes a single undo restore the whole edit.
struct CommittingTextField: View {
    let title: String
    let value: String
    var prompt: String?
    let onCommit: (String) -> Void

    @State private var draft: String = ""
    @FocusState private var focused: Bool

    init(_ title: String, value: String, prompt: String? = nil, onCommit: @escaping (String) -> Void) {
        self.title = title
        self.value = value
        self.prompt = prompt
        self.onCommit = onCommit
    }

    var body: some View {
        // The title is the field's label, and every use site either sits inside
        // a LabeledContent that already shows one or is a bare table cell. Left
        // visible, a Form promotes it to a second label and rows read
        // "Name Name". Hidden, it still serves as the placeholder.
        TextField(title, text: $draft, prompt: prompt.map { Text($0) })
            .labelsHidden()
            .onAppear { draft = value }
            .focused($focused)
            .onChange(of: value) { _, newValue in
                // Something else changed the model: an undo or a repair. Adopt
                // it unless the user is mid-edit, or their typing disappears.
                //
                // A change of SELECTION does not arrive here. The inspector is
                // rebuilt for the new property instead, which is what resets
                // the draft and the focus. See `InspectorPanel`.
                if !focused { draft = newValue }
            }
            // Return gives the field up rather than sitting there with the text
            // selected, which is what a table cell should do once the edit is
            // finished. Dropping focus is also what commits: doing it here as
            // well would write the same value twice and cost two undo steps.
            .onSubmit { focused = false }
            .onChange(of: focused) { _, isFocused in
                if !isFocused { commit() }
            }
            // Selecting another property destroys this field while it still
            // holds focus, and losing focus that way does not fire the handler
            // above. This instance still refers to the property it was built
            // for, so committing here writes the edit to the right one.
            .onDisappear { commit() }
    }

    private func commit() {
        guard draft != value else { return }
        onCommit(draft)
    }
}

#Preview("Commits on Return or blur") {
    @Previewable @State var stored = "employee"
    @Previewable @State var commits = 0

    Form {
        LabeledContent("Name") {
            CommittingTextField("Name", value: stored) { newValue in
                stored = newValue
                commits += 1
            }
        }
        LabeledContent("Optional") {
            CommittingTextField("Class", value: "", prompt: "No Class Name") { _ in }
        }
        LabeledContent("Stored value", value: stored)
        LabeledContent("Commits", value: "\(commits)")
        Text("Type, then press Return or click away. The commit count only moves once per edit.")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
    .formStyle(.grouped)
    .frame(width: 380)
}
