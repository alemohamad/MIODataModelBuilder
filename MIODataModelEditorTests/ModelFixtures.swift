//
//  ModelFixtures.swift
//  MIODataModelEditorTests
//
//  Created by MIO Research Labs on 2026.
//

import Foundation

enum ModelFixtures {
    /// A model exercising every construct the editor understands, written in
    /// Xcode's own attribute order and child order.
    ///
    /// Because it is already canonical, the encoder must reproduce it byte for
    /// byte. Anything that drifts is a real ordering bug rather than a quirk of
    /// the sample.
    static let canonical = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <model type="com.apple.IDECoreDataModeler.DataModel" documentVersion="1.0" lastSavedToolsVersion="23231" systemVersion="24A335" minimumToolsVersion="Automatic" sourceLanguage="Swift" userDefinedModelVersionIdentifier="">
        <entity name="Account" representedClassName="Account" isAbstract="YES" syncable="YES" codeGenerationType="class">
            <attribute name="balance" optional="YES" attributeType="Decimal" defaultValueString="0.0"/>
            <attribute name="identifier" attributeType="UUID" usesScalarValueType="NO"/>
            <attribute name="name" optional="YES" attributeType="String"/>
        </entity>
        <entity name="Employee" representedClassName="Employee" parentEntity="Account" syncable="YES">
            <attribute name="hiredAt" attributeType="Date" defaultDateTimeInterval="-725882400" usesScalarValueType="NO"/>
            <attribute name="payload" optional="YES" attributeType="Transformable" valueTransformerName="NSSecureUnarchiveFromData"/>
            <attribute name="rank" optional="YES" attributeType="Integer 16" minValueString="0" maxValueString="10" defaultValueString="0" usesScalarValueType="YES"/>
            <relationship name="manager" optional="YES" maxCount="1" deletionRule="Nullify" destinationEntity="Employee" inverseName="reports" inverseEntity="Employee"/>
            <relationship name="reports" optional="YES" toMany="YES" deletionRule="Cascade" destinationEntity="Employee" inverseName="manager" inverseEntity="Employee"/>
            <fetchedProperty name="seniorReports" optional="YES">
                <fetchRequest name="fetchedPropertyFetchRequest" entity="Employee" predicateString="rank &gt; 5"/>
            </fetchedProperty>
            <fetchIndex name="byRank">
                <fetchIndexElement property="rank" type="Binary" order="ascending"/>
            </fetchIndex>
            <uniquenessConstraints>
                <uniquenessConstraint>
                    <constraint value="identifier"/>
                </uniquenessConstraint>
            </uniquenessConstraints>
            <userInfo>
                <entry key="exportName" value="employee"/>
                <entry key="syncPolicy" value="server"/>
            </userInfo>
        </entity>
        <configuration name="Remote">
            <memberEntity name="Employee"/>
        </configuration>
        <elements>
            <element name="Account" positionX="160" positionY="192" width="128" height="74"/>
            <element name="Employee" positionX="360" positionY="192" width="128" height="149"/>
        </elements>
    </model>
    """

    /// The shape the MIO `ModelBuilder` generator emits: no `standalone`, a
    /// trailing newline, relationship attributes in its own order, and the two
    /// spellings Core Data silently ignores (`defaultValue`, `abstract`).
    static let generatorFlavoured = """
    <?xml version="1.0" encoding="UTF-8"?>
    <model type="com.apple.IDECoreDataModeler.DataModel" documentVersion="1.0" lastSavedToolsVersion="23231" systemVersion="24A335" minimumToolsVersion="Automatic" sourceLanguage="Swift" userDefinedModelVersionIdentifier="">
        <entity name="Task" representedClassName="Task" syncable="YES" abstract="YES">
            <attribute name="isDone" optional="NO" attributeType="Boolean" usesScalarValueType="NO" defaultValue="NO"/>
            <attribute name="title" optional="NO" attributeType="String" usesScalarValueType="YES"/>
            <relationship name="list" destinationEntity="TaskList" optional="YES" deletionRule="Nullify" maxCount="1" inverseEntity="TaskList" inverseName="tasks"/>
        </entity>
        <entity name="TaskList" representedClassName="TaskList" syncable="YES">
            <relationship name="tasks" destinationEntity="Task" optional="YES" deletionRule="Cascade" toMany="YES" inverseEntity="Task" inverseName="list"/>
        </entity>
    </model>

    """

    /// A model using composite attributes, which Core Data added in 2023 and
    /// this editor does not model.
    ///
    /// The `<compositeAttribute>` blocks sit at model level, as siblings of the
    /// entities. Losing them on save would take the type definitions with them
    /// and leave the entity attributes pointing at nothing, so they have to
    /// survive as extras even though nothing in the UI can edit them.
    static let withComposite = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <model type="com.apple.IDECoreDataModeler.DataModel" documentVersion="1.0" minimumToolsVersion="Automatic" sourceLanguage="Swift" userDefinedModelVersionIdentifier="">
        <entity name="Person" representedClassName="Person" syncable="YES">
            <attribute name="home" optional="YES" attributeType="Composite"/>
            <attribute name="name" optional="YES" attributeType="String"/>
        </entity>
        <compositeAttribute name="Address">
            <attribute name="city" optional="YES" attributeType="String"/>
            <attribute name="postcode" optional="YES" attributeType="String"/>
        </compositeAttribute>
    </model>
    """

    /// Constructs this editor does not model: an unknown attribute, an unknown
    /// child element, and comments interleaved between live relationships.
    static let withUnknowns = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <model type="com.apple.IDECoreDataModeler.DataModel" documentVersion="1.0" minimumToolsVersion="Automatic" sourceLanguage="Swift" userDefinedModelVersionIdentifier="">
        <entity name="Widget" representedClassName="Widget" syncable="YES" futureXcodeFlag="YES">
            <attribute name="label" optional="YES" attributeType="String" someUnknownKey="42"/>
            <relationship name="alpha" optional="YES" maxCount="1" deletionRule="Nullify" destinationEntity="Widget"/>
            <!--        <relationship name="beta" deletionRule="No Action" destinationEntity="Widget"/> -->
            <relationship name="gamma" optional="YES" maxCount="1" deletionRule="Nullify" destinationEntity="Widget"/>
            <futureElement name="something" value="preserved"/>
        </entity>
    </model>
    """
}
