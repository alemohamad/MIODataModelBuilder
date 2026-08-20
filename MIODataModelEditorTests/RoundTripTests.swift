//
//  RoundTripTests.swift
//  MIODataModelEditorTests
//
//  Created by MIO Research Labs on 2026.
//
//  The central promise of this editor: opening a model and saving it without
//  touching anything produces the identical file. A Core Data model lives in
//  git next to source, so an editor that reformats on save turns a one-field
//  change into a four-thousand-line diff, and an editor that drops constructs
//  it does not understand destroys data silently.
//

import Foundation
import Testing
@testable import MIODataModelEditor

@Suite("Round trip")
struct RoundTripTests {

    private func roundTrip(_ source: String) throws -> String {
        let document = try XMLReader.read(data: Data(source.utf8))
        return XMLWriter.write(ModelEncoder.encode(ModelDecoder.decode(document)))
    }

    @Test("A canonical Xcode model re-emits byte for byte")
    func canonicalIsByteExact() throws {
        #expect(try roundTrip(ModelFixtures.canonical) == ModelFixtures.canonical)
    }

    @Test("Generator-flavoured output re-emits byte for byte")
    func generatorFlavourIsByteExact() throws {
        // This one differs from Xcode in declaration, trailing newline and
        // relationship attribute order. All three have to survive, or opening
        // a generator-written model and saving it would rewrite every line.
        #expect(try roundTrip(ModelFixtures.generatorFlavoured) == ModelFixtures.generatorFlavoured)
    }

    @Test("Unknown attributes, unknown elements and comments all survive")
    func unknownsArePreserved() throws {
        #expect(try roundTrip(ModelFixtures.withUnknowns) == ModelFixtures.withUnknowns)
    }

    @Test("Composite attribute definitions survive a save")
    func compositeAttributesArePreserved() throws {
        let output = try roundTrip(ModelFixtures.withComposite)

        // The type definition and the attribute that uses it both have to be
        // there, and in the same place.
        #expect(output.contains("<compositeAttribute name=\"Address\">"))
        #expect(output.contains("<attribute name=\"postcode\" optional=\"YES\" attributeType=\"String\"/>"))
        #expect(output.contains("attributeType=\"Composite\""))
        #expect(output == ModelFixtures.withComposite)
    }

    @Test("A second pass changes nothing more")
    func encodingIsIdempotent() throws {
        for source in [ModelFixtures.canonical, ModelFixtures.generatorFlavoured, ModelFixtures.withUnknowns] {
            let once = try roundTrip(source)
            #expect(try roundTrip(once) == once)
        }
    }

    @Test("The XML declaration is carried through verbatim")
    func declarationIsPreserved() throws {
        let canonical = try XMLReader.read(data: Data(ModelFixtures.canonical.utf8))
        let generator = try XMLReader.read(data: Data(ModelFixtures.generatorFlavoured.utf8))

        #expect(canonical.declaration == "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>")
        #expect(generator.declaration == "<?xml version=\"1.0\" encoding=\"UTF-8\"?>")
        #expect(canonical.trailingNewline == false)
        #expect(generator.trailingNewline == true)
    }

    @Test("A comment keeps its position among live siblings")
    func commentPositionIsPreserved() throws {
        let output = try roundTrip(ModelFixtures.withUnknowns)
        let lines = output.components(separatedBy: "\n")

        let alpha = try #require(lines.firstIndex { $0.contains("name=\"alpha\"") })
        let comment = try #require(lines.firstIndex { $0.contains("<!--") })
        let gamma = try #require(lines.firstIndex { $0.contains("name=\"gamma\"") })

        // Re-emitting comments in a clump at the end of the entity would keep
        // the text but scramble the author's notes.
        #expect(alpha < comment && comment < gamma)
    }

    @Test("Absent YES/NO attributes stay absent")
    func triStateFlagsStayAbsent() throws {
        let source = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <model type="com.apple.IDECoreDataModeler.DataModel" documentVersion="1.0" minimumToolsVersion="Automatic" sourceLanguage="Swift" userDefinedModelVersionIdentifier="">
            <entity name="Thing" representedClassName="Thing" syncable="YES">
                <attribute name="plain" attributeType="String"/>
            </entity>
        </model>
        """
        let output = try roundTrip(source)

        // Modelling these as plain Bool would materialise optional="NO" and
        // transient="NO" on every attribute in the file.
        #expect(!output.contains("optional="))
        #expect(!output.contains("transient="))
        #expect(output == source)
    }

    @Test("Every attribute name in the source is understood or carried")
    func noAttributeIsDropped() throws {
        for source in [ModelFixtures.canonical, ModelFixtures.generatorFlavoured, ModelFixtures.withUnknowns] {
            let output = try roundTrip(source)
            for name in Self.attributeNames(in: source) {
                #expect(output.contains("\(name)=\""), "lost attribute \(name)")
            }
        }
    }

    /// Every `foo="` key appearing anywhere in the document.
    private static func attributeNames(in xml: String) -> Set<String> {
        var names: Set<String> = []
        var current = ""
        for character in xml {
            if character.isLetter {
                current.append(character)
            } else {
                if character == "=", !current.isEmpty { names.insert(current) }
                current = ""
            }
        }
        return names
    }
}
