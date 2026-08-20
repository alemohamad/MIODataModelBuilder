//
//  ModelEntityTests.swift
//  MIODataModelEditorTests
//
//  Created by MIO Research Labs on 2026.
//

import Foundation
import Testing
@testable import MIODataModelEditor

@Suite("Entity property naming")
struct ModelEntityTests {

    private func entity(attributes: [String] = [],
                        relationships: [String] = [],
                        fetched: [String] = []) -> ModelEntity {
        var entity = ModelEntity(name: "Thing")
        entity.attributes = attributes.map { ModelAttribute(name: $0, type: .string) }
        entity.relationships = relationships.map { ModelRelationship(name: $0) }
        entity.fetchedProperties = fetched.map { ModelFetchedProperty(name: $0) }
        return entity
    }

    @Test("Property names span all three kinds")
    func propertyNamesSpanEveryKind() {
        let entity = entity(attributes: ["a"], relationships: ["r"], fetched: ["f"])
        #expect(entity.propertyNames == ["a", "r", "f"])
    }

    @Test("An unused base name is returned unchanged")
    func freeNameIsUsedAsIs() {
        #expect(entity().uniquePropertyName(base: "attribute") == "attribute")
    }

    @Test("A taken name gains the first free numeric suffix")
    func takenNameGetsASuffix() {
        let entity = entity(attributes: ["attribute", "attribute1", "attribute2"])
        #expect(entity.uniquePropertyName(base: "attribute") == "attribute3")
    }

    @Test("Gaps in the numbering are filled rather than skipped")
    func gapsAreFilled() {
        let entity = entity(attributes: ["attribute", "attribute2"])
        #expect(entity.uniquePropertyName(base: "attribute") == "attribute1")
    }

    /// Core Data gives attributes, relationships and fetched properties one
    /// namespace, so a new attribute must not collide with a relationship.
    @Test("Uniqueness is checked across all three kinds")
    func uniquenessCrossesKinds() {
        let entity = entity(attributes: ["shared"], relationships: ["shared1"], fetched: ["shared2"])
        #expect(entity.uniquePropertyName(base: "shared") == "shared3")
    }

    @Test("A name colliding across kinds is reported as a duplicate")
    func crossKindCollisionIsDiagnosed() {
        var model = DataModel()
        model.entities = [entity(attributes: ["clash"], relationships: ["clash"])]

        let duplicates = ModelValidator.validate(model).filter { $0.kind == .duplicateName }
        #expect(duplicates.count == 1)
        #expect(duplicates.first?.location == "Thing.clash")
    }

    // MARK: - Renaming

    @Test("The class name follows a rename while it matches")
    func renameCarriesTheClassName() {
        var entity = ModelEntity(name: "Entity")
        entity.representedClassName = "Entity"

        entity.rename(to: "Folder")

        #expect(entity.name == "Folder")
        #expect(entity.representedClassName == "Folder")
    }

    /// The escape hatch for a name the Objective-C runtime has taken: once the
    /// two differ, the class name is the user's and a rename must not touch it.
    @Test("A deliberately different class name survives a rename")
    func renameLeavesADivergedClassNameAlone() {
        var entity = ModelEntity(name: "Category")
        entity.representedClassName = "MIOCategory"

        entity.rename(to: "ProductCategory")

        #expect(entity.name == "ProductCategory")
        #expect(entity.representedClassName == "MIOCategory")
    }

    /// No class name written means Core Data uses NSManagedObject. A rename has
    /// nothing to carry and must not start writing the attribute.
    @Test("An absent class name stays absent")
    func renameLeavesAnAbsentClassNameAbsent() {
        var entity = ModelEntity(name: "Entity")
        entity.representedClassName = nil

        entity.rename(to: "Folder")

        #expect(entity.name == "Folder")
        #expect(entity.representedClassName == nil)
    }
}

/// Renaming an entity has to move every string that names it, because Core
/// Data resolves all of them by name and treats a miss as absence rather than
/// as an error.
@Suite("Renaming an entity")
struct EntityRenameTests {

    /// Folder/Todo, the pair from the guide: the child's to-one names the
    /// parent entity twice, as destination and as inverse entity.
    private func todoListModel() -> DataModel {
        var model = DataModel()
        model.entities = [entity(named: "Folder", relatedTo: "Todo", by: "todos", inverse: "folder"),
                          entity(named: "Todo", relatedTo: "Folder", by: "folder", inverse: "todos")]
        return model
    }

    private func entity(named name: String,
                        relatedTo destination: String,
                        by relationshipName: String,
                        inverse: String) -> ModelEntity {
        var relationship = ModelRelationship(name: relationshipName, destinationEntityName: destination)
        relationship.inverseName = inverse
        relationship.inverseEntityName = destination

        var entity = ModelEntity(name: name)
        entity.representedClassName = name
        entity.relationships = [relationship]
        return entity
    }

    @Test("A relationship pointing at the entity follows the rename")
    func destinationFollows() throws {
        var model = todoListModel()
        model.renameEntity(named: "Folder", to: "Folders")

        let todo = try #require(model.entity(named: "Todo"))
        let folder = try #require(todo.relationships.first)
        #expect(folder.destinationEntityName == "Folders")
        #expect(folder.inverseEntityName == "Folders")
    }

    @Test("The entity's own name and class both move")
    func theEntityItselfIsRenamed() throws {
        var model = todoListModel()
        model.renameEntity(named: "Folder", to: "Folders")

        #expect(model.entity(named: "Folder") == nil)
        let renamed = try #require(model.entity(named: "Folders"))
        #expect(renamed.representedClassName == "Folders")
    }

    @Test("The renamed entity's own relationships keep their inverse")
    func theRenamedEntityKeepsItsOwnEdges() throws {
        var model = todoListModel()
        model.renameEntity(named: "Folder", to: "Folders")

        let folders = try #require(model.entity(named: "Folders"))
        let todos = try #require(folders.relationships.first)
        #expect(todos.destinationEntityName == "Todo")
        #expect(todos.inverseEntityName == "Todo")
    }

    @Test("A subentity's parent follows the rename")
    func parentFollows() throws {
        var model = todoListModel()
        var subentity = ModelEntity(name: "SmartFolder")
        subentity.parentEntityName = "Folder"
        model.entities.append(subentity)

        model.renameEntity(named: "Folder", to: "Folders")

        let child = try #require(model.entity(named: "SmartFolder"))
        #expect(child.parentEntityName == "Folders")
    }

    @Test("A fetched property's target follows the rename")
    func fetchedPropertyTargetFollows() throws {
        var model = todoListModel()
        var fetched = ModelFetchedProperty(name: "recentFolders")
        fetched.fetchTargetEntityName = "Folder"
        model.entities[1].fetchedProperties = [fetched]

        model.renameEntity(named: "Folder", to: "Folders")

        let todo = try #require(model.entity(named: "Todo"))
        #expect(todo.fetchedProperties.first?.fetchTargetEntityName == "Folders")
    }

    @Test("Configuration membership follows the rename")
    func configurationMembershipFollows() {
        var model = todoListModel()
        var configuration = ModelConfiguration()
        configuration.name = "Cloud"
        configuration.memberEntityNames = ["Folder", "Todo"]
        model.configurations = [configuration]

        model.renameEntity(named: "Folder", to: "Folders")

        #expect(model.configurations.first?.memberEntityNames == ["Folders", "Todo"])
    }

    /// Otherwise the entity loses the position somebody arranged for it in
    /// Xcode's graph editor, silently, on save.
    @Test("The diagram box follows the rename")
    func diagramElementFollows() {
        var model = todoListModel()
        var element = DiagramElement()
        element.name = "Folder"
        model.diagramElements = [element]

        model.renameEntity(named: "Folder", to: "Folders")

        #expect(model.diagramElements.first?.name == "Folders")
    }

    @Test("Renaming to the same name changes nothing")
    func sameNameIsANoOp() {
        var model = todoListModel()
        let before = model

        model.renameEntity(named: "Folder", to: "Folder")

        #expect(model == before)
    }

    @Test("Renaming an entity that is not there changes nothing")
    func unknownEntityIsANoOp() {
        var model = todoListModel()
        let before = model

        model.renameEntity(named: "Ghost", to: "Phantom")

        #expect(model == before)
    }

    @Test("An empty name is refused rather than written")
    func emptyNameIsRefused() {
        var model = todoListModel()
        let before = model

        model.renameEntity(named: "Folder", to: "")

        #expect(model == before)
    }
}
