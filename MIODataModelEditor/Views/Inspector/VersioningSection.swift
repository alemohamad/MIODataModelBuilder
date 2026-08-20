//
//  VersioningSection.swift
//  MIODataModelEditor
//
//  Created by MIO Research Labs on 2026.
//

import SwiftUI

/// The Versioning section, identical for entities and attributes.
///
/// Both fields feed Core Data's migration machinery: the hash modifier forces a
/// version hash change, and the renaming identifier tells a mapping model that
/// this thing used to be called something else.
struct VersioningSection: View {
    @Binding var versionHashModifier: String?
    @Binding var renamingIdentifier: String?

    var body: some View {
        Section("Versioning") {
            LabeledContent("Hash Modifier") {
                CommittingTextField("Hash Modifier",
                                    value: versionHashModifier ?? "",
                                    prompt: "Version Hash Modifier") {
                    versionHashModifier = $0.isEmpty ? nil : $0
                }
                .textFieldStyle(.plain)
                .labelsHidden()
            }
            LabeledContent("Renaming ID") {
                CommittingTextField("Renaming ID",
                                    value: renamingIdentifier ?? "",
                                    prompt: "Renaming Identifier") {
                    renamingIdentifier = $0.isEmpty ? nil : $0
                }
                .textFieldStyle(.plain)
                .labelsHidden()
            }
        }
    }
}

#Preview {
    @Previewable @State var hash: String? = nil
    @Previewable @State var renaming: String? = "OldEmployee"

    Form {
        VersioningSection(versionHashModifier: $hash, renamingIdentifier: $renaming)
    }
    .formStyle(.grouped)
    .frame(width: 340, height: 200)
}
