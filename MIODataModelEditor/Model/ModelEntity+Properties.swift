//
//  ModelEntity+Properties.swift
//  MIODataModelEditor
//
//  Created by MIO Research Labs on 2026.
//

import Foundation

nonisolated extension ModelEntity {
    /// Every property name on the entity.
    ///
    /// Attributes, relationships and fetched properties share one namespace in
    /// Core Data, so all three have to be considered together. Two of them
    /// colliding is a `duplicateName` diagnostic, not something the file
    /// prevents.
    var propertyNames: Set<String> {
        Set(attributes.map(\.name))
            .union(relationships.map(\.name))
            .union(fetchedProperties.map(\.name))
    }

    /// Renames the entity, carrying the class name along while the two match.
    ///
    /// Xcode's rule, and the one every entity in a real model follows: the
    /// class name tracks the entity name until somebody deliberately types a
    /// different one, which is the escape hatch for a name the Objective-C
    /// runtime has already taken. Without this a renamed entity keeps the class
    /// name it was born with, so two entities renamed from the same default
    /// both claim `Entity`, and the generator writes one class file that
    /// overwrites the other.
    mutating func rename(to newName: String) {
        let classNameFollowedTheEntity = representedClassName == name
        name = newName
        if classNameFollowedTheEntity { representedClassName = newName }
    }

    /// A property name not already taken, of the form `base`, `base1`, `base2`…
    func uniquePropertyName(base: String) -> String {
        let taken = propertyNames
        guard taken.contains(base) else { return base }
        var suffix = 1
        while taken.contains("\(base)\(suffix)") { suffix += 1 }
        return "\(base)\(suffix)"
    }
}
