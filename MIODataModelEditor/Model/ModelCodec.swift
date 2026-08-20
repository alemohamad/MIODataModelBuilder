//
//  ModelCodec.swift
//  MIODataModelEditor
//
//  Created by MIO Research Labs on 2026.
//

import Foundation

// MARK: - Attribute plumbing

/// Reads XML attributes off a tag while remembering which ones were understood.
///
/// Whatever is left over at the end is exactly the set the editor does not
/// model, and gets carried through to the next save untouched.
nonisolated struct AttrCursor {
    let tag: XMLTag
    private var consumed: Set<String> = []

    init(_ tag: XMLTag) {
        self.tag = tag
    }

    mutating func string(_ key: String) -> String? {
        guard let value = tag[key] else { return nil }
        consumed.insert(key)
        return value
    }

    /// Reads a `YES`/`NO` attribute.
    ///
    /// A value that is neither is deliberately *not* consumed: it stays in
    /// `leftovers` and round-trips verbatim rather than being coerced to
    /// `false` and written back as a lie.
    mutating func flag(_ key: String) -> Bool? {
        guard let value = tag[key] else { return nil }
        switch value {
        case "YES": consumed.insert(key); return true
        case "NO":  consumed.insert(key); return false
        default:    return nil
        }
    }

    mutating func value<T: RawRepresentable>(_ key: String, _: T.Type) -> T? where T.RawValue == String {
        guard let raw = tag[key], let parsed = T(rawValue: raw) else { return nil }
        consumed.insert(key)
        return parsed
    }

    /// The unconsumed attributes, plus the source ordering, ready to store.
    var extras: NodeExtras {
        NodeExtras(attributes: tag.attributes.filter { !consumed.contains($0.name) },
                   children: [],
                   sourceAttributeOrder: tag.attributes.map(\.name))
    }
}

/// Builds an attribute list in a fixed order, skipping anything unset.
nonisolated struct AttrBuilder {
    private var attributes: [XMLAttribute] = []

    mutating func set(_ key: String, _ value: String?) {
        guard let value else { return }
        attributes.append(XMLAttribute(key, value))
    }

    mutating func flag(_ key: String, _ value: Bool?) {
        guard let value else { return }
        attributes.append(XMLAttribute(key, value ? "YES" : "NO"))
    }

    mutating func append(contentsOf extras: [XMLAttribute]) {
        attributes.append(contentsOf: extras)
    }

    /// The built attributes, replayed in the source file's order when the set
    /// of names is unchanged.
    ///
    /// Falling back to canonical order the moment anything is added or removed
    /// is deliberate: an element the user actually edited should come out in
    /// Xcode's ordering, while every untouched element stays byte-identical.
    func finish(sourceOrder: [String]) -> [XMLAttribute] {
        guard !sourceOrder.isEmpty,
              sourceOrder.count == attributes.count,
              Set(sourceOrder) == Set(attributes.map(\.name))
        else { return attributes }

        var byName: [String: XMLAttribute] = [:]
        for attribute in attributes { byName[attribute.name] = attribute }
        return sourceOrder.compactMap { byName[$0] }
    }
}

/// Re-inserts unrecognised children at the positions they held in the source.
nonisolated func MergePositionedChildren(_ known: [XMLTag], _ extras: [PositionedTag]) -> [XMLTag] {
    guard !extras.isEmpty else { return known }
    var out = known
    for extra in extras.sorted(by: { $0.index < $1.index }) {
        out.insert(extra.tag, at: min(extra.index, out.count))
    }
    return out
}

// MARK: - Decoding

/// Turns a parsed `<model>` tree into the typed model.
///
/// The rule throughout: consume what is understood, park the rest. Every helper
/// ends by stashing unconsumed attributes, the source attribute order, and any
/// unrecognised child element together with the index it held among its
/// siblings.
nonisolated enum ModelDecoder {
    static func decode(_ document: XMLDocumentText) -> DataModel {
        let root = document.root
        var model = DataModel()
        model.xmlDeclaration = document.declaration
        model.endsWithNewline = document.trailingNewline

        var cursor = AttrCursor(root)
        model.type = cursor.string("type") ?? model.type
        model.documentVersion = cursor.string("documentVersion") ?? model.documentVersion
        model.lastSavedToolsVersion = cursor.string("lastSavedToolsVersion")
        model.systemVersion = cursor.string("systemVersion")
        model.minimumToolsVersion = cursor.string("minimumToolsVersion") ?? model.minimumToolsVersion
        model.sourceLanguage = cursor.string("sourceLanguage") ?? model.sourceLanguage
        model.usedWithCloudKit = cursor.flag("usedWithCloudKit")
        model.userDefinedModelVersionIdentifier = cursor.string("userDefinedModelVersionIdentifier")
        model.extras = cursor.extras

        for (index, child) in root.children.enumerated() {
            switch child.name {
            case "entity":
                model.entities.append(decodeEntity(child))
            case "configuration":
                model.configurations.append(decodeConfiguration(child))
            case "elements":
                model.hasElementsBlock = true
                for element in child.children where element.name == "element" {
                    model.diagramElements.append(decodeDiagramElement(element))
                }
                let unknown = child.children.filter { $0.name != "element" }
                if !unknown.isEmpty {
                    let tag = XMLTag("elements", attributes: child.attributes, children: unknown)
                    model.extras.children.append(PositionedTag(index: index, tag: tag))
                }
            default:
                model.extras.children.append(PositionedTag(index: index, tag: child))
            }
        }

        return model
    }

    private static func decodeEntity(_ tag: XMLTag) -> ModelEntity {
        var entity = ModelEntity()
        var cursor = AttrCursor(tag)

        entity.name = cursor.string("name") ?? ""
        entity.representedClassName = cursor.string("representedClassName")
        entity.isAbstract = cursor.flag("isAbstract")
        entity.parentEntityName = cursor.string("parentEntity")
        entity.syncable = cursor.flag("syncable")
        entity.codeGenerationType = cursor.value("codeGenerationType", CodeGenerationType.self)
        entity.versionHashModifier = cursor.string("versionHashModifier")
        entity.renamingIdentifier = cursor.string("renamingIdentifier")
        entity.elementID = cursor.string("elementID")
        entity.coreSpotlightDisplayNameExpression = cursor.string("coreSpotlightDisplayNameExpression")

        // `abstract` is the generator's misspelling of `isAbstract`. Core Data
        // reads only the latter, so capture it separately for diagnostics.
        entity.strayAbstract = cursor.string("abstract")
        entity.extras = cursor.extras

        for (index, child) in tag.children.enumerated() {
            switch child.name {
            case "attribute":
                entity.attributes.append(decodeAttribute(child))
            case "relationship":
                entity.relationships.append(decodeRelationship(child))
            case "fetchedProperty":
                entity.fetchedProperties.append(decodeFetchedProperty(child))
            case "fetchIndex":
                entity.fetchIndexes.append(decodeFetchIndex(child))
            case "userInfo":
                entity.userInfo = decodeUserInfo(child)
            case "uniquenessConstraints":
                entity.hasUniquenessConstraintsElement = true
                for group in child.children where group.name == "uniquenessConstraint" {
                    var decoded = ModelUniquenessConstraintGroup()
                    decoded.constraints = group.children(named: "constraint").map { constraintTag in
                        var constraintCursor = AttrCursor(constraintTag)
                        var constraint = ModelUniquenessConstraint()
                        constraint.value = constraintCursor.string("value") ?? ""
                        constraint.extras = constraintCursor.extras
                        return constraint
                    }
                    entity.uniquenessConstraints.append(decoded)
                }
            default:
                entity.extras.children.append(PositionedTag(index: index, tag: child))
            }
        }

        return entity
    }

    private static func decodeAttribute(_ tag: XMLTag) -> ModelAttribute {
        var attribute = ModelAttribute()
        var cursor = AttrCursor(tag)

        attribute.name = cursor.string("name") ?? ""
        attribute.optional = cursor.flag("optional")
        attribute.transient = cursor.flag("transient")
        attribute.indexed = cursor.flag("indexed")
        attribute.type = cursor.value("attributeType", AttributeType.self) ?? .undefined
        attribute.minValueString = cursor.string("minValueString")
        attribute.minDateTimeInterval = cursor.string("minDateTimeInterval")
        attribute.maxValueString = cursor.string("maxValueString")
        attribute.maxDateTimeInterval = cursor.string("maxDateTimeInterval")
        attribute.defaultValueString = cursor.string("defaultValueString")
        attribute.defaultDateTimeInterval = cursor.string("defaultDateTimeInterval")
        attribute.usesScalarValueType = cursor.flag("usesScalarValueType")
        attribute.valueTransformerName = cursor.string("valueTransformerName")
        attribute.customClassName = cursor.string("customClassName")
        attribute.derived = cursor.flag("derived")
        attribute.derivationExpression = cursor.string("derivationExpression")
        attribute.allowsCloudEncryption = cursor.flag("allowsCloudEncryption")
        attribute.spotlightIndexingEnabled = cursor.flag("spotlightIndexingEnabled")
        attribute.preservesValueInHistoryOnDeletion = cursor.flag("preservesValueInHistoryOnDeletion")
        attribute.storedInExternalRecordFile = cursor.flag("storedInExternalRecordFile")
        attribute.versionHashModifier = cursor.string("versionHashModifier")
        attribute.renamingIdentifier = cursor.string("renamingIdentifier")
        attribute.elementID = cursor.string("elementID")
        attribute.syncable = cursor.flag("syncable")

        // The dead spelling. See ModelAttribute.strayDefaultValue.
        attribute.strayDefaultValue = cursor.string("defaultValue")
        attribute.extras = cursor.extras

        for (index, child) in tag.children.enumerated() {
            if child.name == "userInfo" {
                attribute.userInfo = decodeUserInfo(child)
            } else {
                attribute.extras.children.append(PositionedTag(index: index, tag: child))
            }
        }

        return attribute
    }

    private static func decodeRelationship(_ tag: XMLTag) -> ModelRelationship {
        var relationship = ModelRelationship()
        var cursor = AttrCursor(tag)

        relationship.name = cursor.string("name") ?? ""
        relationship.optional = cursor.flag("optional")
        relationship.transient = cursor.flag("transient")
        relationship.toMany = cursor.flag("toMany")
        relationship.maxCount = cursor.string("maxCount")
        relationship.minCount = cursor.string("minCount")
        relationship.deletionRule = cursor.value("deletionRule", DeletionRule.self) ?? .nullify
        relationship.ordered = cursor.flag("ordered")
        relationship.destinationEntityName = cursor.string("destinationEntity")
        relationship.inverseName = cursor.string("inverseName")
        relationship.inverseEntityName = cursor.string("inverseEntity")
        relationship.spotlightIndexingEnabled = cursor.flag("spotlightIndexingEnabled")
        relationship.versionHashModifier = cursor.string("versionHashModifier")
        relationship.renamingIdentifier = cursor.string("renamingIdentifier")
        relationship.elementID = cursor.string("elementID")
        relationship.syncable = cursor.flag("syncable")
        relationship.extras = cursor.extras

        for (index, child) in tag.children.enumerated() {
            if child.name == "userInfo" {
                relationship.userInfo = decodeUserInfo(child)
            } else {
                relationship.extras.children.append(PositionedTag(index: index, tag: child))
            }
        }

        return relationship
    }

    private static func decodeFetchedProperty(_ tag: XMLTag) -> ModelFetchedProperty {
        var property = ModelFetchedProperty()
        var cursor = AttrCursor(tag)

        property.name = cursor.string("name") ?? ""
        property.optional = cursor.flag("optional")
        property.syncable = cursor.flag("syncable")
        property.extras = cursor.extras

        for (index, child) in tag.children.enumerated() {
            switch child.name {
            case "fetchRequest":
                property.hasFetchRequestElement = true
                var requestCursor = AttrCursor(child)
                property.fetchRequestName = requestCursor.string("name")
                property.fetchTargetEntityName = requestCursor.string("entity")
                property.predicateString = requestCursor.string("predicateString")
                let requestExtras = requestCursor.extras
                property.fetchRequestExtraAttributes = requestExtras.attributes
                property.fetchRequestSourceOrder = requestExtras.sourceAttributeOrder
            case "userInfo":
                property.userInfo = decodeUserInfo(child)
            default:
                property.extras.children.append(PositionedTag(index: index, tag: child))
            }
        }

        return property
    }

    private static func decodeFetchIndex(_ tag: XMLTag) -> ModelFetchIndex {
        var index = ModelFetchIndex()
        var cursor = AttrCursor(tag)
        index.name = cursor.string("name") ?? ""
        index.extras = cursor.extras

        for (position, child) in tag.children.enumerated() {
            guard child.name == "fetchIndexElement" else {
                index.extras.children.append(PositionedTag(index: position, tag: child))
                continue
            }
            var elementCursor = AttrCursor(child)
            var element = ModelFetchIndexElement()
            element.property = elementCursor.string("property")
            element.expression = elementCursor.string("expression")
            element.expressionType = elementCursor.string("expressionType")
            element.type = elementCursor.value("type", FetchIndexElementType.self) ?? .binary
            element.order = elementCursor.string("order") ?? "ascending"
            element.extras = elementCursor.extras
            index.elements.append(element)
        }

        return index
    }

    private static func decodeConfiguration(_ tag: XMLTag) -> ModelConfiguration {
        var configuration = ModelConfiguration()
        var cursor = AttrCursor(tag)
        configuration.name = cursor.string("name") ?? ""
        configuration.usedWithCloudKit = cursor.flag("usedWithCloudKit")
        configuration.extras = cursor.extras

        for (index, child) in tag.children.enumerated() {
            guard child.name == "memberEntity", let name = child["name"] else {
                configuration.extras.children.append(PositionedTag(index: index, tag: child))
                continue
            }
            configuration.memberEntityNames.append(name)
        }

        return configuration
    }

    private static func decodeDiagramElement(_ tag: XMLTag) -> DiagramElement {
        var element = DiagramElement()
        var cursor = AttrCursor(tag)
        element.name = cursor.string("name") ?? ""
        element.positionX = cursor.string("positionX") ?? "0"
        element.positionY = cursor.string("positionY") ?? "0"
        element.width = cursor.string("width") ?? "0"
        element.height = cursor.string("height") ?? "0"
        element.extras = cursor.extras
        return element
    }

    private static func decodeUserInfo(_ tag: XMLTag) -> UserInfoBlock {
        var block = UserInfoBlock()
        block.isPresent = true
        for child in tag.children where child.name == "entry" {
            block.entries.append(UserInfoEntry(key: child["key"] ?? "", value: child["value"] ?? ""))
        }
        return block
    }
}

// MARK: - Encoding

/// Turns the typed model back into a `<model>` tree.
///
/// Attribute order is not a style choice here. Xcode emits attributes in a
/// fixed order and skips the ones that are unset; matching that order exactly
/// is what makes an untouched open/save a zero-line diff. Every order below was
/// derived by counting real orderings across the ~5,000 elements in the Dual
/// Link models rather than guessed.
nonisolated enum ModelEncoder {
    static func encode(_ model: DataModel) -> XMLDocumentText {
        XMLDocumentText(root: encodeRoot(model),
                        declaration: model.xmlDeclaration,
                        trailingNewline: model.endsWithNewline)
    }

    static func encodeRoot(_ model: DataModel) -> XMLTag {
        var builder = AttrBuilder()
        builder.set("type", model.type)
        builder.set("documentVersion", model.documentVersion)
        builder.set("lastSavedToolsVersion", model.lastSavedToolsVersion)
        builder.set("systemVersion", model.systemVersion)
        builder.set("minimumToolsVersion", model.minimumToolsVersion)
        builder.set("sourceLanguage", model.sourceLanguage)
        builder.flag("usedWithCloudKit", model.usedWithCloudKit)
        builder.set("userDefinedModelVersionIdentifier", model.userDefinedModelVersionIdentifier)
        builder.append(contentsOf: model.extras.attributes)

        var known = model.entities.map(encodeEntity)
        // An untouched `Default` is implicit and must not be written out, or
        // every model saved here would grow an element Xcode never put in it.
        known += model.configurations.filter { !$0.isEmptyDefault }.map(encodeConfiguration)
        var children = MergePositionedChildren(known, model.extras.children)

        // Xcode always writes the diagram positions last.
        if model.hasElementsBlock {
            children.append(XMLTag("elements", children: model.diagramElements.map(encodeDiagramElement)))
        }

        return XMLTag("model",
                      attributes: builder.finish(sourceOrder: model.extras.sourceAttributeOrder),
                      children: children)
    }

    private static func encodeEntity(_ entity: ModelEntity) -> XMLTag {
        var builder = AttrBuilder()
        builder.set("name", entity.name)
        builder.set("representedClassName", entity.representedClassName)
        builder.flag("isAbstract", entity.isAbstract)
        builder.set("parentEntity", entity.parentEntityName)
        builder.flag("syncable", entity.syncable)
        builder.set("abstract", entity.strayAbstract)
        builder.set("codeGenerationType", entity.codeGenerationType?.rawValue)
        builder.set("versionHashModifier", entity.versionHashModifier)
        builder.set("renamingIdentifier", entity.renamingIdentifier)
        builder.set("elementID", entity.elementID)
        builder.set("coreSpotlightDisplayNameExpression", entity.coreSpotlightDisplayNameExpression)
        builder.append(contentsOf: entity.extras.attributes)

        var known = entity.attributes.map(encodeAttribute)
        known += entity.relationships.map(encodeRelationship)
        known += entity.fetchedProperties.map(encodeFetchedProperty)
        known += entity.fetchIndexes.map(encodeFetchIndex)

        if entity.hasUniquenessConstraintsElement {
            let groups = entity.uniquenessConstraints.map { group in
                XMLTag("uniquenessConstraint", children: group.constraints.map { constraint in
                    var constraintBuilder = AttrBuilder()
                    constraintBuilder.set("value", constraint.value)
                    constraintBuilder.append(contentsOf: constraint.extras.attributes)
                    return XMLTag("constraint",
                                  attributes: constraintBuilder.finish(sourceOrder: constraint.extras.sourceAttributeOrder))
                })
            }
            known.append(XMLTag("uniquenessConstraints", children: groups))
        }

        known += encodeUserInfo(entity.userInfo)

        return XMLTag("entity",
                      attributes: builder.finish(sourceOrder: entity.extras.sourceAttributeOrder),
                      children: MergePositionedChildren(known, entity.extras.children))
    }

    private static func encodeAttribute(_ attribute: ModelAttribute) -> XMLTag {
        var builder = AttrBuilder()
        builder.set("name", attribute.name)
        builder.flag("optional", attribute.optional)
        builder.flag("transient", attribute.transient)
        builder.flag("indexed", attribute.indexed)
        builder.set("attributeType", attribute.type == .undefined ? nil : attribute.type.rawValue)
        builder.set("minValueString", attribute.minValueString)
        builder.set("minDateTimeInterval", attribute.minDateTimeInterval)
        builder.set("maxValueString", attribute.maxValueString)
        builder.set("maxDateTimeInterval", attribute.maxDateTimeInterval)
        builder.set("defaultValueString", attribute.defaultValueString)
        builder.set("defaultDateTimeInterval", attribute.defaultDateTimeInterval)
        builder.flag("usesScalarValueType", attribute.usesScalarValueType)
        // Emitted after usesScalarValueType because that is where the MIO
        // generator put it; keeping the slot keeps the repair diff small.
        builder.set("defaultValue", attribute.strayDefaultValue)
        builder.set("valueTransformerName", attribute.valueTransformerName)
        builder.set("customClassName", attribute.customClassName)
        builder.flag("derived", attribute.derived)
        builder.set("derivationExpression", attribute.derivationExpression)
        builder.flag("allowsCloudEncryption", attribute.allowsCloudEncryption)
        builder.flag("spotlightIndexingEnabled", attribute.spotlightIndexingEnabled)
        builder.flag("preservesValueInHistoryOnDeletion", attribute.preservesValueInHistoryOnDeletion)
        builder.flag("storedInExternalRecordFile", attribute.storedInExternalRecordFile)
        builder.set("versionHashModifier", attribute.versionHashModifier)
        builder.set("renamingIdentifier", attribute.renamingIdentifier)
        builder.set("elementID", attribute.elementID)
        builder.flag("syncable", attribute.syncable)
        builder.append(contentsOf: attribute.extras.attributes)

        return XMLTag("attribute",
                      attributes: builder.finish(sourceOrder: attribute.extras.sourceAttributeOrder),
                      children: MergePositionedChildren(encodeUserInfo(attribute.userInfo), attribute.extras.children))
    }

    private static func encodeRelationship(_ relationship: ModelRelationship) -> XMLTag {
        var builder = AttrBuilder()
        builder.set("name", relationship.name)
        builder.flag("optional", relationship.optional)
        builder.flag("transient", relationship.transient)
        builder.flag("toMany", relationship.toMany)
        builder.set("minCount", relationship.minCount)
        builder.set("maxCount", relationship.maxCount)
        builder.set("deletionRule", relationship.deletionRule.rawValue)
        builder.flag("ordered", relationship.ordered)
        builder.set("destinationEntity", relationship.destinationEntityName)
        builder.set("inverseName", relationship.inverseName)
        builder.set("inverseEntity", relationship.inverseEntityName)
        builder.flag("spotlightIndexingEnabled", relationship.spotlightIndexingEnabled)
        builder.set("versionHashModifier", relationship.versionHashModifier)
        builder.set("renamingIdentifier", relationship.renamingIdentifier)
        builder.set("elementID", relationship.elementID)
        builder.flag("syncable", relationship.syncable)
        builder.append(contentsOf: relationship.extras.attributes)

        return XMLTag("relationship",
                      attributes: builder.finish(sourceOrder: relationship.extras.sourceAttributeOrder),
                      children: MergePositionedChildren(encodeUserInfo(relationship.userInfo), relationship.extras.children))
    }

    private static func encodeFetchedProperty(_ property: ModelFetchedProperty) -> XMLTag {
        var builder = AttrBuilder()
        builder.set("name", property.name)
        builder.flag("optional", property.optional)
        builder.flag("syncable", property.syncable)
        builder.append(contentsOf: property.extras.attributes)

        var known: [XMLTag] = []
        if property.hasFetchRequestElement {
            var requestBuilder = AttrBuilder()
            requestBuilder.set("name", property.fetchRequestName)
            requestBuilder.set("entity", property.fetchTargetEntityName)
            requestBuilder.set("predicateString", property.predicateString)
            requestBuilder.append(contentsOf: property.fetchRequestExtraAttributes)
            known.append(XMLTag("fetchRequest",
                                attributes: requestBuilder.finish(sourceOrder: property.fetchRequestSourceOrder)))
        }
        known += encodeUserInfo(property.userInfo)

        return XMLTag("fetchedProperty",
                      attributes: builder.finish(sourceOrder: property.extras.sourceAttributeOrder),
                      children: MergePositionedChildren(known, property.extras.children))
    }

    private static func encodeFetchIndex(_ index: ModelFetchIndex) -> XMLTag {
        var builder = AttrBuilder()
        builder.set("name", index.name)
        builder.append(contentsOf: index.extras.attributes)

        let known = index.elements.map { element -> XMLTag in
            var elementBuilder = AttrBuilder()
            elementBuilder.set("property", element.property)
            elementBuilder.set("expression", element.expression)
            elementBuilder.set("expressionType", element.expressionType)
            elementBuilder.set("type", element.type.rawValue)
            elementBuilder.set("order", element.order)
            elementBuilder.append(contentsOf: element.extras.attributes)
            return XMLTag("fetchIndexElement",
                          attributes: elementBuilder.finish(sourceOrder: element.extras.sourceAttributeOrder))
        }

        return XMLTag("fetchIndex",
                      attributes: builder.finish(sourceOrder: index.extras.sourceAttributeOrder),
                      children: MergePositionedChildren(known, index.extras.children))
    }

    private static func encodeConfiguration(_ configuration: ModelConfiguration) -> XMLTag {
        var builder = AttrBuilder()
        builder.set("name", configuration.name)
        builder.flag("usedWithCloudKit", configuration.usedWithCloudKit)
        builder.append(contentsOf: configuration.extras.attributes)

        let members = configuration.memberEntityNames.map {
            XMLTag("memberEntity", attributes: [XMLAttribute("name", $0)])
        }

        return XMLTag("configuration",
                      attributes: builder.finish(sourceOrder: configuration.extras.sourceAttributeOrder),
                      children: MergePositionedChildren(members, configuration.extras.children))
    }

    private static func encodeDiagramElement(_ element: DiagramElement) -> XMLTag {
        var builder = AttrBuilder()
        builder.set("name", element.name)
        builder.set("positionX", element.positionX)
        builder.set("positionY", element.positionY)
        builder.set("width", element.width)
        builder.set("height", element.height)
        builder.append(contentsOf: element.extras.attributes)
        return XMLTag("element", attributes: builder.finish(sourceOrder: element.extras.sourceAttributeOrder))
    }

    private static func encodeUserInfo(_ block: UserInfoBlock) -> [XMLTag] {
        guard block.shouldEmit else { return [] }
        return [XMLTag("userInfo", children: block.entries.map {
            XMLTag("entry", attributes: [XMLAttribute("key", $0.key), XMLAttribute("value", $0.value)])
        })]
    }
}
