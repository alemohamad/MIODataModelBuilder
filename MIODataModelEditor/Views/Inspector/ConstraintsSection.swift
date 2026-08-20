//
//  ConstraintsSection.swift
//  MIODataModelEditor
//
//  Created by MIO Research Labs on 2026.
//

import SwiftUI

/// The Constraints list Xcode shows in the entity inspector.
///
/// One row is one `<uniquenessConstraint>`: a group of property names that
/// together have to be unique. Xcode edits a group as a comma separated list,
/// which is why a row is a single text field rather than a nested table.
///
/// Constraints were parsed and re-emitted long before they were editable, so a
/// model that had them kept them; this is the UI that finally reaches them.
struct ConstraintsSection: View {
    @Binding var entity: ModelEntity

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 2) {
                ForEach($entity.uniquenessConstraints) { $group in
                    CommittingTextField("Constraint",
                                        value: Self.joined(group),
                                        prompt: "Property names, comma separated") { text in
                        $group.wrappedValue.constraints = Self.parse(text)
                    }
                    .textFieldStyle(.plain)
                    .labelsHidden()
                    Divider()
                }
                
                if $entity.uniquenessConstraints.isEmpty {
                    Text("No Content")
                        .foregroundStyle(.tertiary)
                        .padding(.vertical, 8)
                        .padding(.leading, 16)
                }

                AddRemoveFooter(onAdd: add,
                                onRemove: removeAction,
                                addHelp: "Add constraint",
                                removeHelp: "Remove last constraint")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } header: {
            Text("Constraints")
                .foregroundStyle(.secondary)
        }
    }

    private static func joined(_ group: ModelUniquenessConstraintGroup) -> String {
        group.constraints.map(\.value).joined(separator: ", ")
    }

    /// Empty names are dropped rather than written, so a stray comma cannot
    /// put `<constraint value=""/>` into the file.
    private static func parse(_ text: String) -> [ModelUniquenessConstraint] {
        text.split(separator: ",")
            .map { ModelUniquenessConstraint(value: $0.trimmingCharacters(in: .whitespaces)) }
            .filter { !$0.value.isEmpty }
    }

    /// See `AttributesSection.removeAction` for why this is not a ternary.
    private var removeAction: (() -> Void)? {
        guard !entity.uniquenessConstraints.isEmpty else { return nil }
        return removeLast
    }

    private func add() {
        // Adding the first group is also what brings the <uniquenessConstraints>
        // element into existence, matching how UserInfoTable materialises
        // <userInfo>.
        entity.hasUniquenessConstraintsElement = true
        entity.uniquenessConstraints.append(ModelUniquenessConstraintGroup())
    }

    private func removeLast() {
        guard !entity.uniquenessConstraints.isEmpty else { return }
        entity.uniquenessConstraints.removeLast()
    }
}

#Preview("Two constraints") {
    @Previewable @State var entity: ModelEntity = {
        var entity = ModelEntity(name: "Employee")
        entity.hasUniquenessConstraintsElement = true
        entity.uniquenessConstraints = [
            ModelUniquenessConstraintGroup(constraints: [ModelUniquenessConstraint(value: "identifier")]),
            ModelUniquenessConstraintGroup(constraints: [ModelUniquenessConstraint(value: "appID"),
                                                        ModelUniquenessConstraint(value: "placeID")])
        ]
        return entity
    }()

    Form {
        ConstraintsSection(entity: $entity)
    }
    .formStyle(.columns)
    .padding(.horizontal, 14)
    .frame(width: 340, height: 240, alignment: .top)
}

#Preview("None") {
    @Previewable @State var entity = ModelEntity(name: "Blank")

    Form {
        ConstraintsSection(entity: $entity)
    }
    .formStyle(.columns)
    .padding(.horizontal, 14)
    .frame(width: 340, height: 240, alignment: .top)
}
