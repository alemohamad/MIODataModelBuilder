//
//  AttributeInspector.swift
//  MIODataModelEditor
//
//  Created by MIO Research Labs on 2026.
//

import SwiftUI

/// Inspector for the selected attribute.
struct AttributeInspector: View {
    @Binding var attribute: ModelAttribute

    /// Every relationship on the entity being inspected, to-many included.
    ///
    /// The to-many ones are filtered out of the picker but still have to arrive
    /// here, so an expression naming one can be reported as a to-many rather
    /// than as a name that does not exist.
    let relationships: [ModelRelationship]

    /// The attributes visible on an entity, inherited ones included.
    let attributesInEntity: (String) -> [ModelAttribute]

    /// The relationship half of the derivation while the attribute half has not
    /// been chosen yet.
    ///
    /// A half-built keypath is not a valid expression, so it cannot be written
    /// to the file and read back out. `InspectorPanel` gives this view a fresh
    /// identity per property, so the draft resets when the selection moves.
    @State private var relationshipDraft: String?

    /// Whether the expression is being written by hand.
    ///
    /// Inferred from the file rather than stored: an expression the pickers
    /// cannot represent is by definition hand-written. `nil` means nobody has
    /// overridden that reading.
    @State private var customExpression: Bool?

    var body: some View {
        Section("Attribute") {
            LabeledContent("Name") {
                CommittingTextField("Name", value: attribute.name) { attribute.name = $0 }
            }
            Picker("Type", selection: $attribute.type) {
                ForEach(AttributeType.allCases) { type in
                    Text(type.displayName).tag(type)
                }
            }
            Toggle("Optional", isOn: $attribute.optional.asFlag)
            Toggle("Transient", isOn: $attribute.transient.asFlag)
            Toggle("Derived", isOn: $attribute.derived.asFlag)
            Toggle("Allows Cloud Encryption", isOn: $attribute.allowsCloudEncryption.asFlag)
        }

        // Its own section, the way Xcode's inspector groups it, but directly
        // under the toggle that reveals it rather than seven slivers further
        // down. Inside "Attribute" these read as peers of Optional and
        // Transient, which is what they are not.
        if attribute.isDerived {
            Section("Derivation") {
                derivation
            }
        }

        Section("Default Value") {
            // Dates carry their default as a seconds-since-reference-date
            // interval rather than in defaultValueString, so a Date attribute
            // has to edit the other field or the value is unreachable.
            if attribute.type == .date {
                LabeledContent("Default") {
                    DateIntervalField(date: $attribute.defaultDate,
                                      raw: attribute.defaultDateTimeInterval,
                                      prompt: "No Default Value")
                }
            } else if attribute.type == .boolean {
                // Two values and an absence. A free-text field here invites a
                // typo that Core Data drops without a word.
                Picker("Default", selection: $attribute.booleanDefault) {
                    Text("No Default Value").tag(Bool?.none)
                    Text("YES").tag(Bool?.some(true))
                    Text("NO").tag(Bool?.some(false))
                }
            } else if attribute.type.takesNoDefault {
                LabeledContent("Default") {
                    Text("Not applicable")
                        .foregroundStyle(.secondary)
                }
            } else {
                LabeledContent("Default") {
                    CommittingTextField("Default", value: attribute.defaultValueString ?? "", prompt: "No Default Value") {
                        attribute.defaultValueString = $0.isEmpty ? nil : $0
                    }
                }
            }
            Toggle("Use Scalar Type", isOn: $attribute.usesScalarValueType.asFlag)

            if let raw = attribute.unreadableDateInterval {
                IgnoredSpellingWarning(
                    message: "Default is written as \"\(raw)\", which is not a number of seconds. It is still in the file. Choosing a date above replaces it."
                )
            }

            if let raw = attribute.unreadableBooleanDefault {
                IgnoredSpellingWarning(
                    message: "Default is written as \"\(raw)\", which is not a boolean this editor recognises. It is still in the file. Choosing a value above replaces it."
                )
            }

            if let stray = attribute.strayDefaultValue {
                IgnoredSpellingWarning(
                    message: "Default is written as defaultValue=\"\(stray)\". Core Data reads defaultValueString, so this attribute has no default."
                )
            }
        }

        Section("Validation") {
            // Same split as the default value: dates use the interval fields.
            if attribute.type == .date {
                LabeledContent("Minimum") {
                    DateIntervalField(date: $attribute.minDate,
                                      raw: attribute.minDateTimeInterval,
                                      prompt: "None")
                }
                LabeledContent("Maximum") {
                    DateIntervalField(date: $attribute.maxDate,
                                      raw: attribute.maxDateTimeInterval,
                                      prompt: "None")
                }
            } else {
                LabeledContent("Minimum") {
                    CommittingTextField("Minimum", value: attribute.minValueString ?? "", prompt: "None") {
                        attribute.minValueString = $0.isEmpty ? nil : $0
                    }
                }
                LabeledContent("Maximum") {
                    CommittingTextField("Maximum", value: attribute.maxValueString ?? "", prompt: "None") {
                        attribute.maxValueString = $0.isEmpty ? nil : $0
                    }
                }
            }
        }

        Section("Advanced") {
            Toggle("Index in Spotlight", isOn: $attribute.spotlightIndexingEnabled.asFlag)
            Toggle("Preserve After Deletion", isOn: $attribute.preservesValueInHistoryOnDeletion.asFlag)
            if attribute.type == .transformable {
                LabeledContent("Transformer") {
                    CommittingTextField("Transformer", value: attribute.valueTransformerName ?? "", prompt: "Default") {
                        attribute.valueTransformerName = $0.isEmpty ? nil : $0
                    }
                }
                LabeledContent("Custom Class") {
                    CommittingTextField("Custom Class", value: attribute.customClassName ?? "", prompt: "NSObject") {
                        attribute.customClassName = $0.isEmpty ? nil : $0
                    }
                }
            }
            // Xcode offers external storage for Binary Data only.
            if attribute.type == .binary {
                Toggle("Allows External Storage", isOn: $attribute.storedInExternalRecordFile.asFlag)
            }
        }

        Section("User Info") {
            UserInfoTable(userInfo: $attribute.userInfo)
        }

        VersioningSection(versionHashModifier: $attribute.versionHashModifier,
                          renamingIdentifier: $attribute.renamingIdentifier)
    }

    // MARK: - Derivation

    /// Two pickers that build the expression, and the expression itself as
    /// their result rather than as a second way in.
    ///
    /// The pickers cover the one shape the models here use, a value flattened
    /// across a to-one relationship, and they make a misspelled keypath
    /// unrepresentable. Nothing else in the toolchain would catch one: neither
    /// Xcode's model editor nor `momc` validates the expression, so a typo
    /// survives to runtime.
    ///
    /// Which is exactly why the field is read-only while the pickers are
    /// driving it. Once they have written a keypath, hand-editing it can only
    /// make it worse. Core Data's grammar is wider than the pickers though, so
    /// `Custom Expression` unlocks the field for the forms they cannot build.
    /// Deliberate, rather than one stray click away.
    @ViewBuilder
    private var derivation: some View {
        if isCustomExpression {
            LabeledContent("Expression") {
                CommittingTextField("Expression",
                                    value: attribute.derivationExpression ?? "",
                                    prompt: "Expression") {
                    attribute.derivationExpression = $0.isEmpty ? nil : $0
                    // The typed expression is now the truth. A stale draft
                    // would keep showing a relationship the file no longer names.
                    relationshipDraft = nil
                }
            }
        } else {
            Picker("Derive From",
                   selection: $attribute.derivationRelationship(draft: $relationshipDraft,
                                                                relationships: relationships,
                                                                attributesInEntity: attributesInEntity)) {
                Text("None").tag("")
                ForEach(relationshipOptions, id: \.self) { name in
                    Text(relationshipLabel(name)).tag(name)
                }
            }

            Picker("Value", selection: $attribute.derivationAttribute(relationship: selectedRelationship)) {
                Text("None").tag("")
                ForEach(attributeOptions, id: \.self) { name in
                    Text(attributeLabel(name)).tag(name)
                }
            }

            LabeledContent("Expression") {
                Text(attribute.derivationText ?? "None")
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }

        Toggle("Custom Expression", isOn: $customExpression.overriding(attribute.hasAdvancedDerivation))
            // An expression the pickers cannot show has nowhere to go back to,
            // so the way out is to clear it rather than to flip this.
            .disabled(attribute.hasAdvancedDerivation)

        if attribute.isDerivedWithoutExpression {
            DerivationNote("Derived with no expression. Core Data cannot evaluate this, and the model will not compile.",
                           systemImage: "exclamationmark.triangle.fill",
                           tint: .orange)
        }

        if attribute.hasAdvancedDerivation {
            DerivationNote("Not a relationship keypath, so the pickers cannot build it. Clear the expression to go back to them.",
                           systemImage: "info.circle.fill",
                           tint: .secondary)
        }

        if let missing = missingRelationship {
            DerivationNote("This entity has no relationship named \"\(missing)\".",
                           systemImage: "exclamationmark.triangle.fill",
                           tint: .orange)
        }

        if let toMany = toManyRelationship {
            DerivationNote("\"\(toMany)\" is to-many, and a plain keypath only crosses a to-one. Core Data wants an @operation here, such as \(toMany).@count, which needs Custom Expression.",
                           systemImage: "exclamationmark.triangle.fill",
                           tint: .orange)
        }

        if let sourceType = mismatchedSourceType {
            DerivationNote("The source is \(sourceType.displayName) and this attribute is \(attribute.type.displayName).",
                           systemImage: "exclamationmark.triangle.fill",
                           tint: .orange)
        }
    }

    /// Whether the raw field is in charge. An expression the pickers cannot
    /// represent is hand-written by definition, so that reading is the default.
    private var isCustomExpression: Bool {
        customExpression ?? attribute.hasAdvancedDerivation
    }

    // MARK: - Derivation state

    /// The relationship the pickers are working from: the draft if one is being
    /// built, otherwise whatever the saved expression names.
    private var selectedRelationship: String {
        relationshipDraft ?? attribute.keyPathDerivation?.relationshipName ?? ""
    }

    /// To-one relationships, plus the current selection when it is not one of
    /// them.
    ///
    /// A `Picker` whose selection matches no tag shows nothing at all, which
    /// would make a keypath across a to-many, or across a relationship that has
    /// since been renamed, look like an empty control rather than a problem.
    private var relationshipOptions: [String] {
        var names = relationships.filter { $0.isToMany == false }.map(\.name)
        let current = selectedRelationship
        if current.isEmpty == false, names.contains(current) == false {
            names.append(current)
        }
        return names
    }

    private func relationshipLabel(_ name: String) -> String {
        guard let relationship = relationships.first(where: { $0.name == name }) else {
            return "\(name) (missing)"
        }
        if relationship.isToMany { return "\(name) (to-many)" }
        return name
    }

    /// The Value picker's options, plus the current selection when it is not
    /// one of them: same reason as ``relationshipOptions``, and it is what
    /// happens the moment the relationship half is wrong.
    private var attributeOptions: [String] {
        var names = sourceAttributes.map(\.name)
        let current = attribute.keyPathDerivation?.attributeName ?? ""
        if current.isEmpty == false, names.contains(current) == false {
            names.append(current)
        }
        return names
    }

    private func attributeLabel(_ name: String) -> String {
        guard let source = sourceAttributes.first(where: { $0.name == name }) else {
            return "\(name) (missing)"
        }
        return "\(name) (\(source.type.displayName))"
    }

    /// The attributes the Value picker offers: everything on the selected
    /// relationship's destination, inherited attributes included.
    private var sourceAttributes: [ModelAttribute] {
        guard let relationship = relationships.first(where: { $0.name == selectedRelationship }),
              relationship.isToMany == false,
              let destination = relationship.destinationEntityName
        else { return [] }
        return attributesInEntity(destination)
    }

    /// Named by the expression but not on this entity at all.
    private var missingRelationship: String? {
        guard let keyPath = attribute.keyPathDerivation,
              relationships.contains(where: { $0.name == keyPath.relationshipName }) == false
        else { return nil }
        return keyPath.relationshipName
    }

    /// Named by the expression, present, but to-many.
    ///
    /// Reported separately from a name that does not exist, because the fix is
    /// different. Core Data does support deriving across a to-many, through an
    /// `@operation` component rather than a plain keypath, and saying so is
    /// more use than saying the relationship is not there when it plainly is.
    private var toManyRelationship: String? {
        guard let keyPath = attribute.keyPathDerivation,
              let relationship = relationships.first(where: { $0.name == keyPath.relationshipName }),
              relationship.isToMany
        else { return nil }
        return keyPath.relationshipName
    }

    /// The source attribute's type, when it disagrees with this attribute's.
    ///
    /// Reported rather than prevented. The picker still offers every attribute
    /// on the destination, because a model can be mid-edit and hiding the
    /// choice would be more confusing than flagging it.
    private var mismatchedSourceType: AttributeType? {
        guard let keyPath = attribute.keyPathDerivation,
              let source = sourceAttributes.first(where: { $0.name == keyPath.attributeName }),
              source.type != attribute.type
        else { return nil }
        return source.type
    }

}

/// A line of explanation under the derivation controls.
private struct DerivationNote: View {
    let message: String
    let systemImage: String
    let tint: Color

    init(_ message: String, systemImage: String, tint: Color) {
        self.message = message
        self.systemImage = systemImage
        self.tint = tint
    }

    var body: some View {
        Label(message, systemImage: systemImage)
            .font(.caption)
            .foregroundStyle(tint)
    }
}

#Preview("Numeric with bounds") {
    @Previewable @State var attribute = PreviewSamples.entity.attributes[3]

    Form {
        AttributeInspector(attribute: $attribute,
                           relationships: PreviewSamples.entity.relationships,
                           attributesInEntity: PreviewSamples.attributes(inEntityNamed:))
    }
        .formStyle(.grouped)
        .frame(width: 340, height: 800)
}

#Preview("Date, whose default and bounds live in the interval fields") {
    @Previewable @State var attribute: ModelAttribute = {
        var attribute = ModelAttribute(name: "hiredAt", type: .date)
        attribute.optional = true
        attribute.defaultDateTimeInterval = "700000000"
        attribute.minDateTimeInterval = "600000000"
        return attribute
    }()

    Form {
        AttributeInspector(attribute: $attribute,
                           relationships: PreviewSamples.entity.relationships,
                           attributesInEntity: PreviewSamples.attributes(inEntityNamed:))
    }
        .formStyle(.columns)
        .padding(.horizontal, 14)
        .frame(width: 340, height: 800, alignment: .top)
}

#Preview("Derived across a relationship") {
    @Previewable @State var attribute: ModelAttribute = {
        var attribute = ModelAttribute(name: "managerName", type: .string)
        attribute.optional = true
        attribute.derived = true
        attribute.derivationExpression = "manager.name"
        return attribute
    }()

    Form {
        AttributeInspector(attribute: $attribute,
                           relationships: PreviewSamples.entity.relationships,
                           attributesInEntity: PreviewSamples.attributes(inEntityNamed:))
    }
    .formStyle(.columns)
    .padding(.horizontal, 14)
    .frame(width: 340, height: 800, alignment: .top)
}

#Preview("Derived, nothing chosen yet") {
    @Previewable @State var attribute: ModelAttribute = {
        var attribute = ModelAttribute(name: "managerName", type: .string)
        attribute.optional = true
        attribute.derived = true
        return attribute
    }()

    Form {
        AttributeInspector(attribute: $attribute,
                           relationships: PreviewSamples.entity.relationships,
                           attributesInEntity: PreviewSamples.attributes(inEntityNamed:))
    }
    .formStyle(.columns)
    .padding(.horizontal, 14)
    .frame(width: 340, height: 800, alignment: .top)
}

#Preview("Derived by an expression the pickers cannot show") {
    @Previewable @State var attribute: ModelAttribute = {
        var attribute = ModelAttribute(name: "fullName", type: .string)
        attribute.derived = true
        attribute.derivationExpression = "firstName ++ \" \" ++ lastName"
        return attribute
    }()

    Form {
        AttributeInspector(attribute: $attribute,
                           relationships: PreviewSamples.entity.relationships,
                           attributesInEntity: PreviewSamples.attributes(inEntityNamed:))
    }
    .formStyle(.columns)
    .padding(.horizontal, 14)
    .frame(width: 340, height: 800, alignment: .top)
}

#Preview("Derived across a to-many, which is not allowed") {
    @Previewable @State var attribute: ModelAttribute = {
        var attribute = ModelAttribute(name: "reportRank", type: .integer16)
        attribute.derived = true
        attribute.derivationExpression = "reports.rank"
        return attribute
    }()

    Form {
        AttributeInspector(attribute: $attribute,
                           relationships: PreviewSamples.entity.relationships,
                           attributesInEntity: PreviewSamples.attributes(inEntityNamed:))
    }
    .formStyle(.columns)
    .padding(.horizontal, 14)
    .frame(width: 340, height: 800, alignment: .top)
}

#Preview("Transformable") {
    @Previewable @State var attribute: ModelAttribute = {
        var attribute = ModelAttribute(name: "payload", type: .transformable)
        attribute.optional = true
        attribute.valueTransformerName = "NSSecureUnarchiveFromData"
        return attribute
    }()

    Form {
        AttributeInspector(attribute: $attribute,
                           relationships: PreviewSamples.entity.relationships,
                           attributesInEntity: PreviewSamples.attributes(inEntityNamed:))
    }
        .formStyle(.grouped)
        .frame(width: 340, height: 800)
}

#Preview("With the ignored default spelling") {
    @Previewable @State var attribute = PreviewSamples.model.entities[2].attributes[0]

    Form {
        AttributeInspector(attribute: $attribute,
                           relationships: PreviewSamples.entity.relationships,
                           attributesInEntity: PreviewSamples.attributes(inEntityNamed:))
    }
        .formStyle(.grouped)
        .frame(width: 340, height: 800)
}
