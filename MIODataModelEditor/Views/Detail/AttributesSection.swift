//
//  AttributesSection.swift
//  MIODataModelEditor
//
//  Created by MIO Research Labs on 2026.
//

import SwiftUI

/// The Attributes table of the entity detail pane.
struct AttributesSection: View {
    @Binding var entity: ModelEntity
    @Bindable var selection: EditorSelection
    @Binding var isExpanded: Bool

    var body: some View {
        PropertySection(title: "Attributes",
                        isExpanded: $isExpanded,
                        columns: [PropertyColumn("Attribute", AttributeRow.nameWidth),
                                  PropertyColumn("Type", AttributeRow.typeWidth),
                                  PropertyColumn("Default", AttributeRow.defaultWidth)],
                        onAdd: add,
                        onRemove: removeAction) {
            // Alphabetical, which is what Xcode's editor shows and what 96%
            // of the entities in the models here are already stored as. The
            // array keeps its own order: this sorts the view, not the file.
            ForEach(sortedAttributeIDs, id: \.self) { id in
                if let index = entity.attributes.firstIndex(where: { $0.id == id }) {
                    AttributeRow(attribute: $entity.attributes[index], selection: selection)
                }
            }
            // Minimum height of empty properties.
            ForEach(EmptyPropertyRow.padding(for: entity.attributes.count), id: \.self) { _ in
                EmptyPropertyRow(onSelect: { selection.deselectAll() })
            }
        }
    }

    /// Row order, by identity rather than index, so a rename moves the row
    /// without SwiftUI reusing it for whatever now sits at that position.
    private var sortedAttributeIDs: [UUID] {
        entity.attributes
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            .map(\.id)
    }

    /// The minus button is only live when the selection is one of these rows.
    ///
    /// Spelled out with an explicit type rather than inlined as a ternary: a
    /// `cond ? method : nil` producing an optional closure, inside a generic
    /// view initialiser, is enough to make the type checker give up with
    /// "failed to produce diagnostic".
    private var removeAction: (() -> Void)? {
        guard selection.property?.kind == .attribute else { return nil }
        return remove
    }

    private func add() {
        selection.select(propertyNamed: entity.addAttribute(), kind: .attribute)
    }

    private func remove() {
        guard let property = selection.property else { return }
        entity.attributes.removeAll { $0.name == property.name }
        selection.clearProperty()
    }
}

#Preview("Populated") {
    @Previewable @State var entity = PreviewSamples.entity
    @Previewable @State var expanded = true

    ScrollView {
        AttributesSection(entity: $entity,
                          selection: EditorSelection(property: .init(name: "rank", kind: .attribute)),
                          isExpanded: $expanded)
            .padding()
    }
    .frame(width: 560, height: 340)
}

#Preview("One attribute, padded to three rows") {
    @Previewable @State var entity: ModelEntity = {
        var entity = ModelEntity(name: "Sparse")
        entity.attributes = [ModelAttribute(name: "onlyAttribute", type: .string)]
        return entity
    }()
    @Previewable @State var expanded = true

    ScrollView {
        AttributesSection(entity: $entity, selection: EditorSelection(), isExpanded: $expanded)
            .padding()
    }
    .frame(width: 560, height: 280)
}

#Preview("Empty") {
    @Previewable @State var entity = ModelEntity(name: "Blank")
    @Previewable @State var expanded = true

    ScrollView {
        AttributesSection(entity: $entity, selection: EditorSelection(), isExpanded: $expanded)
            .padding()
    }
    .frame(width: 560, height: 280)
}
