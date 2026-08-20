//
//  ValidatorTests.swift
//  MIODataModelEditorTests
//
//  Created by MIO Research Labs on 2026.
//

import Foundation
import Testing
@testable import MIODataModelEditor

@Suite("Validator")
struct ValidatorTests {

    private func decode(_ source: String) throws -> DataModel {
        ModelDecoder.decode(try XMLReader.read(data: Data(source.utf8)))
    }

    @Test("defaultValue is parsed apart from defaultValueString")
    func strayDefaultIsKeptSeparate() throws {
        let model = try decode(ModelFixtures.generatorFlavoured)
        let task = try #require(model.entity(named: "Task"))
        let isDone = try #require(task.attributes.first { $0.name == "isDone" })

        // Core Data reads defaultValueString and ignores defaultValue, so the
        // attribute genuinely has no default however the file reads.
        #expect(isDone.strayDefaultValue == "NO")
        #expect(isDone.defaultValueString == nil)
    }

    @Test("abstract is parsed apart from isAbstract")
    func strayAbstractIsKeptSeparate() throws {
        let model = try decode(ModelFixtures.generatorFlavoured)
        let task = try #require(model.entity(named: "Task"))

        #expect(task.strayAbstract == "YES")
        #expect(task.isAbstract == nil)
    }

    @Test("Both ignored spellings are reported as repairable warnings")
    func straysAreDiagnosed() throws {
        let diagnostics = ModelValidator.validate(try decode(ModelFixtures.generatorFlavoured))

        let defaults = diagnostics.filter { $0.kind == .strayDefaultValue }
        let abstracts = diagnostics.filter { $0.kind == .strayAbstract }

        #expect(defaults.count == 1)
        #expect(abstracts.count == 1)
        #expect(defaults.allSatisfy { $0.severity == .warning && $0.kind.isRepairable })
        #expect(defaults.first?.location == "Task.isDone")
    }

    @Test("Repair moves the values onto the names Core Data reads")
    func repairMovesValues() throws {
        var model = try decode(ModelFixtures.generatorFlavoured)
        let repaired = ModelValidator.repairStrayAttributes(in: &model)
        #expect(repaired == 2)

        let task = try #require(model.entity(named: "Task"))
        #expect(task.isAbstract == true)
        #expect(task.strayAbstract == nil)

        let isDone = try #require(task.attributes.first { $0.name == "isDone" })
        #expect(isDone.defaultValueString == "NO")
        #expect(isDone.strayDefaultValue == nil)

        #expect(ModelValidator.validate(model).allSatisfy { !$0.kind.isRepairable })
    }

    @Test("Repair emits the live spellings and drops the dead ones")
    func repairChangesTheOutput() throws {
        var model = try decode(ModelFixtures.generatorFlavoured)
        ModelValidator.repairStrayAttributes(in: &model)
        let output = XMLWriter.write(ModelEncoder.encode(model))

        #expect(output.contains("isAbstract=\"YES\""))
        #expect(output.contains("defaultValueString=\"NO\""))
        #expect(!output.contains(" abstract=\""))
        #expect(!output.contains(" defaultValue=\""))
    }

    @Test("Repair never lets an ignored value overwrite a live one")
    func repairPrefersTheLiveSpelling() throws {
        var model = try decode("""
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <model type="com.apple.IDECoreDataModeler.DataModel" documentVersion="1.0" minimumToolsVersion="Automatic" sourceLanguage="Swift" userDefinedModelVersionIdentifier="">
            <entity name="Thing" representedClassName="Thing" syncable="YES">
                <attribute name="count" attributeType="Integer 16" defaultValueString="7" defaultValue="99"/>
            </entity>
        </model>
        """)

        ModelValidator.repairStrayAttributes(in: &model)
        let count = try #require(model.entity(named: "Thing")?.attributes.first)

        // 7 is what Core Data was already using. 99 was never in effect.
        #expect(count.defaultValueString == "7")
        #expect(count.strayDefaultValue == nil)
    }

    @Test("A dangling relationship destination is an error")
    func danglingDestinationIsReported() throws {
        let model = try decode("""
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <model type="com.apple.IDECoreDataModeler.DataModel" documentVersion="1.0" minimumToolsVersion="Automatic" sourceLanguage="Swift" userDefinedModelVersionIdentifier="">
            <entity name="Thing" representedClassName="Thing" syncable="YES">
                <relationship name="ghost" optional="YES" maxCount="1" deletionRule="Nullify" destinationEntity="Nowhere"/>
            </entity>
        </model>
        """)

        let diagnostics = ModelValidator.validate(model)
        let dangling = try #require(diagnostics.first { $0.kind == .danglingDestination })
        #expect(dangling.severity == .error)
        #expect(dangling.location == "Thing.ghost")
    }

    /// Two entities renamed from the editor's default both keep the class name
    /// they were born with. The generator writes one file per class, so the
    /// second entity's class overwrites the first's and the properties files
    /// extend a type nobody generated.
    @Test("Two entities sharing a class name is an error")
    func duplicateClassNameIsReported() throws {
        let model = try decode("""
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <model type="com.apple.IDECoreDataModeler.DataModel" documentVersion="1.0" minimumToolsVersion="Automatic" sourceLanguage="Swift" userDefinedModelVersionIdentifier="">
            <entity name="Folder" representedClassName="Entity" syncable="YES"/>
            <entity name="Todo" representedClassName="Entity" syncable="YES"/>
        </model>
        """)

        let diagnostics = ModelValidator.validate(model)
        let duplicate = try #require(diagnostics.first { $0.kind == .duplicateClassName })
        #expect(duplicate.severity == .error)
        #expect(duplicate.entityName == "Todo")
        #expect(duplicate.message.contains("Folder"))
    }

    /// Entities with no class of their own all report NSManagedObject, which is
    /// how Core Data works rather than a collision.
    @Test("NSManagedObject shared by many entities is not a collision")
    func sharedNSManagedObjectIsNotReported() throws {
        let model = try decode("""
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <model type="com.apple.IDECoreDataModeler.DataModel" documentVersion="1.0" minimumToolsVersion="Automatic" sourceLanguage="Swift" userDefinedModelVersionIdentifier="">
            <entity name="Folder" representedClassName="NSManagedObject" syncable="YES"/>
            <entity name="Todo" representedClassName="NSManagedObject" syncable="YES"/>
        </model>
        """)

        #expect(!ModelValidator.validate(model).contains { $0.kind == .duplicateClassName })
    }

    @Test("A clean model reports nothing repairable")
    func canonicalModelIsClean() throws {
        let diagnostics = ModelValidator.validate(try decode(ModelFixtures.canonical))
        #expect(diagnostics.allSatisfy { !$0.kind.isRepairable })
        #expect(!diagnostics.contains { $0.severity == .error })
    }
}
