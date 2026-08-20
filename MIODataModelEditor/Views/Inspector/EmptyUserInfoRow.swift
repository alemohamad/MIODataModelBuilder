//
//  EmptyUserInfoRow.swift
//  MIODataModelEditor
//
//  Created by MIO Research Labs on 2026.
//

import SwiftUI

/// A blank row that pads a short ``UserInfoTable`` out to a minimum height.
///
/// The same idea as ``EmptyPropertyRow``, but for the Key/Value table. That one
/// mirrors a property row, which is a badge and a name column on fixed widths,
/// so it is the wrong height and the wrong shape here.
///
/// The row lays out a real ``UserInfoRow`` and hides it, rather than guessing a
/// number, so the table does not jump when the first entry is added and the
/// height still tracks the system font size.
struct EmptyUserInfoRow: View {
    /// How many rows the table shows before it starts growing.
    static let minimumRowCount = 3

    var body: some View {
        Group {
            UserInfoRow(entry: .constant(UserInfoEntry()))
                .hidden()
                .disabled(true)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            Divider()
                .hidden()
        }
    }
}

extension EmptyUserInfoRow {
    /// How many blanks to add so a table of `count` entries reaches the minimum.
    static func padding(for count: Int) -> Range<Int> {
        0 ..< max(0, minimumRowCount - count)
    }
}

#Preview("Padding a table with one entry") {
    @Previewable @State var entry = UserInfoEntry(key: "syncPolicy", value: "server")

    VStack(alignment: .leading, spacing: 2) {
        UserInfoHeader()
        Divider()
        UserInfoRow(entry: $entry)
        Divider()
        ForEach(EmptyUserInfoRow.padding(for: 1), id: \.self) { _ in
            EmptyUserInfoRow()
            Divider()
        }
    }
    .padding()
    .frame(width: 300)
}

#Preview("Completely empty table") {
    VStack(alignment: .leading, spacing: 2) {
        UserInfoHeader()
        Divider()
        ForEach(EmptyUserInfoRow.padding(for: 0), id: \.self) { _ in
            EmptyUserInfoRow()
        }
    }
    .padding()
    .frame(width: 300)
}
