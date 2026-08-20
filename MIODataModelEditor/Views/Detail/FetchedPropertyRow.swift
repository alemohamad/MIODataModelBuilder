//
//  FetchedPropertyRow.swift
//  MIODataModelEditor
//
//  Created by MIO Research Labs on 2026.
//

import SwiftUI

/// One row of the Fetched Properties table: badge, editable name, predicate.
struct FetchedPropertyRow: View {
    @Binding var property: ModelFetchedProperty
    @Bindable var selection: EditorSelection

    static let nameWidth: CGFloat = 200
    static let predicateWidth: CGFloat = 140

    var body: some View {
        PropertyRow(isSelected: selection.isSelected(property.name, .fetchedProperty),
                    onSelect: { selection.select(propertyNamed: property.name, kind: .fetchedProperty) }) {
            HStack(spacing: 6) {
                TypeBadge(style: .fetchedProperty)
                CommittingTextField("Name", value: property.name) { newName in
                    property.name = newName
                    selection.select(propertyNamed: newName, kind: .fetchedProperty)
                }
                .textFieldStyle(.plain)
            }
            .frame(width: Self.nameWidth, alignment: .leading)

            CommittingTextField("Predicate", value: property.predicateString ?? "", prompt: "Predicate") { newValue in
                property.predicateString = newValue.isEmpty ? nil : newValue
                // The predicate lives on a nested <fetchRequest>, so setting one
                // has to bring the element into existence.
                property.hasFetchRequestElement = true
            }
            .textFieldStyle(.plain)
            .frame(width: Self.predicateWidth, alignment: .leading)
        }
        .frame(alignment: .leading)
    }
}

#Preview("With and without a predicate") {
    @Previewable @State var withPredicate = PreviewSamples.fetchedProperty
    @Previewable @State var empty = ModelFetchedProperty(name: "unfiltered")
    let selection = EditorSelection()
    selection.select(propertyNamed: "seniorReports", kind: .fetchedProperty)

    return VStack(alignment: .leading, spacing: 0) {
        FetchedPropertyRow(property: $withPredicate, selection: selection)
        FetchedPropertyRow(property: $empty, selection: selection)
    }
    .padding()
}
