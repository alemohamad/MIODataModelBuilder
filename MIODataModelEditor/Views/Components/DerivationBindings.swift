//
//  DerivationBindings.swift
//  MIODataModelEditor
//
//  Created by MIO Research Labs on 2026.
//

import SwiftUI

/// The two halves of a derivation keypath, as bindings the pickers can drive.
///
/// Written as `Binding` extensions rather than as `Binding(get:set:)` inside the
/// inspector, which is the same shape `OptionalBindings` and `RelationshipRow`
/// already use. Building them in the view means the closures capture a
/// main-actor-isolated `self`, and the compiler currently crashes in IRGen
/// emitting the thunk for that.
nonisolated extension Binding where Value == ModelAttribute {

    /// The relationship the derivation reads through.
    ///
    /// A relationship on its own is not a valid expression, so choosing one
    /// before an attribute cannot be stored in the file. It goes in `draft`
    /// until the attribute half arrives.
    func derivationRelationship(draft: Binding<String?>,
                                relationships: [ModelRelationship],
                                attributesInEntity: @escaping (String) -> [ModelAttribute]) -> Binding<String> {
        Binding<String>(
            get: { draft.wrappedValue ?? wrappedValue.keyPathDerivation?.relationshipName ?? "" },
            set: { name in
                draft.wrappedValue = name

                guard name.isEmpty == false else {
                    wrappedValue.derivationExpression = nil
                    return
                }

                // Keep the chosen attribute when the new destination also has
                // one by that name, which is what happens moving between
                // sibling entities.
                let chosen = wrappedValue.keyPathDerivation?.attributeName ?? ""
                let destination = relationships.first { $0.name == name }?.destinationEntityName ?? ""

                if chosen.isEmpty == false,
                   attributesInEntity(destination).contains(where: { $0.name == chosen }) {
                    wrappedValue.derivationExpression = KeyPathDerivation(relationshipName: name,
                                                                         attributeName: chosen).expression
                } else {
                    wrappedValue.derivationExpression = nil
                }
            })
    }

    /// The attribute the derivation reads, on the other side of `relationship`.
    func derivationAttribute(relationship: String) -> Binding<String> {
        Binding<String>(
            get: { wrappedValue.keyPathDerivation?.attributeName ?? "" },
            set: { name in
                guard relationship.isEmpty == false, name.isEmpty == false else {
                    wrappedValue.derivationExpression = nil
                    return
                }
                wrappedValue.derivationExpression = KeyPathDerivation(relationshipName: relationship,
                                                                     attributeName: name).expression
            })
    }
}

nonisolated extension Binding where Value == Bool? {
    /// A tri-state override shown as a plain flag, reading as `inferred` until
    /// somebody chooses.
    ///
    /// Lets a control start in the state the file implies and stay there
    /// without writing anything, which is the same rule the model's own
    /// tri-state flags follow.
    func overriding(_ inferred: Bool) -> Binding<Bool> {
        Binding<Bool>(get: { wrappedValue ?? inferred },
                      set: { wrappedValue = $0 })
    }
}
