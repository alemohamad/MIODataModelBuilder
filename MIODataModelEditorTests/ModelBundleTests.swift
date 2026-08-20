//
//  ModelBundleTests.swift
//  MIODataModelEditorTests
//
//  Created by MIO Research Labs on 2026.
//

import Foundation
import Testing
import UniformTypeIdentifiers
@testable import MIODataModelEditor

@Suite("Model bundle")
struct ModelBundleTests {

    private static func versionWrapper(_ contents: String) -> FileWrapper {
        FileWrapper(directoryWithFileWrappers: [
            "contents": FileWrapper(regularFileWithContents: Data(contents.utf8))
        ])
    }

    private static func currentVersionWrapper(_ name: String) -> FileWrapper {
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>_XCCurrentVersionName</key>
            <string>\(name)</string>
        </dict>
        </plist>
        """
        return FileWrapper(regularFileWithContents: Data(plist.utf8))
    }

    /// A two-version package with a stray file at the top level.
    private static func packageWrapper() -> FileWrapper {
        let wrapper = FileWrapper(directoryWithFileWrappers: [
            "Model.xcdatamodel": versionWrapper(ModelFixtures.canonical),
            "Model 2.xcdatamodel": versionWrapper(ModelFixtures.generatorFlavoured),
            ".xccurrentversion": currentVersionWrapper("Model 2.xcdatamodel"),
            "README.txt": FileWrapper(regularFileWithContents: Data("keep me".utf8))
        ])
        wrapper.filename = "Sample.xcdatamodeld"
        return wrapper
    }

    @Test("A versioned package loads every version and the current marker")
    func loadsVersionedPackage() throws {
        let bundle = try ModelBundle(wrapper: Self.packageWrapper())

        #expect(bundle.isVersionedPackage)
        #expect(bundle.versions.count == 2)
        #expect(bundle.currentVersionName == "Model 2.xcdatamodel")
        #expect(bundle.currentModel?.entity(named: "Task") != nil)
        #expect(bundle.versions.map(\.displayName) == ["Model", "Model 2"])
    }

    @Test("Saving reproduces every version's contents byte for byte")
    func savingIsByteExact() throws {
        let bundle = try ModelBundle(wrapper: Self.packageWrapper())
        let saved = bundle.fileWrapper()
        let children = try #require(saved.fileWrappers)

        func contents(of version: String) throws -> String {
            let directory = try #require(children[version]?.fileWrappers)
            let data = try #require(directory["contents"]?.regularFileContents)
            return String(decoding: data, as: UTF8.self)
        }

        #expect(try contents(of: "Model.xcdatamodel") == ModelFixtures.canonical)
        #expect(try contents(of: "Model 2.xcdatamodel") == ModelFixtures.generatorFlavoured)
    }

    @Test("Unrelated files inside the package are not pruned on save")
    func extraFilesSurvive() throws {
        let bundle = try ModelBundle(wrapper: Self.packageWrapper())
        let children = try #require(bundle.fileWrapper().fileWrappers)

        let readme = try #require(children["README.txt"]?.regularFileContents)
        #expect(String(decoding: readme, as: UTF8.self) == "keep me")
    }

    @Test("The current version marker round-trips")
    func currentVersionMarkerRoundTrips() throws {
        let bundle = try ModelBundle(wrapper: Self.packageWrapper())
        let children = try #require(bundle.fileWrapper().fileWrappers)
        let data = try #require(children[".xccurrentversion"]?.regularFileContents)
        let plist = try #require(try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any])

        #expect(plist["_XCCurrentVersionName"] as? String == "Model 2.xcdatamodel")

        // And it survives a second load, which is what actually matters.
        let reloaded = try ModelBundle(wrapper: bundle.fileWrapper())
        #expect(reloaded.currentVersionName == "Model 2.xcdatamodel")
    }

    @Test("A bare .xcdatamodel loads as a single unversioned model")
    func loadsBareModel() throws {
        let wrapper = Self.versionWrapper(ModelFixtures.canonical)
        wrapper.filename = "Bare.xcdatamodel"

        let bundle = try ModelBundle(wrapper: wrapper)
        #expect(!bundle.isVersionedPackage)
        #expect(bundle.versions.count == 1)
        #expect(bundle.currentModel?.entities.count == 2)

        // Saving must not invent a .xccurrentversion for it.
        let children = try #require(bundle.fileWrapper().fileWrappers)
        #expect(children[".xccurrentversion"] == nil)
        #expect(children["contents"] != nil)
    }

    @Test("A directory with no versions is rejected rather than silently empty")
    func rejectsEmptyPackage() throws {
        let wrapper = FileWrapper(directoryWithFileWrappers: [
            "notes.txt": FileWrapper(regularFileWithContents: Data())
        ])
        #expect(throws: ModelBundleError.self) {
            try ModelBundle(wrapper: wrapper)
        }
    }

    @Test("A new document starts with one empty version")
    func newDocumentIsUsable() throws {
        let bundle = ModelBundle.newDocument()
        #expect(bundle.versions.count == 1)
        #expect(bundle.currentModel?.entities.isEmpty == true)

        // It has to be loadable again, or File > New then Save then Open breaks.
        let reloaded = try ModelBundle(wrapper: bundle.fileWrapper())
        #expect(reloaded.versions.count == 1)
    }

    @Test("The document carries the bundle through a save and reload")
    func documentRoundTrips() throws {
        // `FileDocumentWriteConfiguration` has no public initialiser, so the
        // protocol method itself cannot be called from a test. Exercising the
        // wrapper it delegates to covers the same path.
        let document = try MIODataModelEditorDocument(bundle: ModelBundle(wrapper: Self.packageWrapper()))
        let reloaded = try ModelBundle(wrapper: document.bundle.fileWrapper())

        #expect(reloaded.versions.count == 2)
        #expect(reloaded.currentVersionName == "Model 2.xcdatamodel")
        #expect(reloaded.currentModel?.entity(named: "Task") != nil)
    }

    @Test("The document declares both Core Data model types")
    func documentDeclaresContentTypes() {
        let types = MIODataModelEditorDocument.readableContentTypes.map(\.identifier)
        #expect(types.contains("com.apple.xcode.model.data-version"))
        #expect(types.contains("com.apple.xcode.model.data"))
    }

    @Test("A new document is empty but valid")
    func newDocumentIsClean() {
        let document = MIODataModelEditorDocument()
        #expect(document.bundle.versions.count == 1)
        #expect(ModelValidator.validate(document.bundle.currentModel ?? DataModel()).isEmpty)
    }
}
