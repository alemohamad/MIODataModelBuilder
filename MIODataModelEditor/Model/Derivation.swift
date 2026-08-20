//
//  Derivation.swift
//  MIODataModelEditor
//
//  Created by MIO Research Labs on 2026.
//

import Foundation

/// A derivation the inspector's pickers can represent: one hop across a to-one
/// relationship, to one attribute of its destination.
///
/// This is the shape the models here actually use, a flattened copy of a value
/// from the other side of a relationship so a query does not have to join for
/// it. Core Data's grammar is wider (aggregates over a to-many, string
/// functions, `now()`), and an expression outside this shape is shown verbatim
/// rather than rewritten. See ``ModelAttribute/keyPathDerivation``.
nonisolated struct KeyPathDerivation: Equatable, Sendable {
    var relationshipName: String
    var attributeName: String

    /// What the file holds: `relationship.attribute`.
    var expression: String { "\(relationshipName).\(attributeName)" }
}

nonisolated extension ModelAttribute {
    /// Whether the file marks this attribute derived.
    ///
    /// Tri-state underneath, like every other flag here, so an absent XML
    /// attribute stays absent on save.
    var isDerived: Bool { derived == true }

    /// The derivation expression with surrounding space removed, or `nil` when
    /// there is nothing usable in it.
    var derivationText: String? {
        guard let raw = derivationExpression?.trimmingCharacters(in: .whitespaces),
              raw.isEmpty == false
        else { return nil }
        return raw
    }

    /// The derivation read as a relationship and an attribute, or `nil` when
    /// the expression is absent or is some other form.
    ///
    /// Deliberately strict: `count:(items)`, `a.b.c` and
    /// `firstName ++ " " ++ lastName` all return `nil`. Showing any of those in
    /// two pickers would mean rewriting the expression into something it is
    /// not, and the one rule the editor cannot break is losing what the file
    /// says.
    var keyPathDerivation: KeyPathDerivation? {
        guard let raw = derivationText else { return nil }

        let parts = raw.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 2 else { return nil }

        let relationship = String(parts[0])
        let attribute = String(parts[1])
        guard relationship.isPlainIdentifier, attribute.isPlainIdentifier else { return nil }

        return KeyPathDerivation(relationshipName: relationship, attributeName: attribute)
    }

    /// Set to an expression the pickers cannot show. The raw field is the only
    /// way to edit one, and nothing may rewrite it.
    var hasAdvancedDerivation: Bool {
        isDerived && derivationText != nil && keyPathDerivation == nil
    }

    /// Marked derived with no expression at all.
    ///
    /// Core Data cannot evaluate this, so it is worth surfacing rather than
    /// leaving as an empty field somebody meant to fill in.
    var isDerivedWithoutExpression: Bool {
        isDerived && derivationText == nil
    }
}

nonisolated extension DataModel {
    /// Every attribute visible on the entity: its own, and its ancestors'.
    ///
    /// Inheritance is not optional here. In the models this editor is built
    /// for, the most commonly mirrored fields sit on an abstract root, so an
    /// attribute picker showing only the entity's own attributes would be
    /// missing the ones people actually reach for.
    ///
    /// The walk goes child first, so an attribute redeclared on a subentity
    /// shadows its parent's rather than appearing twice. Core Data forbids that
    /// redeclaration, which is exactly why a file editor has to survive it.
    ///
    /// The visited set guards a parent chain that loops, for the same reason.
    func attributes(inEntityNamed name: String) -> [ModelAttribute] {
        var visited: Set<String> = []
        var seenNames: Set<String> = []
        var found: [ModelAttribute] = []
        var current = entity(named: name)

        while let entity = current, visited.contains(entity.name) == false {
            visited.insert(entity.name)
            for attribute in entity.attributes where seenNames.contains(attribute.name) == false {
                seenNames.insert(attribute.name)
                found.append(attribute)
            }
            current = entity.parentEntityName.flatMap { self.entity(named: $0) }
        }

        return found.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}

nonisolated private extension String {
    /// A bare property name: letters, digits and underscores, not starting with
    /// a digit. Anything holding a space, a colon, a bracket or an operator is
    /// an expression, not a keypath component.
    var isPlainIdentifier: Bool {
        guard let first, first.isLetter || first == "_" else { return false }
        return allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
    }
}
