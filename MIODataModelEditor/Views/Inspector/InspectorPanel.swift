//
//  InspectorPanel.swift
//  MIODataModelEditor
//
//  Created by MIO Research Labs on 2026.
//

import SwiftUI

/// The right-hand inspector.
///
/// Routes to whichever of attribute / relationship / fetched property is
/// selected, falling back to the entity. Most specific first, matching Xcode:
/// selecting a property in the middle pane replaces the entity inspector rather
/// than adding to it.
struct InspectorPanel: View {
    @Binding var entity: ModelEntity
    @Bindable var selection: EditorSelection
    let entityNames: [String]
    let relationshipNames: (String) -> [String]
    /// The attributes visible on an entity, inherited ones included. Feeds the
    /// attribute inspector's derivation pickers.
    let attributesInEntity: (String) -> [ModelAttribute]
    let renameEntity: (String) -> Void

    var body: some View {
        Form {
            if let index = attributeIndex {
                AttributeInspector(attribute: $entity.attributes[index],
                                   relationships: entity.relationships,
                                   attributesInEntity: attributesInEntity)
            } else if let index = relationshipIndex {
                RelationshipInspector(relationship: $entity.relationships[index],
                                      entityNames: entityNames,
                                      relationshipNames: relationshipNames)
            } else if let index = fetchedPropertyIndex {
                FetchedPropertyInspector(property: $entity.fetchedProperties[index],
                                         entityNames: entityNames)
            } else {
                EntityInspector(entity: $entity, entityNames: entityNames, renameEntity: renameEntity)
            }
        }
        .formStyle(.grouped)
        // One inspector per thing inspected. Without this SwiftUI reuses the
        // views across a selection change, and a text field that still has
        // focus goes on showing the previous property's text while editing the
        // new one. A fresh identity resets both the draft and the focus.
        .id(inspectedIdentity)
    }

    /// What the inspector is currently editing. Changing it rebuilds the form.
    private var inspectedIdentity: String {
        guard let property = selection.property else { return "entity:\(entity.name)" }
        return "\(entity.name)/\(property.kind)/\(property.name)"
    }

    // Resolved by name rather than held as an index, because the selection has
    // to survive an undo replacing the whole document value.
    private var attributeIndex: Int? {
        index(for: .attribute) { name in entity.attributes.firstIndex { $0.name == name } }
    }

    private var relationshipIndex: Int? {
        index(for: .relationship) { name in entity.relationships.firstIndex { $0.name == name } }
    }

    private var fetchedPropertyIndex: Int? {
        index(for: .fetchedProperty) { name in entity.fetchedProperties.firstIndex { $0.name == name } }
    }

    private func index(for kind: EditorSelection.PropertyKind, in lookup: (String) -> Int?) -> Int? {
        guard let property = selection.property, property.kind == kind else { return nil }
        return lookup(property.name)
    }
}

#Preview("Entity selected") {
    @Previewable @State var entity = PreviewSamples.entity

    InspectorPanel(entity: $entity,
                   selection: EditorSelection(),
                   entityNames: PreviewSamples.entityNames,
                   relationshipNames: PreviewSamples.relationshipNames,
                   attributesInEntity: PreviewSamples.attributes(inEntityNamed:),
                   renameEntity: { _ in })
        .frame(width: 340, height: 700)
}

#Preview("Attribute selected") {
    @Previewable @State var entity = PreviewSamples.entity

    InspectorPanel(entity: $entity,
                   selection: EditorSelection(property: .init(name: "rank", kind: .attribute)),
                   entityNames: PreviewSamples.entityNames,
                   relationshipNames: PreviewSamples.relationshipNames,
                   attributesInEntity: PreviewSamples.attributes(inEntityNamed:),
                   renameEntity: { _ in })
        .frame(width: 340, height: 700)
}

#Preview("Relationship selected") {
    @Previewable @State var entity = PreviewSamples.entity

    InspectorPanel(entity: $entity,
                   selection: EditorSelection(property: .init(name: "reports", kind: .relationship)),
                   entityNames: PreviewSamples.entityNames,
                   relationshipNames: PreviewSamples.relationshipNames,
                   attributesInEntity: PreviewSamples.attributes(inEntityNamed:),
                   renameEntity: { _ in })
        .frame(width: 340, height: 700)
}

#Preview("Fetched property selected") {
    @Previewable @State var entity = PreviewSamples.entity

    InspectorPanel(entity: $entity,
                   selection: EditorSelection(property: .init(name: "seniorReports", kind: .fetchedProperty)),
                   entityNames: PreviewSamples.entityNames,
                   relationshipNames: PreviewSamples.relationshipNames,
                   attributesInEntity: PreviewSamples.attributes(inEntityNamed:),
                   renameEntity: { _ in })
        .frame(width: 340, height: 700)
}
