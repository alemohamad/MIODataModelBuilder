//
//  AttributeDefaultTests.swift
//  MIODataModelEditorTests
//
//  Created by MIO Research Labs on 2026.
//
//  Two things the file format is loose about and the editor must not be.
//
//  A Boolean default is spelled at least six ways in models this organisation
//  already ships. All of them have to read, and only one of them should be
//  written, or opening a model would rewrite defaults nobody touched.
//
//  Relationship cardinality lives in two coupled fields, `toMany` and
//  `maxCount`, and setting one without clearing the other produces a
//  relationship the file cannot describe.
//

import Foundation
import Testing
@testable import MIODataModelEditor

@Suite("Boolean defaults")
struct BooleanDefaultTests {

    private func attribute(_ raw: String?) -> ModelAttribute {
        var a = ModelAttribute(name: "flag", type: .boolean)
        a.defaultValueString = raw
        return a
    }

    @Test("Every spelling found in a real model reads",
          arguments: [("YES", true), ("NO", false),
                      ("TRUE", true), ("FALSE", false),
                      ("1", true), ("0", false),
                      ("yes", true), ("no", false)])
    func reads(_ raw: String, _ expected: Bool) {
        #expect(attribute(raw).booleanDefault == expected)
    }

    @Test("Absent and empty are no default")
    func absent() {
        #expect(attribute(nil).booleanDefault == nil)
        #expect(attribute("").booleanDefault == nil)
    }

    @Test("Writing always uses Xcode's spelling")
    func writesCanonically() {
        var a = attribute("0")
        a.booleanDefault = true
        #expect(a.defaultValueString == "YES")

        a.booleanDefault = false
        #expect(a.defaultValueString == "NO")

        a.booleanDefault = nil
        #expect(a.defaultValueString == nil)
    }

    @Test("Reading does not rewrite, so opening a model does not dirty it")
    func readingIsPure() {
        let a = attribute("0")
        _ = a.booleanDefault
        #expect(a.defaultValueString == "0")
    }

    @Test("A value that is not a boolean is reported, not dropped")
    func unreadable() {
        #expect(attribute("maybe").unreadableBooleanDefault == "maybe")
        #expect(attribute("maybe").booleanDefault == nil)

        // Readable ones are not reported.
        #expect(attribute("NO").unreadableBooleanDefault == nil)
        #expect(attribute(nil).unreadableBooleanDefault == nil)
    }

    @Test("Only Boolean attributes report an unreadable boolean")
    func onlyBooleans() {
        var text = ModelAttribute(name: "title", type: .string)
        text.defaultValueString = "maybe"
        #expect(text.unreadableBooleanDefault == nil)
    }

    @Test("Types that cannot carry a default",
          arguments: [AttributeType.binary, .transformable, .composite, .undefined])
    func noDefault(_ type: AttributeType) {
        #expect(type.takesNoDefault)
    }

    @Test("Types that can",
          arguments: [AttributeType.string, .boolean, .integer64, .double,
                      .decimal, .float, .date, .uuid, .uri, .integer16, .integer32])
    func hasDefault(_ type: AttributeType) {
        #expect(type.takesNoDefault == false)
    }
}

@Suite("Date intervals")
struct DateIntervalTests {

    private func attribute(_ raw: String?) -> ModelAttribute {
        var a = ModelAttribute(name: "createdAt", type: .date)
        a.defaultDateTimeInterval = raw
        return a
    }

    /// Core Data counts from 2001-01-01 UTC, not the Unix epoch.
    @Test("The reference date is 2001, not 1970")
    func referenceDate() throws {
        let zero = try #require(ModelAttribute.date(from: "0"))
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = try #require(TimeZone(identifier: "UTC"))
        let parts = utc.dateComponents([.year, .month, .day], from: zero)

        #expect(parts.year == 2001)
        #expect(parts.month == 1)
        #expect(parts.day == 1)

        // The Unix epoch is this far back, and is the value somebody typing
        // "0" for 1970 would actually need.
        #expect(ModelAttribute.interval(from: Date(timeIntervalSince1970: 0)) == "-978307200")
    }

    @Test("Every date default in the models here round-trips byte for byte",
          arguments: ["-725850000", "-725882400", "0", "-978307200", "694224000"])
    func roundTripsUnchanged(_ raw: String) throws {
        let date = try #require(ModelAttribute.date(from: raw))
        #expect(ModelAttribute.interval(from: date) == raw)
    }

    @Test("Reading does not rewrite, so opening a model does not dirty it")
    func readingIsPure() {
        let a = attribute("-725850000")
        _ = a.defaultDate
        _ = a.minDate
        _ = a.maxDate
        #expect(a.defaultDateTimeInterval == "-725850000")
    }

    @Test("Whole seconds are written without a decimal point")
    func noStrayDecimal() {
        var a = attribute(nil)
        a.defaultDate = Date(timeIntervalSinceReferenceDate: -725850000)
        #expect(a.defaultDateTimeInterval == "-725850000")
    }

    @Test("A fractional second survives rather than being rounded away")
    func fractional() throws {
        let raw = try #require(ModelAttribute.interval(from: Date(timeIntervalSinceReferenceDate: 1.5)))
        #expect(raw.contains("."))
        #expect(ModelAttribute.date(from: raw)?.timeIntervalSinceReferenceDate == 1.5)
    }

    @Test("Clearing removes the attribute rather than writing zero")
    func clearing() {
        var a = attribute("-725850000")
        a.defaultDate = nil
        #expect(a.defaultDateTimeInterval == nil)
    }

    @Test("Absent and empty read as no value")
    func absent() {
        #expect(attribute(nil).defaultDate == nil)
        #expect(attribute("").defaultDate == nil)
    }

    @Test("Minimum and maximum use their own fields")
    func bounds() {
        var a = attribute(nil)
        a.minDate = Date(timeIntervalSinceReferenceDate: 0)
        a.maxDate = Date(timeIntervalSinceReferenceDate: 86400)

        #expect(a.minDateTimeInterval == "0")
        #expect(a.maxDateTimeInterval == "86400")
        #expect(a.defaultDateTimeInterval == nil)
    }

    @Test("A value that is not a number is reported, not dropped")
    func unreadable() {
        #expect(attribute("tomorrow").unreadableDateInterval == "tomorrow")
        #expect(attribute("tomorrow").defaultDate == nil)
        #expect(attribute("-725850000").unreadableDateInterval == nil)
        #expect(attribute(nil).unreadableDateInterval == nil)
    }

    @Test("Only Date attributes report an unreadable interval")
    func onlyDates() {
        var text = ModelAttribute(name: "title", type: .string)
        text.defaultDateTimeInterval = "tomorrow"
        #expect(text.unreadableDateInterval == nil)
    }
}

@Suite("Default summary")
struct DefaultSummaryTests {

    private func attribute(_ type: AttributeType, _ raw: String?) -> ModelAttribute {
        var a = ModelAttribute(name: "x", type: type)
        a.defaultValueString = raw
        return a
    }

    @Test("Booleans read as YES or NO whatever the file spells",
          arguments: [("YES", "YES"), ("1", "YES"), ("TRUE", "YES"),
                      ("NO", "NO"), ("0", "NO"), ("FALSE", "NO")])
    func booleans(_ raw: String, _ shown: String) {
        #expect(attribute(.boolean, raw).defaultSummary == shown)
    }

    @Test("No default shows nothing rather than a placeholder")
    func empty() {
        #expect(attribute(.string, nil).defaultSummary == "")
        #expect(attribute(.boolean, nil).defaultSummary == "")
        #expect(attribute(.integer64, nil).defaultSummary == "")
    }

    @Test("Types that cannot carry a default never show one",
          arguments: [AttributeType.binary, .transformable, .composite, .undefined])
    func noDefault(_ type: AttributeType) {
        // Even when the file carries a value it should not be advertised here.
        #expect(attribute(type, "something").defaultSummary == "")
    }

    @Test("Plain values pass through")
    func passthrough() {
        #expect(attribute(.string, "untitled").defaultSummary == "untitled")
        #expect(attribute(.integer64, "1").defaultSummary == "1")
    }

    @Test("A date shows as a date, not as seconds")
    func dates() throws {
        var a = ModelAttribute(name: "createdAt", type: .date)
        a.defaultDateTimeInterval = "-725850000"

        let shown = a.defaultSummary
        #expect(shown.isEmpty == false)
        #expect(shown != "-725850000")

        // Rendered in the reader's time zone, which is the point: the same
        // instant is 1977-12-31 23:00 in UTC and 1978-01-01 00:00 an hour
        // east. Asserting a year here would pass only where it was written,
        // so this pins the FORMAT and leaves the clock alone.
        let instant = Date(timeIntervalSinceReferenceDate: -725850000)
        #expect(shown == instant.formatted(date: .abbreviated, time: .shortened))
    }

    @Test("A value the editor cannot read is still shown, not hidden")
    func unreadable() {
        #expect(attribute(.boolean, "maybe").defaultSummary == "maybe")

        var date = ModelAttribute(name: "d", type: .date)
        date.defaultDateTimeInterval = "tomorrow"
        #expect(date.defaultSummary == "tomorrow")
    }
}

@Suite("Relationship cardinality")
struct CardinalityTests {

    /// A new relationship as `RelationshipsSection.add()` makes one.
    private func fresh() -> ModelRelationship {
        var r = ModelRelationship(name: "items", destinationEntityName: "Item")
        r.optional = true
        r.maxCount = "1"
        return r
    }

    @Test("A new relationship is a to-one")
    func startsToOne() {
        let r = fresh()
        #expect(r.isToMany == false)
        #expect(r.maxCount == "1")
        #expect(r.toMany == nil)
    }

    @Test("Switching to to-many sets toMany and clears maxCount")
    func toMany() {
        var r = fresh()
        r.setToMany(true)
        #expect(r.isToMany)
        #expect(r.toMany == true)
        #expect(r.maxCount == nil)
    }

    @Test("Switching back restores the to-one spelling")
    func backToOne() {
        var r = fresh()
        r.setToMany(true)
        r.setToMany(false)
        #expect(r.isToMany == false)
        #expect(r.toMany == nil)
        #expect(r.maxCount == "1")
    }

    @Test("Setting the same value twice is stable")
    func idempotent() {
        var r = fresh()
        r.setToMany(true)
        let once = r
        r.setToMany(true)
        #expect(r == once)
    }

    @Test("The two fields never coexist")
    func neverBoth() {
        var r = fresh()
        for value in [true, false, true, true, false] {
            r.setToMany(value)
            #expect(!(r.toMany == true && r.maxCount != nil),
                    "toMany and maxCount were both set after setToMany(\(value))")
        }
    }
}
