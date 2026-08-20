//
//  PropertyRow.swift
//  MIODataModelEditor
//
//  Created by MIO Research Labs on 2026.
//

import SwiftUI

/// One row of a property table.
struct PropertyRow<Content: View>: View {
    let isSelected: Bool
    let onSelect: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 8) {
            content
            Spacer()
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 4)
        .background {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.85) : .clear)
        }
        .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .overlay(alignment: .bottom) { Divider() }
    }
}

#Preview("Selected and unselected") {
    @Previewable @State var selected = "appID"

    VStack(alignment: .leading, spacing: 0) {
        ForEach(["accountName", "appID", "balance"], id: \.self) { name in
            PropertyRow(isSelected: selected == name, onSelect: { selected = name }) {
                TypeBadge(style: .attribute(.string))
                Text(name).frame(width: 200, alignment: .leading)
                Text("String").foregroundStyle(.secondary)
            }
        }
    }
    .padding()
}
