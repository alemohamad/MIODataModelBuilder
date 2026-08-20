//
//  PreviewSamples.swift
//  MIODataModelEditor
//
//  Created by MIO Research Labs on 2026.
//

import Foundation

/// Sample data for previews.
///
/// Built with the real model types rather than parsed from XML, so a preview
/// can never fail to render because a fixture string had a typo in it. The
/// `Task` entity deliberately carries the two spellings Core Data ignores, so
/// the diagnostics views have something real to show.
nonisolated enum PreviewSamples {

    static let model: DataModel = makeModel()

    static var entity: ModelEntity { model.entities[1] }

    static var attribute: ModelAttribute { entity.attributes[0] }

    static var relationship: ModelRelationship { entity.relationships[0] }

    static var fetchedProperty: ModelFetchedProperty { entity.fetchedProperties[0] }

    static var entityNames: [String] { model.entities.map(\.name).sorted() }

    static var diagnostics: [Diagnostic] { ModelValidator.validate(model) }

    /// Mirrors `ContentView`'s lookup so detail and inspector previews behave
    /// the way they do in the running app.
    static func relationshipNames(inEntityNamed name: String) -> [String] {
        model.entity(named: name)?.relationships.map(\.name).sorted() ?? []
    }

    static func attributes(inEntityNamed name: String) -> [ModelAttribute] {
        model.attributes(inEntityNamed: name)
    }

    static var document: MIODataModelEditorDocument {
        var bundle = ModelBundle.newDocument()
        bundle.versions[0].model = model
        return MIODataModelEditorDocument(bundle: bundle)
    }

    /// A two-version package whose current version is not the first one, so a
    /// preview shows the picker at all and shows the viewed-versus-current
    /// split rather than the case where the two coincide.
    static var versionedDocument: MIODataModelEditorDocument {
        var bundle = ModelBundle.newDocument()
        bundle.versions[0].model = model
        bundle.addVersion(named: "Model 2", copying: "Model.xcdatamodel")
        bundle.currentVersionName = "Model 2.xcdatamodel"
        return MIODataModelEditorDocument(bundle: bundle)
    }

    // MARK: - Construction

    private static func makeModel() -> DataModel {
        var model = DataModel()
        model.entities = [makeAccount(), makeEmployee(), makeTask()]
        return model
    }

    private static func makeAccount() -> ModelEntity {
        var entity = ModelEntity(name: "Account")
        entity.representedClassName = "Account"
        entity.isAbstract = true
        entity.syncable = true

        var identifier = ModelAttribute(name: "identifier", type: .uuid)
        identifier.usesScalarValueType = false

        var name = ModelAttribute(name: "name", type: .string)
        name.optional = true

        var balance = ModelAttribute(name: "balance", type: .decimal)
        balance.optional = true
        balance.defaultValueString = "0.0"

        entity.attributes = [balance, identifier, name]
        return entity
    }

    private static func makeEmployee() -> ModelEntity {
        var entity = ModelEntity(name: "Employee")
        entity.representedClassName = "Employee"
        entity.parentEntityName = "Account"
        entity.syncable = true

        var hiredAt = ModelAttribute(name: "hiredAt", type: .date)
        hiredAt.usesScalarValueType = false

        var rank = ModelAttribute(name: "rank", type: .integer16)
        rank.optional = true
        rank.minValueString = "0"
        rank.maxValueString = "10"
        rank.defaultValueString = "0"
        rank.usesScalarValueType = true

        var active = ModelAttribute(name: "isActive", type: .boolean)
        active.defaultValueString = "YES"

        // Derived across the to-one `manager`, from an attribute Employee
        // inherits rather than declares, so the pickers have to walk the parent
        // chain to offer it.
        var managerName = ModelAttribute(name: "managerName", type: .string)
        managerName.optional = true
        managerName.derived = true
        managerName.derivationExpression = "manager.name"

        entity.attributes = [active, hiredAt, managerName, rank]

        var manager = ModelRelationship(name: "manager", destinationEntityName: "Employee")
        manager.optional = true
        manager.maxCount = "1"
        manager.inverseName = "reports"
        manager.inverseEntityName = "Employee"

        var reports = ModelRelationship(name: "reports", destinationEntityName: "Employee")
        reports.optional = true
        reports.toMany = true
        reports.deletionRule = .cascade
        reports.inverseName = "manager"
        reports.inverseEntityName = "Employee"

        entity.relationships = [manager, reports]

        var senior = ModelFetchedProperty(name: "seniorReports")
        senior.optional = true
        senior.hasFetchRequestElement = true
        senior.fetchTargetEntityName = "Employee"
        senior.predicateString = "rank > 5"
        entity.fetchedProperties = [senior]

        entity.userInfo = UserInfoBlock(isPresent: true, entries: [
            UserInfoEntry(key: "exportName", value: "employee"),
            UserInfoEntry(key: "syncPolicy", value: "server")
        ])

        return entity
    }

    /// Carries both ignored spellings, so the diagnostics banner and sheet have
    /// real findings to render.
    private static func makeTask() -> ModelEntity {
        var entity = ModelEntity(name: "Task")
        entity.representedClassName = "Task"
        entity.syncable = true
        entity.strayAbstract = "YES"

        var done = ModelAttribute(name: "isDone", type: .boolean)
        done.usesScalarValueType = false
        done.strayDefaultValue = "NO"

        var title = ModelAttribute(name: "title", type: .string)
        title.usesScalarValueType = true

        entity.attributes = [done, title]
        return entity
    }
}
