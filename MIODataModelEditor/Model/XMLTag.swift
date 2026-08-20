//
//  XMLTag.swift
//  MIODataModelEditor
//
//  Created by MIO Research Labs on 2026.
//

import Foundation

/// One XML attribute, kept as an ordered pair rather than a dictionary entry.
///
/// Order matters: reproducing Xcode's `contents` byte for byte depends on
/// emitting attributes in the order Xcode emits them, and a dictionary would
/// throw that away on the way in.
nonisolated struct XMLAttribute: Equatable, Sendable {
    var name: String
    var value: String

    init(_ name: String, _ value: String) {
        self.name = name
        self.value = value
    }
}

/// A minimal, order-preserving XML element tree.
///
/// This is the transport format between the file on disk and the typed model.
/// Anything the typed model does not understand survives a load/save cycle by
/// staying in this form, which is what keeps the editor from quietly deleting
/// constructs a future Xcode adds.
nonisolated struct XMLTag: Equatable, Sendable {
    var name: String
    var attributes: [XMLAttribute] = []
    var children: [XMLTag] = []

    /// Non-nil when this node is an XML comment rather than an element, in
    /// which case `name` is `#comment` and the other fields are unused.
    ///
    /// Comments are nodes rather than a separate type so the decoder's
    /// `switch child.name` falls through to its `default:` branch and files
    /// them into the node's extra children automatically. Hand-edited models
    /// carry commented-out relationships, and dropping them on save would be
    /// destroying someone's notes.
    var comment: String?

    init(_ name: String, attributes: [XMLAttribute] = [], children: [XMLTag] = []) {
        self.name = name
        self.attributes = attributes
        self.children = children
    }

    static func comment(_ text: String) -> XMLTag {
        var tag = XMLTag("#comment")
        tag.comment = text
        return tag
    }

    var isComment: Bool { comment != nil }

    subscript(attribute: String) -> String? {
        attributes.first { $0.name == attribute }?.value
    }

    func children(named name: String) -> [XMLTag] {
        children.filter { $0.name == name }
    }
}

/// A whole `contents` file: its root element plus the two file-level details
/// that are invisible to a tree comparison but very visible in a diff.
///
/// Xcode writes `standalone="yes"` in its declaration and no trailing newline;
/// the MIO `ModelBuilder` generator writes neither. Both are preserved as found
/// rather than normalised, so opening a generated model and saving it does not
/// produce a two-line diff nobody asked for.
nonisolated struct XMLDocumentText: Equatable, Sendable {
    static let xcodeDeclaration = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>"

    var declaration: String = xcodeDeclaration
    var root: XMLTag
    var trailingNewline: Bool = false

    init(root: XMLTag, declaration: String = xcodeDeclaration, trailingNewline: Bool = false) {
        self.root = root
        self.declaration = declaration
        self.trailingNewline = trailingNewline
    }
}

/// An unrecognised child element together with where it sat among its siblings.
///
/// Position matters: a hand-edited model can have commented-out relationships
/// interleaved with live ones. Re-emitting them in a clump at the end would
/// preserve the text but scramble the notes, and turn an untouched save into a
/// diff.
nonisolated struct PositionedTag: Equatable, Sendable {
    var index: Int
    var tag: XMLTag
}

/// The passthrough storage every model value carries.
///
/// This is the whole fidelity story. Any XML attribute or child element the
/// editor does not model is parked here and written back untouched, so saving a
/// model in this app cannot silently delete whatever a newer Xcode put in it.
nonisolated struct NodeExtras: Equatable, Sendable {
    var attributes: [XMLAttribute] = []
    var children: [PositionedTag] = []

    /// The attribute names in the order the source file listed them.
    ///
    /// The encoder emits in Xcode's canonical order, but when an element's
    /// attribute set is untouched it replays this order instead. That is what
    /// lets a model written by the MIO `ModelBuilder` generator, whose order
    /// differs from Xcode's, round-trip with a zero-line diff.
    var sourceAttributeOrder: [String] = []
}
