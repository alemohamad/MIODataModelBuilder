//
//  DerivationTests.swift
//  MIODataModelEditorTests
//
//  Created by MIO Research Labs on 2026.
//
//  `derived` and `derivationExpression` were read, written and editable before
//  any of this, and covered by nothing. They are also the two fields nothing
//  else in the toolchain validates: neither Xcode's model editor nor `momc`
//  looks at the expression, so a misspelled keypath reaches runtime.
//
//  Two promises are under test. The file survives a round trip, and the
//  inspector's pickers never rewrite an expression they cannot represent.
//

import Foundation
import SwiftUI
import Testing
@testable import MIODataModelEditor

@Suite("Derivation expressions")
struct DerivationExpressionTests {

    private func attribute(_ expression: String?, derived: Bool = true) -> ModelAttribute {
        var a = ModelAttribute(name: "legalEntityName", type: .string)
        a.derived = derived ? true : nil
        a.derivationExpression = expression
        return a
    }

    @Test("A one-hop keypath reads as a relationship and an attribute")
    func keyPath() {
        let parsed = attribute("legalEntity.name").keyPathDerivation
        #expect(parsed?.relationshipName == "legalEntity")
        #expect(parsed?.attributeName == "name")
        #expect(parsed?.expression == "legalEntity.name")
    }

    @Test("Surrounding whitespace does not stop it reading")
    func trimmed() {
        #expect(attribute("  legalEntity.name  ").keyPathDerivation?.attributeName == "name")
    }

    @Test("Forms the pickers cannot build are refused rather than reshaped",
          arguments: ["count:(installments)",
                      "sum:(lines.amount)",
                      "now()",
                      "canonical:(name)",
                      "firstName ++ \" \" ++ lastName",
                      "legalEntity.address.city",
                      "legalEntity.",
                      ".name",
                      "legalEntity",
                      "legalEntity .name",
                      "9legalEntity.name",
                      "",
                      "   "])
    func refused(_ expression: String) {
        #expect(attribute(expression).keyPathDerivation == nil)
    }

    @Test("Core Data's to-many forms are kept whole, not read as a keypath",
          arguments: ["reports.@count",
                      "lines.@sum.amount",
                      "@count",
                      "installments.@max.dueDate"])
    func toManyOperations(_ expression: String) {
        // Apple supports deriving across a to-many, but through an @operation
        // component rather than a plain keypath. The pickers do not build these
        // yet, so they take the custom-expression path and survive untouched.
        let a = attribute(expression)
        #expect(a.keyPathDerivation == nil)
        #expect(a.hasAdvancedDerivation)
        #expect(a.derivationExpression == expression)
    }

    @Test("An underscored name is a name, not an expression")
    func underscores() {
        #expect(attribute("legal_entity.legal_name").keyPathDerivation?.attributeName == "legal_name")
    }

    @Test("Derived with no expression is called out separately from an advanced one")
    func states() {
        #expect(attribute(nil).isDerivedWithoutExpression)
        #expect(attribute(nil).hasAdvancedDerivation == false)

        #expect(attribute("count:(installments)").hasAdvancedDerivation)
        #expect(attribute("count:(installments)").isDerivedWithoutExpression == false)

        #expect(attribute("legalEntity.name").hasAdvancedDerivation == false)
        #expect(attribute("legalEntity.name").isDerivedWithoutExpression == false)
    }

    @Test("An attribute that is not marked derived is in neither state")
    func notDerived() {
        let plain = attribute("legalEntity.name", derived: false)
        #expect(plain.isDerived == false)
        #expect(plain.hasAdvancedDerivation == false)
        #expect(plain.isDerivedWithoutExpression == false)
        // Still readable, because an expression left behind by a toggle is
        // inert rather than wrong, and must not be discarded.
        #expect(plain.keyPathDerivation?.attributeName == "name")
    }
}

@Suite("Attributes visible on an entity")
struct VisibleAttributeTests {

    private func model() -> DataModel {
        var parent = ModelEntity(name: "CoreEntity")
        parent.attributes = [ModelAttribute(name: "identifier", type: .uuid),
                             ModelAttribute(name: "name", type: .string)]

        var child = ModelEntity(name: "LegalEntity")
        child.parentEntityName = "CoreEntity"
        child.attributes = [ModelAttribute(name: "vatNumber", type: .string)]

        var model = DataModel()
        model.entities = [parent, child]
        return model
    }

    @Test("Inherited attributes are offered, not just the entity's own")
    func inherited() {
        let names = model().attributes(inEntityNamed: "LegalEntity").map(\.name)
        #expect(names == ["identifier", "name", "vatNumber"])
    }

    @Test("A redeclared name shadows the parent's rather than appearing twice")
    func shadowing() {
        var model = model()
        var override = ModelAttribute(name: "name", type: .string)
        override.defaultValueString = "child"
        model.entities[1].attributes.append(override)

        let found = model.attributes(inEntityNamed: "LegalEntity")
        #expect(found.filter { $0.name == "name" }.count == 1)
        #expect(found.first { $0.name == "name" }?.defaultValueString == "child")
    }

    @Test("A parent chain that loops terminates instead of hanging")
    func cycle() {
        var model = model()
        model.entities[0].parentEntityName = "LegalEntity"
        #expect(model.attributes(inEntityNamed: "LegalEntity").isEmpty == false)
    }

    @Test("An entity that is not there has nothing to offer")
    func missing() {
        #expect(model().attributes(inEntityNamed: "Nonexistent").isEmpty)
    }
}

@Suite("Derivation pickers")
@MainActor
struct DerivationBindingTests {

    private static func relationship(_ name: String,
                                     to destination: String,
                                     toMany: Bool = false) -> ModelRelationship {
        var relationship = ModelRelationship(name: name, destinationEntityName: destination)
        if toMany {
            relationship.toMany = true
        } else {
            relationship.maxCount = "1"
        }
        return relationship
    }

    private let relationships: [ModelRelationship] = [
        relationship("legalEntity", to: "LegalEntity"),
        relationship("lines", to: "LegalEntity", toMany: true)
    ]

    private func sources(_ entityName: String) -> [ModelAttribute] {
        entityName == "LegalEntity" ? [ModelAttribute(name: "name", type: .string),
                                       ModelAttribute(name: "vatNumber", type: .string)] : []
    }

    /// Drives the two bindings the way the pickers do, and reports what the
    /// file would end up holding.
    private func choose(relationship: String? = nil,
                        attribute attributeName: String? = nil,
                        startingFrom expression: String? = nil) -> String? {
        var stored = ModelAttribute(name: "legalEntityName", type: .string)
        stored.derived = true
        stored.derivationExpression = expression
        var draft: String? = nil

        let attribute = Binding(get: { stored }, set: { stored = $0 })
        let draftBinding = Binding(get: { draft }, set: { draft = $0 })

        if let relationship {
            attribute.derivationRelationship(draft: draftBinding,
                                             relationships: relationships,
                                             attributesInEntity: sources).wrappedValue = relationship
        }
        if let attributeName {
            let current = draft ?? stored.keyPathDerivation?.relationshipName ?? ""
            attribute.derivationAttribute(relationship: current).wrappedValue = attributeName
        }
        return stored.derivationExpression
    }

    @Test("Choosing both halves writes the keypath")
    func writesTheKeyPath() {
        #expect(choose(relationship: "legalEntity", attribute: "name") == "legalEntity.name")
    }

    @Test("A relationship on its own is not written, because it is not an expression")
    func halfChosenIsNotWritten() {
        #expect(choose(relationship: "legalEntity", attribute: nil) == nil)
    }

    @Test("Repointing keeps the attribute when the new destination also has it")
    func repointingKeepsTheAttribute() {
        #expect(choose(relationship: "lines", startingFrom: "legalEntity.name") == "lines.name")
    }

    @Test("Repointing clears the attribute when the new destination lacks it")
    func repointingClearsTheAttribute() {
        // "Unknown" resolves to no attributes at all, so "name" cannot survive.
        let unknown = Self.relationship("unknown", to: "Unknown")

        var stored = ModelAttribute(name: "legalEntityName", type: .string)
        stored.derived = true
        stored.derivationExpression = "legalEntity.name"
        var draft: String? = nil

        Binding(get: { stored }, set: { stored = $0 })
            .derivationRelationship(draft: Binding(get: { draft }, set: { draft = $0 }),
                                    relationships: relationships + [unknown],
                                    attributesInEntity: sources)
            .wrappedValue = "unknown"

        #expect(stored.derivationExpression == nil)
    }

    @Test("Clearing either half clears the expression")
    func clearing() {
        #expect(choose(relationship: "", attribute: nil, startingFrom: "legalEntity.name") == nil)
        #expect(choose(relationship: nil, attribute: "", startingFrom: "legalEntity.name") == nil)
    }
}

@Suite("Derivation round trip")
struct DerivationRoundTripTests {

    /// Both spellings on one attribute, and an expression the pickers cannot
    /// represent on another, so the byte-exact check covers the escape hatch
    /// as well as the shape the editor understands.
    private static let source = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <model type="com.apple.IDECoreDataModeler.DataModel" documentVersion="1.0" lastSavedToolsVersion="23231" systemVersion="24A335" minimumToolsVersion="Automatic" sourceLanguage="Swift" userDefinedModelVersionIdentifier="">
        <entity name="LegalEntity" representedClassName="LegalEntity" syncable="YES">
            <attribute name="identifier" attributeType="UUID" usesScalarValueType="NO"/>
            <attribute name="name" attributeType="String"/>
        </entity>
        <entity name="LegalEntityPaymentInstallment" representedClassName="LegalEntityPaymentInstallment" syncable="YES">
            <attribute name="fullLabel" optional="YES" attributeType="String" derived="YES" derivationExpression="firstName ++ &quot; &quot; ++ lastName"/>
            <attribute name="legalEntityName" optional="YES" attributeType="String" derived="YES" derivationExpression="legalEntity.name"/>
            <relationship name="legalEntity" optional="YES" maxCount="1" deletionRule="Nullify" destinationEntity="LegalEntity"/>
        </entity>
    </model>

    """

    private func decoded() throws -> DataModel {
        ModelDecoder.decode(try XMLReader.read(data: Data(Self.source.utf8)))
    }

    @Test("A model carrying derivations re-emits byte for byte")
    func byteExact() throws {
        let output = XMLWriter.write(ModelEncoder.encode(try decoded()))
        #expect(output == Self.source)
    }

    @Test("Both fields survive the decode")
    func fieldsSurvive() throws {
        let entity = try #require(try decoded().entity(named: "LegalEntityPaymentInstallment"))
        let mirror = try #require(entity.attributes.first { $0.name == "legalEntityName" })

        #expect(mirror.isDerived)
        #expect(mirror.derivationExpression == "legalEntity.name")
        #expect(mirror.keyPathDerivation?.relationshipName == "legalEntity")
    }

    @Test("An expression the pickers cannot show is kept exactly as written")
    func advancedExpressionIsUntouched() throws {
        let entity = try #require(try decoded().entity(named: "LegalEntityPaymentInstallment"))
        let advanced = try #require(entity.attributes.first { $0.name == "fullLabel" })

        #expect(advanced.hasAdvancedDerivation)
        #expect(advanced.derivationExpression == "firstName ++ \" \" ++ lastName")
    }
}
