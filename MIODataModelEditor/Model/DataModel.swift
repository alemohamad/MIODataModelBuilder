//
//  DataModel.swift
//  MIODataModelEditor
//
//  Created by MIO Research Labs on 2026.
//

import Foundation

// MARK: - Enumerations

/// The attribute types Core Data understands, with the exact spelling used in
/// the `attributeType` XML attribute.
///
/// Note `binary`: the inspector calls it "Binary Data" but the file says
/// `Binary`. The raw value is always the file's spelling.
nonisolated enum AttributeType: String, CaseIterable, Identifiable, Sendable {
    case undefined     = "Undefined"
    case integer16     = "Integer 16"
    case integer32     = "Integer 32"
    case integer64     = "Integer 64"
    case decimal       = "Decimal"
    case double        = "Double"
    case float         = "Float"
    case string        = "String"
    case boolean       = "Boolean"
    case date          = "Date"
    case binary        = "Binary"
    case uuid          = "UUID"
    case uri           = "URI"
    case transformable = "Transformable"
    case composite     = "Composite"

    var id: String { rawValue }

    /// What the Xcode inspector shows in the Type popup.
    var displayName: String {
        switch self {
        case .binary: "Binary Data"
        default:      rawValue
        }
    }
    /// Types where a default value means nothing. Core Data offers no default
    /// for these in Xcode either, and a value typed here would be dropped.
    var takesNoDefault: Bool {
        switch self {
            case .binary, .transformable, .composite, .undefined: true
            default: false
        }
    }

}

/// Deletion rules, spelled as they appear in `deletionRule`.
nonisolated enum DeletionRule: String, CaseIterable, Identifiable, Sendable {
    case noAction = "No Action"
    case nullify  = "Nullify"
    case cascade  = "Cascade"
    case deny     = "Deny"

    var id: String { rawValue }
}

/// Xcode's Codegen popup, spelled as it appears in `codeGenerationType`.
///
/// Absent from the file means "Manual/None", which is why the model stores this
/// as an optional and only writes it when set.
nonisolated enum CodeGenerationType: String, CaseIterable, Identifiable, Sendable {
    case classDefinition = "class"
    case category        = "category"
    case manualNone      = "manual"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .classDefinition: "Class Definition"
        case .category:        "Category/Extension"
        case .manualNone:      "Manual/None"
        }
    }
}

/// Collation type of a fetch index element (`type` on `fetchIndexElement`).
nonisolated enum FetchIndexElementType: String, CaseIterable, Identifiable, Sendable {
    case binary = "Binary"
    case rTree  = "RTree"

    var id: String { rawValue }
}

// MARK: - User info

/// One `<entry key="…" value="…"/>`.
nonisolated struct UserInfoEntry: Identifiable, Equatable, Sendable {
    let id = UUID()
    var key: String = ""
    var value: String = ""
}

/// A `<userInfo>` block.
///
/// `isPresent` records that the source had the element even when it held no
/// entries, so an empty block round-trips as an empty block instead of
/// vanishing.
nonisolated struct UserInfoBlock: Equatable, Sendable {
    var isPresent: Bool = false
    var entries: [UserInfoEntry] = []

    var shouldEmit: Bool { isPresent || !entries.isEmpty }
}

// MARK: - Properties

/// An `<attribute>`.
nonisolated struct ModelAttribute: Identifiable, Equatable, Sendable {
    let id = UUID()
    var extras = NodeExtras()
    var userInfo = UserInfoBlock()

    var name: String = ""
    var type: AttributeType = .undefined

    // Tri-state on purpose. `nil` means the XML attribute was absent, and it
    // stays absent on save. Collapsing these to `Bool` would add a few thousand
    // lines of noise to the first diff of any real model.
    var optional: Bool?
    var transient: Bool?
    var indexed: Bool?
    var usesScalarValueType: Bool?
    var derived: Bool?
    var allowsCloudEncryption: Bool?
    var spotlightIndexingEnabled: Bool?
    var preservesValueInHistoryOnDeletion: Bool?
    var storedInExternalRecordFile: Bool?
    var syncable: Bool?

    var defaultValueString: String?
    var minValueString: String?
    var maxValueString: String?

    // Date bounds and defaults use a seconds-since-reference-date interval
    // rather than the `*ValueString` attributes.
    var defaultDateTimeInterval: String?
    var minDateTimeInterval: String?
    var maxDateTimeInterval: String?

    var valueTransformerName: String?
    var customClassName: String?
    var derivationExpression: String?
    var versionHashModifier: String?
    var renamingIdentifier: String?
    var elementID: String?

    /// Set when the source spelled the default as `defaultValue` instead of
    /// `defaultValueString`. Core Data ignores that spelling entirely, so the
    /// value is dead on arrival. Kept separately so the editor can report it
    /// and offer a repair rather than silently honouring or dropping it.
    var strayDefaultValue: String?

    /// The default of a Boolean attribute, as a tri-state.
    ///
    /// The file format does not agree with itself here. Models in this
    /// organisation alone spell a Boolean default `YES`, `NO`, `TRUE`,
    /// `FALSE`, `1` and `0`. All six are read. Only `YES` and `NO` are
    /// written, which is what Xcode writes.
    ///
    /// Reading never writes, so opening a model that says `0` does not dirty
    /// it. The spelling changes only when somebody picks a new value.
    var booleanDefault: Bool? {
        get {
            guard let raw = defaultValueString?.trimmingCharacters( in: .whitespaces ),
                  raw.isEmpty == false
            else { return nil }

            switch raw.uppercased() {
                case "YES", "TRUE", "1":  return true
                case "NO", "FALSE", "0":  return false
                default:                  return nil
            }
        }
        set {
            switch newValue {
                case .some(true):  defaultValueString = "YES"
                case .some(false): defaultValueString = "NO"
                case nil:          defaultValueString = nil
            }
        }
    }

    // MARK: - Dates
    //
    // A Date attribute stores its default and its bounds as seconds since Core
    // Data's REFERENCE DATE, 2001-01-01 UTC. Not the Unix epoch: 0 here is
    // 2001, and -978307200 is 1970. Getting that wrong is silent, which is why
    // the editor shows the raw interval next to the picker.

    var defaultDate: Date? {
        get { ModelAttribute.date( from: defaultDateTimeInterval ) }
        set { defaultDateTimeInterval = ModelAttribute.interval( from: newValue ) }
    }

    var minDate: Date? {
        get { ModelAttribute.date( from: minDateTimeInterval ) }
        set { minDateTimeInterval = ModelAttribute.interval( from: newValue ) }
    }

    var maxDate: Date? {
        get { ModelAttribute.date( from: maxDateTimeInterval ) }
        set { maxDateTimeInterval = ModelAttribute.interval( from: newValue ) }
    }

    /// Reading is pure: a value the file already holds is returned as-is and
    /// never reformatted, so opening a model does not dirty it.
    static func date( from raw: String? ) -> Date? {
        guard let raw = raw?.trimmingCharacters( in: .whitespaces ), raw.isEmpty == false,
              let seconds = TimeInterval( raw )
        else { return nil }
        return Date( timeIntervalSinceReferenceDate: seconds )
    }

    /// Whole seconds are written without a decimal point, which is how Xcode
    /// writes them. Otherwise setting one date would reformat it against its
    /// untouched neighbours in the same file.
    static func interval( from date: Date? ) -> String? {
        guard let date else { return nil }
        let seconds = date.timeIntervalSinceReferenceDate
        guard seconds.rounded() == seconds, seconds.magnitude < 9e15 else {
            return String( seconds )
        }
        return String( Int64( seconds ) )
    }

    /// The default value as one short line, for the attributes table.
    ///
    /// Reads whatever spelling the file uses but shows the canonical one, so a
    /// column of booleans reads YES/NO however they were written. Empty when
    /// there is no default, rather than a placeholder: a column of dashes is
    /// harder to scan than a column of gaps.
    var defaultSummary: String {
        if type.takesNoDefault { return "" }

        switch type {
            case .date:
                guard let date = defaultDate else { return defaultDateTimeInterval ?? "" }
                return date.formatted( date: .abbreviated, time: .shortened )

            case .boolean:
                guard let flag = booleanDefault else { return defaultValueString ?? "" }
                return flag ? "YES" : "NO"

            default:
                return defaultValueString ?? ""
        }
    }

    /// A date interval the file carries that is not a number, so the picker
    /// shows nothing while the value is still there.
    var unreadableDateInterval: String? {
        guard type == .date,
              let raw = defaultDateTimeInterval, raw.isEmpty == false,
              defaultDate == nil
        else { return nil }
        return raw
    }

    /// A Boolean default the file carries that this editor cannot read as a
    /// boolean, so the picker shows no selection while the value is still
    /// there. Reported rather than silently dropped.
    var unreadableBooleanDefault: String? {
        guard type == .boolean,
              let raw = defaultValueString, raw.isEmpty == false,
              booleanDefault == nil
        else { return nil }
        return raw
    }

    init(name: String = "", type: AttributeType = .undefined) {
        self.name = name
        self.type = type
    }
}

/// A `<relationship>`.
nonisolated struct ModelRelationship: Identifiable, Equatable, Sendable {
    let id = UUID()
    var extras = NodeExtras()
    var userInfo = UserInfoBlock()

    var name: String = ""
    var destinationEntityName: String?
    var inverseName: String?
    var inverseEntityName: String?
    var deletionRule: DeletionRule = .nullify

    var optional: Bool?
    var transient: Bool?
    var toMany: Bool?
    var ordered: Bool?
    var spotlightIndexingEnabled: Bool?
    var syncable: Bool?

    /// Xcode writes `maxCount="1"` for a to-one and `toMany="YES"` for a
    /// to-many; both occupy the same slot in the attribute order. Kept as
    /// strings because the file allows an explicit bound on a to-many too.
    var maxCount: String?
    var minCount: String?

    var versionHashModifier: String?
    var renamingIdentifier: String?
    var elementID: String?

    var isToMany: Bool { toMany == true }

    /// Switch between to-one and to-many.
    ///
    /// The file spells a to-one as `maxCount="1"` and a to-many as
    /// `toMany="YES"`, and the two occupy the same slot, so setting either has
    /// to clear the other. Doing it here rather than in the inspector keeps it
    /// testable and keeps the two writes in one mutation.
    mutating func setToMany( _ value: Bool ) {
        if value {
            toMany = true
            maxCount = nil
        } else {
            toMany = nil
            maxCount = "1"
        }
    }

    init(name: String = "", destinationEntityName: String? = nil) {
        self.name = name
        self.destinationEntityName = destinationEntityName
    }
}

/// A `<fetchedProperty>`. Its predicate lives in a nested `<fetchRequest>`.
nonisolated struct ModelFetchedProperty: Identifiable, Equatable, Sendable {
    let id = UUID()
    var extras = NodeExtras()
    var userInfo = UserInfoBlock()

    var name: String = ""
    var optional: Bool?
    var syncable: Bool?

    var hasFetchRequestElement: Bool = false
    var fetchRequestName: String?
    var fetchTargetEntityName: String?
    var predicateString: String?
    /// Attributes of the nested `<fetchRequest>` this editor does not model.
    var fetchRequestExtraAttributes: [XMLAttribute] = []
    var fetchRequestSourceOrder: [String] = []

    init(name: String = "") {
        self.name = name
    }
}

/// A `<fetchIndexElement>`.
nonisolated struct ModelFetchIndexElement: Identifiable, Equatable, Sendable {
    let id = UUID()
    var extras = NodeExtras()

    var property: String?
    var expression: String?
    var expressionType: String?
    var type: FetchIndexElementType = .binary
    var order: String = "ascending"
}

/// A `<fetchIndex>`.
nonisolated struct ModelFetchIndex: Identifiable, Equatable, Sendable {
    let id = UUID()
    var extras = NodeExtras()

    var name: String = ""
    var elements: [ModelFetchIndexElement] = []
}

/// One `<constraint value="…"/>` inside `<uniquenessConstraints>`.
nonisolated struct ModelUniquenessConstraint: Identifiable, Equatable, Sendable {
    let id = UUID()
    var extras = NodeExtras()
    var value: String = ""
}

/// A group of constraints, one `<uniquenessConstraint>`.
nonisolated struct ModelUniquenessConstraintGroup: Identifiable, Equatable, Sendable {
    let id = UUID()
    var constraints: [ModelUniquenessConstraint] = []
}

// MARK: - Entity

/// An `<entity>`.
nonisolated struct ModelEntity: Identifiable, Equatable, Sendable {
    let id = UUID()
    var extras = NodeExtras()
    var userInfo = UserInfoBlock()

    var name: String = ""
    var representedClassName: String?
    var parentEntityName: String?
    var isAbstract: Bool?
    var syncable: Bool?
    var codeGenerationType: CodeGenerationType?
    var versionHashModifier: String?
    var renamingIdentifier: String?
    var elementID: String?
    var coreSpotlightDisplayNameExpression: String?

    var attributes: [ModelAttribute] = []
    var relationships: [ModelRelationship] = []
    var fetchedProperties: [ModelFetchedProperty] = []
    var fetchIndexes: [ModelFetchIndex] = []
    var uniquenessConstraints: [ModelUniquenessConstraintGroup] = []
    var hasUniquenessConstraintsElement: Bool = false

    /// Set when the source spelled abstractness as `abstract` instead of
    /// `isAbstract`. Core Data reads only `isAbstract`, so the entity is not
    /// actually abstract despite what the file appears to say. Same failure
    /// mode as `ModelAttribute.strayDefaultValue`.
    var strayAbstract: String?

    init(name: String = "") {
        self.name = name
    }
}

// MARK: - Model-level

/// A `<configuration>`, which names a subset of entities.
///
/// Configurations exist to split a model across persistent stores, and that is
/// also how `NSPersistentCloudKitContainer` separates synced entities from
/// local-only ones, which is what ``usedWithCloudKit`` records.
nonisolated struct ModelConfiguration: Identifiable, Equatable, Sendable {
    /// What Xcode calls the implicit configuration that holds every entity.
    static let defaultName = "Default"

    let id = UUID()
    var extras = NodeExtras()
    var name: String = ""
    var memberEntityNames: [String] = []
    var usedWithCloudKit: Bool?

    var isDefault: Bool { name == Self.defaultName }

    /// True when the element carries nothing Core Data would act on.
    ///
    /// The `Default` configuration is implicit: Xcode always shows it and never
    /// writes it. It only earns an element once it has a setting worth
    /// recording, and it has to lose that element again when the setting is
    /// cleared, or the editor would leave a `<configuration name="Default"/>`
    /// behind in a file that never had one.
    var isEmptyDefault: Bool {
        isDefault
            && memberEntityNames.isEmpty
            && usedWithCloudKit != true
            && extras.attributes.isEmpty
            && extras.children.isEmpty
    }
}

/// One `<element>` in the trailing `<elements>` block: where Xcode's graph
/// editor parked an entity's box.
///
/// This editor has no canvas, but the positions are parsed and re-emitted so
/// that opening a model here and saving it does not scramble the layout for
/// someone who opens it in Xcode afterwards.
nonisolated struct DiagramElement: Identifiable, Equatable, Sendable {
    let id = UUID()
    var extras = NodeExtras()

    var name: String = ""
    var positionX: String = "0"
    var positionY: String = "0"
    var width: String = "128"
    var height: String = "44"
}

/// A whole `<model>`: one version of an `.xcdatamodeld`.
nonisolated struct DataModel: Equatable, Sendable {
    var extras = NodeExtras()

    var type: String = "com.apple.IDECoreDataModeler.DataModel"
    var documentVersion: String = "1.0"
    var lastSavedToolsVersion: String?
    var systemVersion: String?
    var minimumToolsVersion: String = "Automatic"
    var sourceLanguage: String = "Swift"
    var usedWithCloudKit: Bool?
    var userDefinedModelVersionIdentifier: String? = ""

    var entities: [ModelEntity] = []
    var configurations: [ModelConfiguration] = []
    var diagramElements: [DiagramElement] = []
    var hasElementsBlock: Bool = false

    /// File-level formatting carried through from the source so an untouched
    /// open/save is a zero-line diff even for models the MIO generator wrote.
    var xmlDeclaration: String = XMLDocumentText.xcodeDeclaration
    var endsWithNewline: Bool = false

    init() {}

    func entity(named name: String) -> ModelEntity? {
        entities.first { $0.name == name }
    }

    func index(ofEntityNamed name: String) -> Int? {
        entities.firstIndex { $0.name == name }
    }

    /// Renames an entity and every reference to it.
    ///
    /// An entity name is a foreign key spelled out all over the file:
    /// relationship destinations and inverses, parent entities, fetched
    /// property targets, configuration membership and the diagram's boxes all
    /// name it as a string. Renaming only the entity leaves every one of those
    /// pointing at something that no longer exists, and Core Data reads a
    /// missing destination as "no destination" rather than as an error, so the
    /// relationship stays in the file and quietly resolves to nothing.
    ///
    /// A name that collides with another entity is not refused here. The
    /// inspector never refused one either, and `duplicateName` reports it.
    mutating func renameEntity(named oldName: String, to newName: String) {
        guard oldName != newName,
              !newName.isEmpty,
              let renamed = index(ofEntityNamed: oldName) else { return }

        entities[renamed].rename(to: newName)

        for entity in entities.indices {
            if entities[entity].parentEntityName == oldName {
                entities[entity].parentEntityName = newName
            }

            for relationship in entities[entity].relationships.indices {
                if entities[entity].relationships[relationship].destinationEntityName == oldName {
                    entities[entity].relationships[relationship].destinationEntityName = newName
                }
                if entities[entity].relationships[relationship].inverseEntityName == oldName {
                    entities[entity].relationships[relationship].inverseEntityName = newName
                }
            }

            for fetched in entities[entity].fetchedProperties.indices
            where entities[entity].fetchedProperties[fetched].fetchTargetEntityName == oldName {
                entities[entity].fetchedProperties[fetched].fetchTargetEntityName = newName
            }
        }

        for configuration in configurations.indices {
            for member in configurations[configuration].memberEntityNames.indices
            where configurations[configuration].memberEntityNames[member] == oldName {
                configurations[configuration].memberEntityNames[member] = newName
            }
        }

        // The diagram keys its boxes by name too, so without this the entity
        // loses the position somebody arranged for it in Xcode.
        for element in diagramElements.indices where diagramElements[element].name == oldName {
            diagramElements[element].name = newName
        }
    }

    /// Entities that name `parent` as their parent entity.
    func children(of parent: ModelEntity) -> [ModelEntity] {
        entities.filter { $0.parentEntityName == parent.name }
    }

    var rootEntities: [ModelEntity] {
        entities.filter { entity in
            guard let parent = entity.parentEntityName, !parent.isEmpty else { return true }
            // An entity pointing at a parent that does not exist is still a
            // root as far as the outline is concerned, otherwise it would
            // disappear from the sidebar entirely.
            return self.entity(named: parent) == nil
        }
    }

    /// A unique entity name of the form `Entity`, `Entity 2`, `Entity 3`, …
    func uniqueEntityName(base: String = "Entity") -> String {
        var candidate = base
        var suffix = 1
        while entities.contains(where: { $0.name == candidate }) {
            suffix += 1
            candidate = "\(base) \(suffix)"
        }
        return candidate
    }
}
