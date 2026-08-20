//
//  DataModel+Adding.swift
//  MIODataModelEditor
//
//  Created by MIO Research Labs on 2026.
//

import Foundation

/// What a newly created entity, property or configuration looks like.
///
/// One definition per kind, because there are two ways to reach each of them
/// now: the `+` under the table and the Editor menu. Two copies of "a new
/// relationship is optional and to-one" is one copy too many, and the copies
/// that already existed had started to matter: adding an entity was written
/// out twice, in the sidebar and in the window's own menu action.
///
/// Each returns the name it chose, which is what the caller selects so the
/// inspector is ready for a rename.
nonisolated extension DataModel {
    @discardableResult
    mutating func addEntity() -> String {
        var entity = ModelEntity(name: uniqueEntityName())
        entity.representedClassName = entity.name
        entity.syncable = true
        entities.append(entity)
        return entity.name
    }

    @discardableResult
    mutating func addConfiguration() -> String {
        let configuration = ModelConfiguration(name: uniqueConfigurationName())
        configurations.append(configuration)
        return configuration.name
    }

    /// A configuration name not already taken, of the form `base`, `base 2`,
    /// `base 3`, which is how ``uniqueEntityName(base:)`` numbers them.
    ///
    /// `Default` counts as taken even in the normal case where the file does
    /// not declare it, since the sidebar shows it either way.
    func uniqueConfigurationName(base: String = "Configuration") -> String {
        let taken = Set(sidebarConfigurations.map(\.name))
        var candidate = base
        var suffix = 1
        while taken.contains(candidate) {
            suffix += 1
            candidate = "\(base) \(suffix)"
        }
        return candidate
    }
}

nonisolated extension ModelEntity {
    @discardableResult
    mutating func addAttribute() -> String {
        var attribute = ModelAttribute(name: uniquePropertyName(base: "attribute"), type: .undefined)
        attribute.optional = true
        attributes.append(attribute)
        return attribute.name
    }

    @discardableResult
    mutating func addRelationship() -> String {
        var relationship = ModelRelationship(name: uniquePropertyName(base: "relationship"))
        relationship.optional = true
        // Xcode's default is a to-one, which the file spells as maxCount="1".
        relationship.maxCount = "1"
        relationships.append(relationship)
        return relationship.name
    }

    @discardableResult
    mutating func addFetchedProperty() -> String {
        let property = ModelFetchedProperty(name: uniquePropertyName(base: "fetchedProperty"))
        fetchedProperties.append(property)
        return property.name
    }
}
