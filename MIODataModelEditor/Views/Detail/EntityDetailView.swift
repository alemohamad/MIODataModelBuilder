//
//  EntityDetailView.swift
//  MIODataModelEditor
//
//  Created by MIO Research Labs on 2026.
//

import SwiftUI

/// The middle pane: Attributes, Relationships and Fetched Properties stacked as
/// three collapsible tables, matching Xcode's layout.
///
/// The tables live in a single `ScrollView` rather than being three `Table`s or
/// `List`s. Nesting scrollable containers is the thing to avoid here, and the
/// rows need inline pickers bound straight to the document.
struct EntityDetailView: View {
    @Binding var entity: ModelEntity
    @Bindable var selection: EditorSelection
    let entityNames: [String]
    let relationshipNames: (String) -> [String]

    @State private var attributesExpanded = true
    @State private var relationshipsExpanded = true
    @State private var fetchedExpanded = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                AttributesSection(entity: $entity,
                                  selection: selection,
                                  isExpanded: $attributesExpanded)
                Divider()
                RelationshipsSection(entity: $entity,
                                     selection: selection,
                                     isExpanded: $relationshipsExpanded,
                                     entityNames: entityNames,
                                     relationshipNames: relationshipNames)
                Divider()
                FetchedPropertiesSection(entity: $entity,
                                         selection: selection,
                                         isExpanded: $fetchedExpanded)
            }
            .padding(16)
            // A ScrollView centres content narrower than itself. Collapsing every
            // section leaves only the headers, which is narrow enough to drift to
            // the middle of the pane, so the content is stretched and pinned
            // leading instead.
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(entity.name)
    }
}

#Preview("Populated entity") {
    @Previewable @State var entity = PreviewSamples.entity

    EntityDetailView(entity: $entity,
                     selection: EditorSelection(),
                     entityNames: PreviewSamples.entityNames,
                     relationshipNames: PreviewSamples.relationshipNames)
}

#Preview("Empty entity") {
    @Previewable @State var entity = ModelEntity(name: "Blank")

    EntityDetailView(entity: $entity,
                     selection: EditorSelection(),
                     entityNames: PreviewSamples.entityNames,
                     relationshipNames: PreviewSamples.relationshipNames)
}
