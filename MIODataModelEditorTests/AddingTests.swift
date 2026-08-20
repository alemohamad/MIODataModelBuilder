//
//  AddingTests.swift
//  MIODataModelEditorTests
//
//  Created by MIO Research Labs on 2026.
//

import Foundation
import Testing
@testable import MIODataModelEditor

@Suite("Adding to a model")
struct AddingTests {

    // MARK: - Entities

    @Test("A new entity carries the class name and syncable flag Xcode gives it")
    func newEntity() throws {
        var model = DataModel()
        let name = model.addEntity()

        let entity = try #require(model.entity(named: name))
        #expect(entity.name == "Entity")
        // The generator writes one class file per entity, so a new entity that
        // did not name its class would collide with the next one.
        #expect(entity.representedClassName == "Entity")
        #expect(entity.syncable == true)
    }

    @Test("Entities added in a row do not collide")
    func entityNamesAreUnique() {
        var model = DataModel()
        let names = (0..<3).map { _ in model.addEntity() }

        #expect(names == ["Entity", "Entity 2", "Entity 3"])
        #expect(model.entities.count == 3)
    }

    // MARK: - Properties

    @Test("A new attribute is optional and untyped, so it shows as a choice to make")
    func newAttribute() throws {
        var entity = ModelEntity(name: "Employee")
        let name = entity.addAttribute()

        let attribute = try #require(entity.attributes.first { $0.name == name })
        #expect(name == "attribute")
        #expect(attribute.type == .undefined)
        #expect(attribute.optional == true)
    }

    @Test("A new relationship is optional and to-one, which the file spells as maxCount 1")
    func newRelationship() throws {
        var entity = ModelEntity(name: "Employee")
        let name = entity.addRelationship()

        let relationship = try #require(entity.relationships.first { $0.name == name })
        #expect(name == "relationship")
        #expect(relationship.optional == true)
        #expect(relationship.maxCount == "1")
    }

    @Test("A new fetched property is just a name, since the predicate is the point")
    func newFetchedProperty() throws {
        var entity = ModelEntity(name: "Employee")
        let name = entity.addFetchedProperty()

        #expect(name == "fetchedProperty")
        #expect(entity.fetchedProperties.contains { $0.name == name })
    }

    @Test("The three kinds share one namespace, so a new name dodges all of them")
    func propertyNamesAreUniqueAcrossKinds() {
        var entity = ModelEntity(name: "Employee")
        entity.attributes = [ModelAttribute(name: "attribute", type: .string)]
        entity.relationships = [ModelRelationship(name: "attribute1")]

        #expect(entity.addAttribute() == "attribute2")
    }

    // MARK: - Configurations

    @Test("A new configuration does not take the implicit Default's name")
    func newConfigurationAvoidsDefault() {
        var model = DataModel()
        // The file declares no configuration at all, which is the normal case,
        // and the sidebar still shows Default.
        #expect(model.configurations.isEmpty)

        let name = model.addConfiguration()
        #expect(name == "Configuration")
        #expect(model.sidebarConfigurations.map(\.name) == ["Default", "Configuration"])
    }

    @Test("Configurations added in a row do not collide")
    func configurationNamesAreUnique() {
        var model = DataModel()
        let names = (0..<3).map { _ in model.addConfiguration() }

        #expect(names == ["Configuration", "Configuration 2", "Configuration 3"])
    }

    @Test("A configuration with no members is still written, unlike an empty Default")
    func emptyConfigurationIsWritten() throws {
        var model = DataModel()
        model.addEntity()
        let name = model.addConfiguration()

        let written = String(decoding: XMLWriter.data(ModelEncoder.encode(model)), as: UTF8.self)
        #expect(written.contains("<configuration name=\"\(name)\""))
        #expect(!written.contains("name=\"Default\""))

        // And it comes back, or adding one would look like it did nothing.
        let reloaded = ModelDecoder.decode(try XMLReader.read(data: Data(written.utf8)))
        #expect(reloaded.configuration(named: name) != nil)
        #expect(reloaded.configuration(named: name)?.memberEntityNames.isEmpty == true)
    }
}
