//
//  EmptyPropertyRow.swift
//  MIODataModelEditor
//
//  Created by MIO Research Labs on 2026.
//

import SwiftUI

/// A blank row that pads a short table out to a minimum height.
///
/// Xcode keeps a few empty rows under every property table so it does not
/// collapse to a single line when the entity has one attribute, or to nothing
/// at all when it has none.
///
/// The height comes from laying out a hidden copy of what a real row contains
/// rather than from a fixed number, so the table does not jump when the first
/// item is added, and it still tracks the system font size.
struct EmptyPropertyRow: View {
    /// How many rows a table shows before it starts growing.
    static let minimumRowCount = 3

    /// Clicking the blank area under a table is how the user deselects, the
    /// same as clicking past the last row in a Finder list. Rows without an
    /// action stay inert.
    var onSelect: (() -> Void)?

    var body: some View {
        PropertyRow(isSelected: false, onSelect: { onSelect?() }) {
            HStack(spacing: 6) {
                TypeBadge(style: .attribute(.undefined))
                Text(verbatim: "placeholder")
            }
            .hidden()
        }
        .allowsHitTesting(onSelect != nil)
        .accessibilityHidden(true)
    }
}

extension EmptyPropertyRow {
    /// How many blanks to add so a table of `count` items reaches the minimum.
    static func padding(for count: Int) -> Range<Int> {
        0 ..< max(0, minimumRowCount - count)
    }
}

#Preview("Padding a short table") {
    VStack(alignment: .leading, spacing: 0) {
        PropertyRow(isSelected: false, onSelect: {}) {
            TypeBadge(style: .attribute(.string))
            Text("onlyAttribute").frame(width: 140, alignment: .leading)
            Text("String")
        }
        ForEach(EmptyPropertyRow.padding(for: 1), id: \.self) { _ in
            EmptyPropertyRow()
        }
    }
    .padding()
    .frame(width: 420)
}

#Preview("Completely empty table") {
    VStack(alignment: .leading, spacing: 0) {
        ForEach(EmptyPropertyRow.padding(for: 0), id: \.self) { _ in
            EmptyPropertyRow()
        }
    }
    .padding()
    .frame(width: 420)
}
