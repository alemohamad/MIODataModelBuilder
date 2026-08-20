//
//  XMLReader.swift
//  MIODataModelEditor
//
//  Created by MIO Research Labs on 2026.
//

import Foundation

nonisolated enum XMLReaderError: Error, LocalizedError {
    case notXML(underlying: Error)
    case noRootElement

    var errorDescription: String? {
        switch self {
        case .notXML(let underlying): "The file is not valid XML: \(underlying.localizedDescription)"
        case .noRootElement:          "The XML document has no root element."
        }
    }
}

/// Parses a `contents` file into an `XMLDocumentText`.
///
/// Foundation's `XMLDocument` is used rather than `XMLParser` for one specific
/// reason: `XMLParser` hands attributes over as a `[String: String]`, which
/// loses their order. `XMLDocument.attributes` is an array in document order,
/// which is what a faithful re-emit needs.
nonisolated enum XMLReader {
    static func read(data: Data) throws -> XMLDocumentText {
        let doc: XMLDocument
        do {
            doc = try XMLDocument(data: data, options: [.nodePreserveWhitespace])
        } catch {
            throw XMLReaderError.notXML(underlying: error)
        }

        guard let root = doc.rootElement() else { throw XMLReaderError.noRootElement }

        let text = String(decoding: data, as: UTF8.self)
        return XMLDocumentText(root: convert(root),
                               declaration: declaration(in: text),
                               trailingNewline: text.hasSuffix("\n"))
    }

    static func read(contentsOf url: URL) throws -> XMLDocumentText {
        try read(data: Data(contentsOf: url))
    }

    /// Lifts the literal `<?xml …?>` prologue off the front of the file so it
    /// can be written back exactly as it came in.
    private static func declaration(in text: String) -> String {
        guard text.hasPrefix("<?xml"), let end = text.range(of: "?>") else {
            return XMLDocumentText.xcodeDeclaration
        }
        return String(text[text.startIndex ..< end.upperBound])
    }

    private static func convert(_ element: XMLElement) -> XMLTag {
        var tag = XMLTag(element.name ?? "")

        for attribute in element.attributes ?? [] {
            guard let name = attribute.name else { continue }
            tag.attributes.append(XMLAttribute(name, attribute.stringValue ?? ""))
        }

        for child in element.children ?? [] {
            switch child.kind {
            case .element:
                guard let childElement = child as? XMLElement else { continue }
                tag.children.append(convert(childElement))
            case .comment:
                tag.children.append(.comment(child.stringValue ?? ""))
            default:
                // Text and whitespace between elements carry no meaning in this
                // format; the writer regenerates indentation from scratch.
                continue
            }
        }

        return tag
    }
}
