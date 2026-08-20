//
//  ModelBundle.swift
//  MIODataModelEditor
//
//  Created by MIO Research Labs on 2026.
//

import Foundation

nonisolated enum ModelBundleError: Error, LocalizedError {
    case notADirectory
    case noVersionsFound

    var errorDescription: String? {
        switch self {
        case .notADirectory:   "This does not look like an .xcdatamodeld package."
        case .noVersionsFound: "The package contains no .xcdatamodel version."
        }
    }
}

/// One `.xcdatamodel` inside the package: a named version of the model.
nonisolated struct ModelVersion: Identifiable, Equatable, Sendable {
    let id = UUID()

    /// The directory name including the `.xcdatamodel` extension, because that
    /// is the exact string `.xccurrentversion` stores.
    var fileName: String
    var model: DataModel
    /// Files inside the version directory other than `contents`.
    var extraFiles: [String: Data] = [:]

    /// The name without the extension, for display.
    var displayName: String {
        fileName.hasSuffix(".xcdatamodel") ? String(fileName.dropLast(".xcdatamodel".count)) : fileName
    }
}

/// A whole `.xcdatamodeld` package.
///
/// The package is a directory: one `.xcdatamodel` subdirectory per version,
/// each holding a `contents` file, plus an `.xccurrentversion` plist naming the
/// active one. A bare `.xcdatamodel` with no wrapper is also accepted, since
/// that is what an unversioned model looks like.
nonisolated struct ModelBundle: Equatable, Sendable {
    static let currentVersionFileName = ".xccurrentversion"
    static let currentVersionKey = "_XCCurrentVersionName"
    static let contentsFileName = "contents"

    var versions: [ModelVersion] = []
    var currentVersionName: String = ""
    /// Files at the top level of the package other than the versions and
    /// `.xccurrentversion`, kept so saving does not prune them.
    var extraFiles: [String: Data] = [:]
    /// False for a bare `.xcdatamodel`, which has no `.xccurrentversion`.
    var isVersionedPackage: Bool = true

    init() {}

    /// An empty package holding one blank version, for File > New.
    static func newDocument() -> ModelBundle {
        var bundle = ModelBundle()
        bundle.versions = [ModelVersion(fileName: "Model.xcdatamodel", model: DataModel())]
        bundle.currentVersionName = "Model.xcdatamodel"
        return bundle
    }

    var currentVersionIndex: Int? {
        versions.firstIndex { $0.fileName == currentVersionName } ?? (versions.isEmpty ? nil : 0)
    }

    var currentModel: DataModel? {
        currentVersionIndex.map { versions[$0].model }
    }

    func index(ofVersionNamed fileName: String) -> Int? {
        versions.firstIndex { $0.fileName == fileName }
    }

    // MARK: - Version order

    /// Sort on the display name, not the file name. The extension makes the
    /// file names sort wrongly: in "Model 2.xcdatamodel" the space precedes the
    /// period of "Model.xcdatamodel", so version 2 would come first.
    ///
    /// Adding a version re-sorts with this too, so the picker lists the
    /// versions in the same order before and after a save.
    static func versionOrder(_ lhs: ModelVersion, _ rhs: ModelVersion) -> Bool {
        lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
    }

    // MARK: - Adding a version

    /// A display name split into its root and its version number: "Model 63"
    /// gives ("Model", 63), and an unnumbered "Model" gives ("Model", nil).
    ///
    /// Only a trailing run of digits counts, so "Model v2" and "iOS 18 Model"
    /// are names in their own right rather than versions of something.
    static func split(displayName: String) -> (root: String, number: Int?) {
        guard let space = displayName.lastIndex(of: " ") else { return (displayName, nil) }
        let tail = displayName[displayName.index(after: space)...]
        guard !tail.isEmpty, tail.allSatisfy(\.isNumber), let number = Int(tail) else {
            return (displayName, nil)
        }
        return (String(displayName[..<space]), number)
    }

    static func rootName(of displayName: String) -> String {
        split(displayName: displayName).root
    }

    /// The name Add Model Version offers: the base's number plus one, which is
    /// how Xcode numbers them.
    ///
    /// Counting from the base rather than filling the lowest free number is
    /// what produces the sequences real packages have. Dual Link's model runs
    /// "DualLinkDB" then 59 through 63 with nothing in between, which only
    /// happens if each version was named after the one it was based on.
    /// An unnumbered base counts as 1, so a package holding only "DualLinkDB"
    /// suggests "DualLinkDB 2".
    func suggestedVersionName(basedOn fileName: String) -> String {
        let base = index(ofVersionNamed: fileName).map { versions[$0].displayName }
            ?? versions.first?.displayName
            ?? "Model"
        let (root, number) = Self.split(displayName: base)
        let taken = Set(versions.map(\.displayName))

        var next = (number ?? 1) + 1
        while taken.contains("\(root) \(next)") { next += 1 }
        return "\(root) \(next)"
    }

    /// A name that can become a directory inside the package: non-empty, and
    /// unable to escape it or to hide.
    private func isUsableVersionName(_ name: String) -> Bool {
        guard isVersionedPackage, !name.isEmpty else { return false }
        return !name.contains("/") && !name.contains(":") && !name.hasPrefix(".")
    }

    /// Whether `displayName` can be added: Xcode's own rule, a usable name that
    /// is not already a version.
    func canAddVersion(named displayName: String) -> Bool {
        let name = displayName.trimmingCharacters(in: .whitespaces)
        guard isUsableVersionName(name) else { return false }
        return !versions.contains { $0.displayName == name }
    }

    /// Whether a version can take `displayName`.
    ///
    /// Its own current name is refused, so the Rename button stays inert until
    /// something has actually changed.
    func canRenameVersion(_ fileName: String, to displayName: String) -> Bool {
        let name = displayName.trimmingCharacters(in: .whitespaces)
        guard isUsableVersionName(name), let index = index(ofVersionNamed: fileName) else { return false }
        guard versions[index].displayName != name else { return false }
        return !versions.contains { $0.displayName == name }
    }

    /// Appends a copy of an existing version under a new name and returns its
    /// file name, or `nil` if the name is not addable.
    ///
    /// The current-version marker is deliberately left alone: Xcode's Add Model
    /// Version does not switch the model every consumer compiles against, and
    /// neither does this. Use `currentVersionName` for that, on purpose.
    @discardableResult
    mutating func addVersion(named displayName: String, copying fileName: String) -> String? {
        guard canAddVersion(named: displayName), let source = index(ofVersionNamed: fileName) else { return nil }

        // Built rather than copied, because `ModelVersion.id` is a stored
        // constant: mutating a copy of the struct would carry the source's id
        // over and leave the picker's ForEach with two rows claiming the same
        // identity.
        let name = displayName.trimmingCharacters(in: .whitespaces)
        let copy = ModelVersion(fileName: "\(name).xcdatamodel",
                                model: versions[source].model,
                                extraFiles: versions[source].extraFiles)
        versions.append(copy)
        versions.sort(by: Self.versionOrder)
        return copy.fileName
    }

    // MARK: - Renaming a version

    /// Renames a version and returns its new file name, or `nil` if the name is
    /// not usable.
    ///
    /// The version keeps its identity, unlike the copy `addVersion` makes: this
    /// is the same version under a new name, and the picker row should stay the
    /// same row.
    @discardableResult
    mutating func renameVersion(_ fileName: String, to displayName: String) -> String? {
        guard canRenameVersion(fileName, to: displayName),
              let index = index(ofVersionNamed: fileName)
        else { return nil }

        let name = displayName.trimmingCharacters(in: .whitespaces)
        let renamed = "\(name).xcdatamodel"
        let wasCurrent = currentVersionName == fileName

        versions[index].fileName = renamed
        // The marker names the directory. Renaming the current version without
        // moving the marker with it would leave `.xccurrentversion` pointing at
        // a version that no longer exists, and the next load would silently
        // fall back to the last one in the package.
        if wasCurrent { currentVersionName = renamed }

        versions.sort(by: Self.versionOrder)
        return renamed
    }

    // MARK: - Deleting a version

    /// Whether a version can be removed from the package.
    ///
    /// Two things are refused outright. The last version, because a package
    /// with no `.xcdatamodel` in it will not load at all. And the current one,
    /// because deleting it would have to repoint `.xccurrentversion` at some
    /// other version, and what every consumer of this model compiles against
    /// does not get to change as a side effect of a delete. Set another version
    /// current first, deliberately, and then this one is deletable.
    func canDeleteVersion(_ fileName: String) -> Bool {
        guard isVersionedPackage, versions.count > 1 else { return false }
        guard index(ofVersionNamed: fileName) != nil else { return false }
        return fileName != currentVersionName
    }

    @discardableResult
    mutating func deleteVersion(_ fileName: String) -> Bool {
        guard canDeleteVersion(fileName) else { return false }
        versions.removeAll { $0.fileName == fileName }
        return true
    }

    // MARK: - Loading

    init(wrapper: FileWrapper) throws {
        self.init()
        guard wrapper.isDirectory, let children = wrapper.fileWrappers else {
            throw ModelBundleError.notADirectory
        }

        // A bare .xcdatamodel: the contents file sits at the top level.
        if children[Self.contentsFileName] != nil {
            isVersionedPackage = false
            let version = try Self.readVersion(named: wrapper.filename ?? "Model.xcdatamodel", from: wrapper)
            versions = [version]
            currentVersionName = version.fileName
            return
        }

        for (name, child) in children {
            if name == Self.currentVersionFileName {
                currentVersionName = Self.readCurrentVersionName(child) ?? ""
            } else if name.hasSuffix(".xcdatamodel"), child.isDirectory {
                versions.append(try Self.readVersion(named: name, from: child))
            } else if let data = child.regularFileContents {
                extraFiles[name] = data
            }
        }

        guard !versions.isEmpty else { throw ModelBundleError.noVersionsFound }

        versions.sort(by: Self.versionOrder)
        if currentVersionName.isEmpty || !versions.contains(where: { $0.fileName == currentVersionName }) {
            currentVersionName = versions[versions.count - 1].fileName
        }
    }

    private static func readVersion(named name: String, from wrapper: FileWrapper) throws -> ModelVersion {
        var extraFiles: [String: Data] = [:]
        var model = DataModel()

        for (childName, child) in wrapper.fileWrappers ?? [:] {
            guard let data = child.regularFileContents else { continue }
            if childName == contentsFileName {
                model = ModelDecoder.decode(try XMLReader.read(data: data))
            } else {
                extraFiles[childName] = data
            }
        }

        return ModelVersion(fileName: name, model: model, extraFiles: extraFiles)
    }

    private static func readCurrentVersionName(_ wrapper: FileWrapper) -> String? {
        guard let data = wrapper.regularFileContents,
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
        else { return nil }
        return plist[currentVersionKey] as? String
    }

    // MARK: - Saving

    func fileWrapper() -> FileWrapper {
        if !isVersionedPackage, let only = versions.first {
            return Self.versionWrapper(only)
        }

        var children: [String: FileWrapper] = [:]
        for version in versions {
            children[version.fileName] = Self.versionWrapper(version)
        }
        for (name, data) in extraFiles {
            children[name] = FileWrapper(regularFileWithContents: data)
        }
        children[Self.currentVersionFileName] =
            FileWrapper(regularFileWithContents: Self.currentVersionPlist(currentVersionName))

        return FileWrapper(directoryWithFileWrappers: children)
    }

    private static func versionWrapper(_ version: ModelVersion) -> FileWrapper {
        var children: [String: FileWrapper] = [
            contentsFileName: FileWrapper(regularFileWithContents: XMLWriter.data(ModelEncoder.encode(version.model)))
        ]
        for (name, data) in version.extraFiles {
            children[name] = FileWrapper(regularFileWithContents: data)
        }
        return FileWrapper(directoryWithFileWrappers: children)
    }

    /// Written by hand rather than through `PropertyListSerialization` so the
    /// output matches Xcode's formatting exactly, down to the four-space indent
    /// and the DOCTYPE line.
    private static func currentVersionPlist(_ name: String) -> Data {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>\(currentVersionKey)</key>
            <string>\(name)</string>
        </dict>
        </plist>

        """
        return Data(xml.utf8)
    }
}
