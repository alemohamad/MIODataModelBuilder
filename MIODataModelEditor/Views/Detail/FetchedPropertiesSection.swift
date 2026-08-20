//
//  FetchedPropertiesSection.swift
//  MIODataModelEditor
//
//  Created by MIO Research Labs on 2026.
//

import SwiftUI

/// The Fetched Properties table of the entity detail pane.
struct FetchedPropertiesSection: View {
    @Binding var entity: ModelEntity
    @Bindable var selection: EditorSelection
    @Binding var isExpanded: Bool

    var body: some View {
        PropertySection(title: "Fetched Properties",
                        isExpanded: $isExpanded,
                        columns: [PropertyColumn("Fetched Property", FetchedPropertyRow.nameWidth),
                                  PropertyColumn("Predicate", FetchedPropertyRow.predicateWidth)],
                        onAdd: add,
                        onRemove: removeAction) {
            ForEach(sortedIndices, id: \.self) { index in
                FetchedPropertyRow(property: $entity.fetchedProperties[index], selection: selection)
            }
            // Minimum height of empty properties.
            ForEach(EmptyPropertyRow.padding(for: entity.fetchedProperties.count), id: \.self) { _ in
                EmptyPropertyRow(onSelect: { selection.deselectAll() })
            }
        }
    }

    /// Row order for display only.
    ///
    /// The table is sorted by name while every binding still writes through to
    /// the property's stored position, so sorting the view never reorders the
    /// `<fetchedProperty>` elements in the file. Iterating indices rather than
    /// a sorted copy is what keeps that true.
    private var sortedIndices: [Int] {
        entity.fetchedProperties.indices.sorted {
            entity.fetchedProperties[$0].name
                .localizedStandardCompare(entity.fetchedProperties[$1].name) == .orderedAscending
        }
    }

    /// The minus button is only live when the selection is one of these rows.
    /// See `AttributesSection.removeAction` for why this is not a ternary.
    private var removeAction: (() -> Void)? {
        guard selection.property?.kind == .fetchedProperty else { return nil }
        return remove
    }

    private func add() {
        selection.select(propertyNamed: entity.addFetchedProperty(), kind: .fetchedProperty)
    }

    private func remove() {
        guard let property = selection.property else { return }
        entity.fetchedProperties.removeAll { $0.name == property.name }
        selection.clearProperty()
    }
}

#Preview("Populated") {
    @Previewable @State var entity = PreviewSamples.entity
    @Previewable @State var expanded = true

    ScrollView {
        FetchedPropertiesSection(entity: $entity,
                                 selection: EditorSelection(property: .init(name: "seniorReports", kind: .fetchedProperty)),
                                 isExpanded: $expanded)
            .padding()
    }
    .frame(width: 660, height: 300)
}

#Preview("Empty") {
    // The usual case: most entities never define a fetched property, so this
    // is what the section looks like almost everywhere.
    @Previewable @State var entity = ModelEntity(name: "Blank")
    @Previewable @State var expanded = true

    ScrollView {
        FetchedPropertiesSection(entity: $entity, selection: EditorSelection(), isExpanded: $expanded)
            .padding()
    }
    .frame(width: 660, height: 300)
}
