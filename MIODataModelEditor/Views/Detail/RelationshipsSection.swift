//
//  RelationshipsSection.swift
//  MIODataModelEditor
//
//  Created by MIO Research Labs on 2026.
//

import SwiftUI

/// The Relationships table of the entity detail pane.
struct RelationshipsSection: View {
    @Binding var entity: ModelEntity
    @Bindable var selection: EditorSelection
    @Binding var isExpanded: Bool
    let entityNames: [String]
    let relationshipNames: (String) -> [String]

    var body: some View {
        PropertySection(title: "Relationships",
                        isExpanded: $isExpanded,
                        columns: [PropertyColumn("Relationship", RelationshipRow.nameWidth),
                                  PropertyColumn("Destination", RelationshipRow.popupWidth),
                                  PropertyColumn("Inverse", RelationshipRow.popupWidth)],
                        onAdd: add,
                        onRemove: removeAction) {
            ForEach($entity.relationships) { $relationship in
                RelationshipRow(relationship: $relationship,
                                selection: selection,
                                entityNames: entityNames,
                                relationshipNames: relationshipNames)
            }
            // Minimum height of empty properties.
            ForEach(EmptyPropertyRow.padding(for: entity.relationships.count), id: \.self) { _ in
                EmptyPropertyRow(onSelect: { selection.deselectAll() })
            }
        }
    }

    /// The minus button is only live when the selection is one of these rows.
    /// See `AttributesSection.removeAction` for why this is not a ternary.
    private var removeAction: (() -> Void)? {
        guard selection.property?.kind == .relationship else { return nil }
        return remove
    }

    private func add() {
        selection.select(propertyNamed: entity.addRelationship(), kind: .relationship)
    }

    private func remove() {
        guard let property = selection.property else { return }
        entity.relationships.removeAll { $0.name == property.name }
        selection.clearProperty()
    }
}

#Preview("Populated") {
    @Previewable @State var entity = PreviewSamples.entity
    @Previewable @State var expanded = true

    ScrollView {
        RelationshipsSection(entity: $entity,
                             selection: EditorSelection(property: .init(name: "reports", kind: .relationship)),
                             isExpanded: $expanded,
                             entityNames: PreviewSamples.entityNames,
                             relationshipNames: PreviewSamples.relationshipNames)
            .padding()
    }
    .frame(width: 760, height: 320)
}

#Preview("One relationship, padded to three rows") {
    @Previewable @State var entity: ModelEntity = {
        var entity = ModelEntity(name: "Sparse")
        var relationship = ModelRelationship(name: "owner", destinationEntityName: "Account")
        relationship.optional = true
        relationship.maxCount = "1"
        entity.relationships = [relationship]
        return entity
    }()
    @Previewable @State var expanded = true

    ScrollView {
        RelationshipsSection(entity: $entity,
                             selection: EditorSelection(),
                             isExpanded: $expanded,
                             entityNames: PreviewSamples.entityNames,
                             relationshipNames: PreviewSamples.relationshipNames)
            .padding()
    }
    .frame(width: 760, height: 300)
}

#Preview("Empty") {
    @Previewable @State var entity = ModelEntity(name: "Blank")
    @Previewable @State var expanded = true

    ScrollView {
        RelationshipsSection(entity: $entity,
                             selection: EditorSelection(),
                             isExpanded: $expanded,
                             entityNames: PreviewSamples.entityNames,
                             relationshipNames: PreviewSamples.relationshipNames)
            .padding()
    }
    .frame(width: 760, height: 300)
}
