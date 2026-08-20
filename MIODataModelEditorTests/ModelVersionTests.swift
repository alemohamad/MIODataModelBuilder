//
//  ModelVersionTests.swift
//  MIODataModelEditorTests
//
//  Created by MIO Research Labs on 2026.
//

import Foundation
import Testing
@testable import MIODataModelEditor

@Suite("Model versions")
struct ModelVersionTests {

    private static func bundle(_ displayNames: [String], current: String) -> ModelBundle {
        var bundle = ModelBundle()
        bundle.versions = displayNames.map {
            ModelVersion(fileName: "\($0).xcdatamodel", model: DataModel())
        }
        bundle.versions.sort(by: ModelBundle.versionOrder)
        bundle.currentVersionName = "\(current).xcdatamodel"
        return bundle
    }

    // MARK: - Naming

    @Test("A trailing number is what separates a version from its root name")
    func rootNames() {
        #expect(ModelBundle.rootName(of: "Model") == "Model")
        #expect(ModelBundle.rootName(of: "Model 2") == "Model")
        #expect(ModelBundle.rootName(of: "DualLinkDB 63") == "DualLinkDB")
        // Only a trailing number counts. These are names, not versions of "iOS"
        // and "Model".
        #expect(ModelBundle.rootName(of: "Model v2") == "Model v2")
        #expect(ModelBundle.rootName(of: "iOS 18 Model") == "iOS 18 Model")
        #expect(ModelBundle.rootName(of: "Model ") == "Model ")
    }

    @Test("The suggested name counts on from the version it is based on")
    func suggestsFromTheBase() {
        let single = Self.bundle(["Model"], current: "Model")
        #expect(single.suggestedVersionName(basedOn: "Model.xcdatamodel") == "Model 2")

        let several = Self.bundle(["Model", "Model 2", "Model 3"], current: "Model 3")
        #expect(several.suggestedVersionName(basedOn: "Model 3.xcdatamodel") == "Model 4")
        // Based on the oldest, so 2 is what it would offer, but 2 and 3 are
        // taken and a name already in use is no use as a suggestion.
        #expect(several.suggestedVersionName(basedOn: "Model.xcdatamodel") == "Model 4")
    }

    @Test("A gap in the numbering is left alone, not filled")
    func doesNotFillGaps() {
        let gapped = Self.bundle(["Model", "Model 4"], current: "Model 4")
        #expect(gapped.suggestedVersionName(basedOn: "Model 4.xcdatamodel") == "Model 5")
        #expect(gapped.suggestedVersionName(basedOn: "Model.xcdatamodel") == "Model 2")
    }

    @Test("Dual Link's real numbering continues where it left off")
    func continuesRealNumbering() {
        let real = Self.bundle(["DualLinkDB", "DualLinkDB 59", "DualLinkDB 60", "DualLinkDB 61",
                                "DualLinkDB 62", "DualLinkDB 63"],
                               current: "DualLinkDB 63")
        // The sequence in the real package only makes sense this way: 2 is free
        // and was never offered, because each version was named after its base.
        #expect(real.suggestedVersionName(basedOn: "DualLinkDB 63.xcdatamodel") == "DualLinkDB 64")
    }

    @Test("A root and its number come apart the same way everywhere")
    func splitsNames() {
        #expect(ModelBundle.split(displayName: "Model 63").number == 63)
        #expect(ModelBundle.split(displayName: "Model").number == nil)
        #expect(ModelBundle.split(displayName: "Model v2").number == nil)
    }

    // MARK: - What may be added

    @Test("A name already in use, or one that could escape the package, is refused")
    func rejectsUnusableNames() {
        let bundle = Self.bundle(["Model", "Model 2"], current: "Model 2")

        #expect(bundle.canAddVersion(named: "Model 3"))
        #expect(!bundle.canAddVersion(named: "Model 2"))
        #expect(!bundle.canAddVersion(named: ""))
        #expect(!bundle.canAddVersion(named: "   "))
        #expect(!bundle.canAddVersion(named: "../Model 3"))
        #expect(!bundle.canAddVersion(named: "Model:3"))
        #expect(!bundle.canAddVersion(named: ".hidden"))
    }

    @Test("A bare .xcdatamodel cannot be versioned")
    func bareModelRefusesVersions() {
        var bare = Self.bundle(["Bare"], current: "Bare")
        bare.isVersionedPackage = false

        #expect(!bare.canAddVersion(named: "Bare 2"))
        #expect(bare.addVersion(named: "Bare 2", copying: "Bare.xcdatamodel") == nil)
        #expect(bare.versions.count == 1)
    }

    // MARK: - Adding

    @Test("The new version is a copy of the one it is based on")
    func copiesTheBaseModel() throws {
        var bundle = Self.bundle(["Model", "Model 2"], current: "Model 2")
        var entity = ModelEntity(name: "Employee")
        entity.representedClassName = "Employee"
        bundle.versions[1].model.entities = [entity]
        bundle.versions[1].extraFiles = ["layout": Data("positions".utf8)]

        let newName = bundle.addVersion(named: "Model 3", copying: "Model 2.xcdatamodel")
        let added = try #require(newName)
        #expect(added == "Model 3.xcdatamodel")

        let new = try #require(bundle.versions.first { $0.fileName == added })
        #expect(new.model.entity(named: "Employee") != nil)
        #expect(new.extraFiles["layout"] != nil)

        // A copy, not a share: editing one must not reach the other.
        let index = try #require(bundle.index(ofVersionNamed: added))
        bundle.versions[index].model.entities.removeAll()
        #expect(bundle.versions[1].model.entities.count == 1)
    }

    @Test("Adding a version leaves the current one alone")
    func doesNotStealTheCurrentMarker() {
        var bundle = Self.bundle(["Model", "Model 2"], current: "Model 2")
        bundle.addVersion(named: "Model 3", copying: "Model 2.xcdatamodel")

        #expect(bundle.currentVersionName == "Model 2.xcdatamodel")
        #expect(bundle.versions.count == 3)
    }

    @Test("The name is trimmed, and a version keeps its own identity")
    func trimsAndReidentifies() throws {
        var bundle = Self.bundle(["Model"], current: "Model")
        let newName = bundle.addVersion(named: "  Model 2  ", copying: "Model.xcdatamodel")
        let added = try #require(newName)

        #expect(added == "Model 2.xcdatamodel")
        // Two rows sharing an id would collapse in the picker's ForEach.
        #expect(Set(bundle.versions.map(\.id)).count == bundle.versions.count)
    }

    @Test("The list stays in the order a reload would produce")
    func staysSorted() {
        var bundle = Self.bundle(["Model", "Model 10"], current: "Model")
        bundle.addVersion(named: "Model 2", copying: "Model.xcdatamodel")

        #expect(bundle.versions.map(\.displayName) == ["Model", "Model 2", "Model 10"])
    }

    @Test("An added version survives a save and reload with the marker unmoved")
    func addedVersionRoundTrips() throws {
        var bundle = Self.bundle(["Model", "Model 2"], current: "Model 2")
        bundle.addVersion(named: "Model 3", copying: "Model 2.xcdatamodel")

        let reloaded = try ModelBundle(wrapper: bundle.fileWrapper())
        #expect(reloaded.versions.map(\.displayName) == ["Model", "Model 2", "Model 3"])
        #expect(reloaded.currentVersionName == "Model 2.xcdatamodel")
    }

    // MARK: - Renaming

    @Test("Renaming keeps the contents and re-sorts the list")
    func renamesAndResorts() throws {
        var bundle = Self.bundle(["Model", "Model 10"], current: "Model")
        var entity = ModelEntity(name: "Employee")
        entity.representedClassName = "Employee"
        bundle.versions[1].model.entities = [entity]

        let renamed = bundle.renameVersion("Model 10.xcdatamodel", to: "Model 2")
        #expect(renamed == "Model 2.xcdatamodel")
        #expect(bundle.versions.map(\.displayName) == ["Model", "Model 2"])

        let moved = try #require(bundle.versions.first { $0.displayName == "Model 2" })
        #expect(moved.model.entity(named: "Employee") != nil)
    }

    @Test("Renaming the current version takes the marker with it")
    func markerFollowsTheRename() throws {
        var bundle = Self.bundle(["Model", "Model 2"], current: "Model 2")
        bundle.renameVersion("Model 2.xcdatamodel", to: "Model Final")

        #expect(bundle.currentVersionName == "Model Final.xcdatamodel")

        // The marker naming a directory that is not there is the failure this
        // guards: the next load would quietly fall back to the last version.
        let reloaded = try ModelBundle(wrapper: bundle.fileWrapper())
        #expect(reloaded.currentVersionName == "Model Final.xcdatamodel")
        #expect(reloaded.versions.map(\.displayName) == ["Model", "Model Final"])
    }

    @Test("Renaming another version leaves the marker alone")
    func markerStaysWhenRenamingAnother() {
        var bundle = Self.bundle(["Model", "Model 2"], current: "Model 2")
        bundle.renameVersion("Model.xcdatamodel", to: "Model Original")

        #expect(bundle.currentVersionName == "Model 2.xcdatamodel")
    }

    @Test("A renamed version is the same version, so its row keeps its identity")
    func renameKeepsIdentity() throws {
        var bundle = Self.bundle(["Model", "Model 2"], current: "Model")
        let before = try #require(bundle.versions.first { $0.displayName == "Model 2" }).id

        bundle.renameVersion("Model 2.xcdatamodel", to: "Model 3")
        let after = try #require(bundle.versions.first { $0.displayName == "Model 3" }).id

        #expect(before == after)
    }

    @Test("The old directory does not survive the rename")
    func oldDirectoryIsGone() throws {
        var bundle = Self.bundle(["Model", "Model 2"], current: "Model")
        bundle.renameVersion("Model 2.xcdatamodel", to: "Model 3")

        let children = try #require(bundle.fileWrapper().fileWrappers)
        #expect(children["Model 3.xcdatamodel"] != nil)
        #expect(children["Model 2.xcdatamodel"] == nil)
    }

    @Test("A name in use, its own name, or one that could escape the package is refused")
    func rejectsUnusableRenames() {
        var bundle = Self.bundle(["Model", "Model 2"], current: "Model 2")
        let subject = "Model 2.xcdatamodel"

        #expect(bundle.canRenameVersion(subject, to: "Model 3"))
        // Its own name is not an error, but there is nothing to do, so the
        // Rename button stays inert until something actually changes.
        #expect(!bundle.canRenameVersion(subject, to: "Model 2"))
        #expect(!bundle.canRenameVersion(subject, to: "Model"))
        #expect(!bundle.canRenameVersion(subject, to: "  "))
        #expect(!bundle.canRenameVersion(subject, to: "../Model 3"))
        #expect(!bundle.canRenameVersion(subject, to: ".hidden"))
        #expect(!bundle.canRenameVersion("Model 9.xcdatamodel", to: "Model 3"))

        #expect(bundle.renameVersion(subject, to: "Model") == nil)
        #expect(bundle.versions.map(\.displayName) == ["Model", "Model 2"])
    }

    @Test("A bare .xcdatamodel cannot be renamed from inside the editor")
    func bareModelRefusesRename() {
        var bare = Self.bundle(["Bare"], current: "Bare")
        bare.isVersionedPackage = false

        #expect(!bare.canRenameVersion("Bare.xcdatamodel", to: "Renamed"))
        #expect(bare.renameVersion("Bare.xcdatamodel", to: "Renamed") == nil)
    }

    @Test("A renamed version is a new base to count from")
    func renameFeedsTheNumbering() {
        var bundle = Self.bundle(["Model"], current: "Model")
        bundle.renameVersion("Model.xcdatamodel", to: "DualLinkDB 58")

        #expect(bundle.suggestedVersionName(basedOn: "DualLinkDB 58.xcdatamodel") == "DualLinkDB 59")
    }

    // MARK: - Deleting

    @Test("Deleting a version takes its directory out of the package")
    func deletesVersion() throws {
        var bundle = Self.bundle(["Model", "Model 2", "Model 3"], current: "Model 3")
        // Hoisted out of #expect: the macro captures its expression immutably,
        // so a mutating call inside it does not compile.
        let deleted = bundle.deleteVersion("Model 2.xcdatamodel")
        #expect(deleted)

        #expect(bundle.versions.map(\.displayName) == ["Model", "Model 3"])

        let children = try #require(bundle.fileWrapper().fileWrappers)
        #expect(children["Model 2.xcdatamodel"] == nil)
        #expect(children["Model.xcdatamodel"] != nil)

        // And it stays gone, with the marker untouched.
        let reloaded = try ModelBundle(wrapper: bundle.fileWrapper())
        #expect(reloaded.versions.map(\.displayName) == ["Model", "Model 3"])
        #expect(reloaded.currentVersionName == "Model 3.xcdatamodel")
    }

    @Test("The current version cannot be deleted, so the marker never moves by itself")
    func refusesToDeleteTheCurrentVersion() {
        var bundle = Self.bundle(["Model", "Model 2"], current: "Model 2")

        #expect(!bundle.canDeleteVersion("Model 2.xcdatamodel"))
        let deleted = bundle.deleteVersion("Model 2.xcdatamodel")
        #expect(!deleted)
        #expect(bundle.versions.count == 2)

        // Making the other one current is what unlocks it, deliberately.
        bundle.currentVersionName = "Model.xcdatamodel"
        #expect(bundle.canDeleteVersion("Model 2.xcdatamodel"))
    }

    @Test("The last version cannot be deleted, since the package would not load")
    func refusesToDeleteTheLastVersion() throws {
        var bundle = Self.bundle(["Model", "Model 2"], current: "Model")
        let deleted = bundle.deleteVersion("Model 2.xcdatamodel")
        #expect(deleted)

        // One left, and it is the current one, so both guards now apply.
        #expect(!bundle.canDeleteVersion("Model.xcdatamodel"))
        let deletedLast = bundle.deleteVersion("Model.xcdatamodel")
        #expect(!deletedLast)
        #expect(bundle.versions.count == 1)

        // A package with no version in it is what this is protecting against.
        #expect(throws: ModelBundleError.self) {
            var emptied = bundle
            emptied.versions = []
            _ = try ModelBundle(wrapper: emptied.fileWrapper())
        }
    }

    @Test("A version that is not there cannot be deleted")
    func refusesUnknownVersion() {
        var bundle = Self.bundle(["Model", "Model 2"], current: "Model")
        #expect(!bundle.canDeleteVersion("Model 9.xcdatamodel"))
        let deleted = bundle.deleteVersion("Model 9.xcdatamodel")
        #expect(!deleted)
    }

    @Test("A bare .xcdatamodel has no version to delete")
    func bareModelRefusesDelete() {
        var bare = Self.bundle(["Bare"], current: "Bare")
        bare.isVersionedPackage = false

        #expect(!bare.canDeleteVersion("Bare.xcdatamodel"))
        let deleted = bare.deleteVersion("Bare.xcdatamodel")
        #expect(!deleted)
    }

    @Test("Deleting frees the name again")
    func deleteFreesTheName() {
        var bundle = Self.bundle(["Model", "Model 2"], current: "Model")
        #expect(!bundle.canAddVersion(named: "Model 2"))

        bundle.deleteVersion("Model 2.xcdatamodel")
        #expect(bundle.canAddVersion(named: "Model 2"))
    }

    // MARK: - Viewing versus current

    @Test("Looking up a version by name is what the window views by")
    func indexByName() {
        let bundle = Self.bundle(["Model", "Model 2"], current: "Model 2")

        #expect(bundle.index(ofVersionNamed: "Model.xcdatamodel") == 0)
        #expect(bundle.index(ofVersionNamed: "Model 2.xcdatamodel") == 1)
        #expect(bundle.index(ofVersionNamed: "Model 9.xcdatamodel") == nil)
    }

    @Test("Setting the current version is the only thing that moves the marker")
    func settingCurrentVersionIsExplicit() throws {
        // The bug this replaced: the version picker wrote straight into
        // `currentVersionName`, so viewing an old version and saving silently
        // repointed every consumer of the package at it.
        var document = MIODataModelEditorDocument(bundle: Self.bundle(["Model", "Model 2"], current: "Model 2"))

        // Viewing version 1 is a read, and a read must not write.
        let viewed = "Model.xcdatamodel"
        #expect(document.bundle.index(ofVersionNamed: viewed) == 0)
        #expect(document.bundle.currentVersionName == "Model 2.xcdatamodel")

        var saved = try ModelBundle(wrapper: document.bundle.fileWrapper())
        #expect(saved.currentVersionName == "Model 2.xcdatamodel")

        // Only the explicit action moves it.
        document.bundle.currentVersionName = viewed
        saved = try ModelBundle(wrapper: document.bundle.fileWrapper())
        #expect(saved.currentVersionName == viewed)
    }
}
