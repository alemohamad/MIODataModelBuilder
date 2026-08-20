//
//  MIODataModelEditorDocument.swift
//  MIODataModelEditor
//
//  Created by Ale Mohamad on 19/08/2026.
//

import SwiftUI
import UniformTypeIdentifiers

nonisolated extension UTType {
    /// The versioned package, `.xcdatamodeld`.
    static let xcDataModelVersioned = UTType(importedAs: "com.apple.xcode.model.data-version")
    /// A single unversioned model, `.xcdatamodel`.
    static let xcDataModel = UTType(importedAs: "com.apple.xcode.model.data")
}

/// The document.
///
/// A value type conforming to `FileDocument`, which is what keeps this file
/// free of Combine: the reference-based `ReferenceFileDocument` refines
/// `ObservableObject`, and adopting it would drag `ObservableObject` and a
/// `@preconcurrency` conformance in behind it. Value semantics also mean SwiftUI
/// registers undo automatically for every change made through the document
/// binding, so there is no undo plumbing to write or to forget.
nonisolated struct MIODataModelEditorDocument: FileDocument {
    var bundle: ModelBundle

    init() {
        bundle = .newDocument()
    }

    init(bundle: ModelBundle) {
        self.bundle = bundle
    }

    static let readableContentTypes: [UTType] = [.xcDataModelVersioned, .xcDataModel]

    init(configuration: ReadConfiguration) throws {
        bundle = try ModelBundle(wrapper: configuration.file)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        bundle.fileWrapper()
    }
}
