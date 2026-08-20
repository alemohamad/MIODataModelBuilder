//
//  PropertySection.swift
//  MIODataModelEditor
//
//  Created by MIO Research Labs on 2026.
//

import SwiftUI

/// A collapsible titled table with a column header and the +/- footer.
///
/// Composition only: the header, the column titles and the footer are their own
/// views, so this type is just the layout that puts them around the rows.
struct PropertySection<Rows: View>: View {
    let title: String
    @Binding var isExpanded: Bool
    let columns: [PropertyColumn]
    let onAdd: () -> Void
    /// `nil` disables the minus button, which is how a section signals that the
    /// current selection is not one of its rows.
    let onRemove: (() -> Void)?
    @ViewBuilder let rows: Rows

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PropertySectionHeader(title: title, isExpanded: $isExpanded)

            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    PropertyColumnHeader(columns: columns)
                    Divider()
                    rows
                    AddRemoveFooter(onAdd: onAdd, onRemove: onRemove)
                }
                .padding(.leading, 32)
            }
        }
        .padding(.vertical, 16)
    }
}

#Preview("Populated") {
    @Previewable @State var expanded = true
    @Previewable @State var names = ["accountName", "appID", "balance"]
    @Previewable @State var selected: String? = "appID"

    ScrollView {
        PropertySection(title: "Attributes",
                        isExpanded: $expanded,
                        columns: [PropertyColumn("Attribute", 200), PropertyColumn("Type", 140)],
                        onAdd: { names.append("attribute\(names.count)") },
                        onRemove: selected == nil ? nil : {
                            names.removeAll { $0 == selected }
                            selected = nil
                        }) {
            ForEach(names, id: \.self) { name in
                PropertyRow(isSelected: selected == name, onSelect: { selected = name }) {
                    TypeBadge(style: .attribute(.string))
                    Text(name).frame(width: 200, alignment: .leading)
                    Text("String").frame(width: 140, alignment: .leading)
                }
            }
        }
        .padding()
    }
    .frame(width: 480, height: 300)
}

#Preview("Empty and collapsed") {
    @Previewable @State var expanded = false

    VStack(alignment: .leading) {
        PropertySection(title: "Fetched Properties",
                        isExpanded: $expanded,
                        columns: [PropertyColumn("Fetched Property", 200), PropertyColumn("Predicate", 200)],
                        onAdd: {},
                        onRemove: nil) {
            EmptyView()
        }
        Spacer()
    }
    .padding()
    .frame(width: 480, height: 160)
}
