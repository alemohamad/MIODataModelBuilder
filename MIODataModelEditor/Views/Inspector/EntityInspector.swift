//
//  EntityInspector.swift
//  MIODataModelEditor
//
//  Created by MIO Research Labs on 2026.
//

import SwiftUI

/// Inspector for the selected entity.
struct EntityInspector: View {
    @Binding var entity: ModelEntity
    let entityNames: [String]
    /// Renaming touches every reference to the entity and then re-selects it,
    /// neither of which this view can reach, so the owner does both.
    let renameEntity: (String) -> Void

    var body: some View {
        Section {
            LabeledContent("Name") {
                CommittingTextField("Name", value: entity.name) { renameEntity($0) }
                    .textFieldStyle(.plain)
            }
            Toggle("Abstract Entity", isOn: $entity.isAbstract.asFlag)

            Picker("Parent Entity", selection: $entity.parentEntityName.orEmpty) {
                Text("No Parent Entity").tag("")
                ForEach(entityNames.filter { $0 != entity.name }, id: \.self) { name in
                    Text(name).tag(name)
                }
            }

            if let stray = entity.strayAbstract {
                IgnoredSpellingWarning(
                    message: "Abstractness is written as abstract=\"\(stray)\". Core Data reads isAbstract, so this entity is not abstract."
                )
            }
        } header: {
            Text("Entity")
                .foregroundStyle(.secondary)
        }

        Section {
            LabeledContent("Name") {
                CommittingTextField("Class Name", value: entity.representedClassName ?? "", prompt: entity.name) {
                    entity.representedClassName = $0.isEmpty ? nil : $0
                }
            }
            Picker("Codegen", selection: codegen) {
                ForEach(CodeGenerationType.allCases) { type in
                    Text(type.displayName).tag(type)
                }
            }
        } header: {
            Text("Class")
                .foregroundStyle(.secondary)
        }

        ConstraintsSection(entity: $entity)

        Section {
            LabeledContent("Display Name") {
                CommittingTextField("Expression",
                                    value: entity.coreSpotlightDisplayNameExpression ?? "",
                                    prompt: "Expression") {
                    entity.coreSpotlightDisplayNameExpression = $0.isEmpty ? nil : $0
                }
            }
        } header: {
            Text("Spotlight")
                .foregroundStyle(.secondary)
        }

        Section {
            UserInfoTable(userInfo: $entity.userInfo)
        } header: {
            Text("User Info")
                .foregroundStyle(.secondary)
        }

        VersioningSection(versionHashModifier: $entity.versionHashModifier,
                          renamingIdentifier: $entity.renamingIdentifier)
    }

    /// Absent means Manual/None, so selecting it writes the attribute away
    /// again rather than spelling out the default.
    private var codegen: Binding<CodeGenerationType> {
        Binding(get: { entity.codeGenerationType ?? .manualNone },
                set: { entity.codeGenerationType = $0 == .manualNone ? nil : $0 })
    }
}

#Preview("Concrete child entity") {
    @Previewable @State var entity = PreviewSamples.entity

    Form {
        EntityInspector(entity: $entity,
                        entityNames: PreviewSamples.entityNames,
                        renameEntity: { _ in })
    }
    .formStyle(.grouped)
    .frame(width: 340, height: 700)
}

#Preview("Entity with the ignored abstract spelling") {
    @Previewable @State var entity = PreviewSamples.model.entities[2]

    Form {
        EntityInspector(entity: $entity,
                        entityNames: PreviewSamples.entityNames,
                        renameEntity: { _ in })
    }
    .formStyle(.grouped)
    .frame(width: 340, height: 700)
}
