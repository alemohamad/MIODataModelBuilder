//
//  ConfigurationTests.swift
//  MIODataModelEditorTests
//
//  Created by MIO Research Labs on 2026.
//
//  The `Default` configuration is implicit: Xcode shows it for every model and
//  writes it for none. Showing it in the sidebar must not be enough to put it
//  in the file, or opening and saving any model here would add an element Xcode
//  never wrote.
//

import Foundation
import Testing
@testable import MIODataModelEditor

@Suite("Configurations")
struct ConfigurationTests {

    private func decode(_ source: String) throws -> DataModel {
        ModelDecoder.decode(try XMLReader.read(data: Data(source.utf8)))
    }

    private func emit(_ model: DataModel) -> String {
        XMLWriter.write(ModelEncoder.encode(model))
    }

    private let bare = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <model type="com.apple.IDECoreDataModeler.DataModel" documentVersion="1.0" minimumToolsVersion="Automatic" sourceLanguage="Swift" userDefinedModelVersionIdentifier="">
        <entity name="Thing" representedClassName="Thing" syncable="YES"/>
    </model>
    """

    @Test("Default is offered even when the file declares no configuration")
    func defaultIsSynthesised() throws {
        let model = try decode(bare)
        #expect(model.configurations.isEmpty)
        #expect(model.sidebarConfigurations.map(\.name) == ["Default"])
    }

    @Test("Showing Default does not write it")
    func defaultIsNotWritten() throws {
        var model = try decode(bare)
        _ = model.sidebarConfigurations

        // Even materialising the element leaves the output unchanged, because
        // an untouched Default carries nothing Core Data would act on.
        _ = model.indexOfConfiguration(named: "Default", creatingDefault: true)
        #expect(emit(model) == bare)
    }

    @Test("Default appears in the file once it carries a setting")
    func defaultIsWrittenOnceItMatters() throws {
        var model = try decode(bare)
        // Hoisted out of `#require`: the macro evaluates its argument inside a
        // closure, where `model` is immutable and a mutating call cannot run.
        let created = model.indexOfConfiguration(named: "Default", creatingDefault: true)
        let index = try #require(created)
        model.configurations[index].usedWithCloudKit = true

        let output = emit(model)
        #expect(output.contains("<configuration name=\"Default\" usedWithCloudKit=\"YES\"/>"))
    }

    @Test("Clearing the setting takes Default back out of the file")
    func defaultLeavesAgain() throws {
        var model = try decode(bare)
        let created = model.indexOfConfiguration(named: "Default", creatingDefault: true)
        let index = try #require(created)
        model.configurations[index].usedWithCloudKit = true
        model.configurations[index].usedWithCloudKit = nil

        #expect(emit(model) == bare)
    }

    @Test("A declared configuration round-trips with its members")
    func namedConfigurationRoundTrips() throws {
        let source = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <model type="com.apple.IDECoreDataModeler.DataModel" documentVersion="1.0" minimumToolsVersion="Automatic" sourceLanguage="Swift" userDefinedModelVersionIdentifier="">
            <entity name="Thing" representedClassName="Thing" syncable="YES"/>
            <entity name="Other" representedClassName="Other" syncable="YES"/>
            <configuration name="Remote" usedWithCloudKit="YES">
                <memberEntity name="Thing"/>
            </configuration>
        </model>
        """
        let model = try decode(source)
        let remote = try #require(model.configuration(named: "Remote"))

        #expect(remote.usedWithCloudKit == true)
        #expect(remote.memberEntityNames == ["Thing"])
        #expect(model.sidebarConfigurations.map(\.name) == ["Default", "Remote"])
        #expect(emit(model) == source)
    }

    @Test("A declared Default is kept, not treated as implicit")
    func declaredDefaultIsPreserved() throws {
        let source = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <model type="com.apple.IDECoreDataModeler.DataModel" documentVersion="1.0" minimumToolsVersion="Automatic" sourceLanguage="Swift" userDefinedModelVersionIdentifier="">
            <entity name="Thing" representedClassName="Thing" syncable="YES"/>
            <configuration name="Default" usedWithCloudKit="YES"/>
        </model>
        """
        #expect(try emit(decode(source)) == source)
    }

    @Test("Default contains every entity, a named configuration only its members")
    func membershipIsResolved() throws {
        let source = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <model type="com.apple.IDECoreDataModeler.DataModel" documentVersion="1.0" minimumToolsVersion="Automatic" sourceLanguage="Swift" userDefinedModelVersionIdentifier="">
            <entity name="Thing" representedClassName="Thing" syncable="YES"/>
            <entity name="Other" representedClassName="Other" syncable="YES"/>
            <configuration name="Remote">
                <memberEntity name="Thing"/>
            </configuration>
        </model>
        """
        let model = try decode(source)

        #expect(model.entities(inConfigurationNamed: "Default").map(\.name) == ["Other", "Thing"])
        #expect(model.entities(inConfigurationNamed: "Remote").map(\.name) == ["Thing"])
    }

    @Test("A model with no configurations still saves without one")
    func modelWithoutConfigurationsStaysWithoutOne() throws {
        // The common case by far: most models never declare a configuration,
        // which is exactly why showing Default must not introduce one.
        let model = try decode(bare)
        #expect(model.configurations.isEmpty)
        #expect(model.sidebarConfigurations.count == 1)
        #expect(emit(model) == bare)
    }
}
