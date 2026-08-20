//
//  AddRemoveFooter.swift
//  MIODataModelEditor
//
//  Created by MIO Research Labs on 2026.
//

import SwiftUI

/// The +/- pair Xcode puts under every editable table.
///
/// Shared by the property tables and the User Info table, which had grown
/// identical copies of it.
struct AddRemoveFooter: View {
    let onAdd: () -> Void
    /// `nil` disables the minus button, which is how a table signals that
    /// nothing removable is selected.
    let onRemove: (() -> Void)?

    var addHelp: String = "Add"
    var removeHelp: String = "Remove selected"

    /// Click target, which is deliberately larger than the glyph.
    ///
    /// The size and shape have to be applied to the *label*, inside the button.
    /// Sizing the button itself only moves the glyph around within a bigger
    /// frame: a plain button hit-tests its label, so everything but the few
    /// points the glyph actually covers stays dead. `contentShape` is what makes
    /// the whole rectangle clickable.
    private static let hitWidth: CGFloat = 22
    private static let hitHeight: CGFloat = 18

    var body: some View {
        HStack(spacing: 4) {
            Button(action: onAdd) {
                Image(systemName: "plus")
                    .frame(width: Self.hitWidth, height: Self.hitHeight)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(addHelp)

            Button { onRemove?() } label: {
                Image(systemName: "minus")
                    .frame(width: Self.hitWidth, height: Self.hitHeight)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(onRemove == nil)
            .help(removeHelp)
        }
        .foregroundStyle(.secondary)
        .padding(.top, 6)
    }
}

#Preview("Both states") {
    VStack(alignment: .leading, spacing: 24) {
        VStack(alignment: .leading) {
            Text("Removable").font(.caption)
            AddRemoveFooter(onAdd: {}, onRemove: {})
        }
        VStack(alignment: .leading) {
            Text("Nothing selected").font(.caption)
            AddRemoveFooter(onAdd: {}, onRemove: nil)
        }
    }
    .padding()
}
