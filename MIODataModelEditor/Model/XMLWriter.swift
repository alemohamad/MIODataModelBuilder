//
//  XMLWriter.swift
//  MIODataModelEditor
//
//  Created by MIO Research Labs on 2026.
//

import Foundation

/// Serialises an `XMLDocumentText` in exactly the shape Xcode writes a
/// `contents` file.
///
/// The details are not cosmetic. A model file lives in git next to source, so
/// an editor that reformats it turns a one-attribute change into a 4,000-line
/// diff. Every rule below was read off a real model:
///
/// - four spaces per level, LF line endings
/// - childless elements self-close as `<tag/>`
/// - Xcode writes no trailing newline after `</model>`
///
/// The declaration and the trailing newline come from the document rather than
/// being hardcoded, so a file written by the MIO generator keeps its own.
nonisolated enum XMLWriter {
    private static let indentUnit = "    "

    static func write(_ document: XMLDocumentText) -> String {
        var out = document.declaration + "\n"
        append(document.root, depth: 0, into: &out)
        if document.trailingNewline { out += "\n" }
        return out
    }

    static func data(_ document: XMLDocumentText) -> Data {
        Data(write(document).utf8)
    }

    private static func append(_ tag: XMLTag, depth: Int, into out: inout String) {
        let pad = String(repeating: indentUnit, count: depth)

        if let comment = tag.comment {
            out += pad + "<!--" + comment + "-->"
            return
        }

        out += pad + "<" + tag.name
        for attribute in tag.attributes {
            out += " " + attribute.name + "=\"" + escape(attribute.value) + "\""
        }

        if tag.children.isEmpty {
            out += "/>"
            return
        }

        out += ">\n"
        for child in tag.children {
            append(child, depth: depth + 1, into: &out)
            out += "\n"
        }
        out += pad + "</" + tag.name + ">"
    }

    /// Escapes an attribute value.
    ///
    /// `&` must be replaced first or the replacement's own ampersands get
    /// double-escaped on the following passes.
    private static func escape(_ value: String) -> String {
        var out = value.replacingOccurrences(of: "&", with: "&amp;")
        out = out.replacingOccurrences(of: "<", with: "&lt;")
        out = out.replacingOccurrences(of: ">", with: "&gt;")
        out = out.replacingOccurrences(of: "\"", with: "&quot;")
        out = out.replacingOccurrences(of: "\n", with: "&#10;")
        out = out.replacingOccurrences(of: "\r", with: "&#13;")
        out = out.replacingOccurrences(of: "\t", with: "&#9;")
        return out
    }
}
