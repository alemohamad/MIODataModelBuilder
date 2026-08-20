//
//  AttributeRow.swift
//  MIODataModelEditor
//
//  Created by MIO Research Labs on 2026.
//

import SwiftUI

/// One row of the Attributes table: badge, editable name, type popup.
struct AttributeRow: View {
    @Binding var attribute: ModelAttribute
    @Bindable var selection: EditorSelection

    static let nameWidth: CGFloat = 200
    static let typeWidth: CGFloat = 140
    /// Matches the relationships table, so both are 480 wide and the detail
    /// pane's minimum width covers either.
    static let defaultWidth: CGFloat = 140

    var body: some View {
        PropertyRow(isSelected: selection.isSelected(attribute.name, .attribute),
                    onSelect: { selection.select(propertyNamed: attribute.name, kind: .attribute) }) {
            HStack(spacing: 6) {
                TypeBadge(style: .attribute(attribute.type))
                CommittingTextField("Name", value: attribute.name) { newName in
                    attribute.name = newName
                    // Selection is keyed by name, so it has to follow a rename
                    // or the inspector would empty out mid-edit.
                    selection.select(propertyNamed: newName, kind: .attribute)
                }
                .textFieldStyle(.plain)
                if attribute.optional == true {
                    OptionalMarker()
                }
                if attribute.isDerived {
                    DerivedMarker(expression: attribute.derivationExpression)
                }
            }
            .frame(width: Self.nameWidth, alignment: .leading)

            Picker("", selection: $attribute.type) {
                ForEach(AttributeType.allCases) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(.menu)
            .buttonStyle(.borderless)
            .padding(.leading, -10)
            .frame(width: Self.typeWidth, alignment: .leading)

            // Read-only. Editing lives in the inspector, where the control can
            // match the type: a picker for a boolean, a calendar for a date.
            Text(attribute.defaultSummary)
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(.secondary)
                .frame(width: Self.defaultWidth, alignment: .leading)
        }
        .frame(alignment: .leading)
    }
}

#Preview("Rows") {
    @Previewable @State var entity = PreviewSamples.entity
    let selection = EditorSelection()
    selection.select(propertyNamed: "hiredAt", kind: .attribute)

    return VStack(alignment: .leading, spacing: 0) {
        ForEach($entity.attributes) { $attribute in
            AttributeRow(attribute: $attribute, selection: selection)
        }
    }
    .padding()
    .frame(width: 540)
}
