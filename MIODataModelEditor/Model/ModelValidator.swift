//
//  ModelValidator.swift
//  MIODataModelEditor
//
//  Created by MIO Research Labs on 2026.
//

import Foundation

/// A problem found in a model, and whether the editor can fix it.
nonisolated struct Diagnostic: Identifiable, Equatable, Sendable {
    enum Severity: Int, Comparable, Sendable {
        case info, warning, error
        static func < (lhs: Severity, rhs: Severity) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    /// The kinds of problem the editor knows how to recognise.
    ///
    /// The first two are the same defect twice over: an attribute name Core
    /// Data does not read, written by a generator that read the correct one.
    /// Core Data parses the file without complaint and ignores the value, so
    /// nothing surfaces until behaviour is subtly wrong at runtime.
    enum Kind: String, Sendable {
        case strayDefaultValue
        case strayAbstract
        case danglingDestination
        case missingInverse
        case duplicateName
        case duplicateClassName
        case missingParentEntity

        var isRepairable: Bool {
            switch self {
            case .strayDefaultValue, .strayAbstract: true
            default: false
            }
        }
    }

    let id = UUID()
    var kind: Kind
    var severity: Severity
    var entityName: String
    var propertyName: String?
    var message: String

    var location: String {
        guard let propertyName else { return entityName }
        return "\(entityName).\(propertyName)"
    }
}

/// Inspects a model for defects, and repairs the two that are mechanical.
nonisolated enum ModelValidator {
    static func validate(_ model: DataModel) -> [Diagnostic] {
        var out: [Diagnostic] = []
        var seenEntityNames: Set<String> = []
        var classNameOwners: [String: String] = [:]

        for entity in model.entities {
            if !seenEntityNames.insert(entity.name).inserted {
                out.append(Diagnostic(kind: .duplicateName, severity: .error,
                                      entityName: entity.name, propertyName: nil,
                                      message: "Two entities are named \(entity.name)."))
            }

            // Every entity generates `<ClassName>+CoreDataClass.swift`, so a
            // class name used twice means one entity's class silently
            // overwrites the other's. Renaming an entity without renaming its
            // class is how a model arrives here. `NSManagedObject` is exempt:
            // entities with no class of their own all share it, legitimately.
            if let className = entity.representedClassName,
               className != "NSManagedObject" {
                if let owner = classNameOwners[className] {
                    out.append(Diagnostic(kind: .duplicateClassName, severity: .error,
                                          entityName: entity.name, propertyName: nil,
                                          message: "Class \(className) is already used by \(owner). The generator writes one file per class, so one of these two entities loses its class."))
                } else {
                    classNameOwners[className] = entity.name
                }
            }

            if let stray = entity.strayAbstract {
                out.append(Diagnostic(kind: .strayAbstract, severity: .warning,
                                      entityName: entity.name, propertyName: nil,
                                      message: "Uses abstract=\"\(stray)\". Core Data reads isAbstract and ignores this, so the entity is not actually abstract."))
            }

            if let parent = entity.parentEntityName, !parent.isEmpty, model.entity(named: parent) == nil {
                out.append(Diagnostic(kind: .missingParentEntity, severity: .error,
                                      entityName: entity.name, propertyName: nil,
                                      message: "Parent entity \(parent) does not exist in this model."))
            }

            var seenPropertyNames: Set<String> = []

            for attribute in entity.attributes {
                if !seenPropertyNames.insert(attribute.name).inserted {
                    out.append(Diagnostic(kind: .duplicateName, severity: .error,
                                          entityName: entity.name, propertyName: attribute.name,
                                          message: "Duplicate property name."))
                }
                if let stray = attribute.strayDefaultValue {
                    out.append(Diagnostic(kind: .strayDefaultValue, severity: .warning,
                                          entityName: entity.name, propertyName: attribute.name,
                                          message: "Default is written as defaultValue=\"\(stray)\". Core Data reads defaultValueString and ignores this, so the attribute has no default."))
                }
            }

            for relationship in entity.relationships {
                if !seenPropertyNames.insert(relationship.name).inserted {
                    out.append(Diagnostic(kind: .duplicateName, severity: .error,
                                          entityName: entity.name, propertyName: relationship.name,
                                          message: "Duplicate property name."))
                }

                if let destination = relationship.destinationEntityName {
                    if model.entity(named: destination) == nil {
                        out.append(Diagnostic(kind: .danglingDestination, severity: .error,
                                              entityName: entity.name, propertyName: relationship.name,
                                              message: "Destination entity \(destination) does not exist in this model."))
                    }
                } else {
                    out.append(Diagnostic(kind: .danglingDestination, severity: .error,
                                          entityName: entity.name, propertyName: relationship.name,
                                          message: "Relationship has no destination entity."))
                }

                if relationship.inverseName == nil {
                    out.append(Diagnostic(kind: .missingInverse, severity: .info,
                                          entityName: entity.name, propertyName: relationship.name,
                                          message: "No inverse relationship. Core Data can behave unpredictably without one."))
                }
            }
        }

        return out
    }

    // MARK: - Repairs

    /// Rewrites every `defaultValue` into `defaultValueString`, and every
    /// `abstract` into `isAbstract`.
    ///
    /// Returns how many values were moved. A property that already carries the
    /// live spelling keeps it and simply drops the dead one, rather than
    /// letting the ignored value overwrite the one Core Data actually reads.
    @discardableResult
    static func repairStrayAttributes(in model: inout DataModel) -> Int {
        var count = 0

        for entityIndex in model.entities.indices {
            if let stray = model.entities[entityIndex].strayAbstract {
                if model.entities[entityIndex].isAbstract == nil {
                    model.entities[entityIndex].isAbstract = (stray == "YES")
                }
                model.entities[entityIndex].strayAbstract = nil
                // The attribute set changed, so canonical order applies now.
                model.entities[entityIndex].extras.sourceAttributeOrder = []
                count += 1
            }

            for attributeIndex in model.entities[entityIndex].attributes.indices {
                guard let stray = model.entities[entityIndex].attributes[attributeIndex].strayDefaultValue else { continue }
                if model.entities[entityIndex].attributes[attributeIndex].defaultValueString == nil {
                    model.entities[entityIndex].attributes[attributeIndex].defaultValueString = stray
                }
                model.entities[entityIndex].attributes[attributeIndex].strayDefaultValue = nil
                model.entities[entityIndex].attributes[attributeIndex].extras.sourceAttributeOrder = []
                count += 1
            }
        }

        return count
    }
}
