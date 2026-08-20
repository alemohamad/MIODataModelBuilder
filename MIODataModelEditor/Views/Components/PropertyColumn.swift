//
//  PropertyColumn.swift
//  MIODataModelEditor
//
//  Created by MIO Research Labs on 2026.
//

import SwiftUI

/// One column header of a property table.
///
/// A named struct rather than a `(String, CGFloat)` tuple: an array of tuples
/// inside a generic view initialiser is enough to push the type checker into
/// "failed to produce diagnostic" territory.
struct PropertyColumn: Identifiable {
    let title: String
    let width: CGFloat

    var id: String { title }

    init(_ title: String, _ width: CGFloat) {
        self.title = title
        self.width = width
    }
}

/// The header row of a property table.
///
/// Takes the same widths the rows use, so the two cannot drift apart.
struct PropertyColumnHeader: View {
    let columns: [PropertyColumn]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(columns) { column in
                Text(column.title)
                    .font(.caption.weight(.semibold))
                    .frame(width: column.width, alignment: .leading)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 0) {
        PropertyColumnHeader(columns: [PropertyColumn("Relationship", 200),
                                       PropertyColumn("Destination", 140),
                                       PropertyColumn("Inverse", 140)])
        Divider()
    }
    .padding()
}
