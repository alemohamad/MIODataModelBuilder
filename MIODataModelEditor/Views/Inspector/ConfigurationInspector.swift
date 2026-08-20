//
//  ConfigurationInspector.swift
//  MIODataModelEditor
//
//  Created by MIO Research Labs on 2026.
//

import SwiftUI

/// Inspector for the selected configuration.
///
/// `Default` cannot be renamed: it is the implicit configuration, and the name
/// is what identifies it. Its `Used with CloudKit` box is live though, and
/// ticking it is what makes the element appear in the file at all.
struct ConfigurationInspector: View {
    @Binding var model: DataModel
    let configurationName: String

    private var isDefault: Bool { configurationName == ModelConfiguration.defaultName }

    private var configuration: ModelConfiguration? {
        model.configuration(named: configurationName)
    }

    var body: some View {
        Section("Configuration") {
            LabeledContent("Name") {
                if isDefault {
                    Text(configurationName).foregroundStyle(.secondary)
                } else {
                    CommittingTextField("Name", value: configurationName) { rename(to: $0) }
                }
            }
            Toggle("Used with CloudKit", isOn: usedWithCloudKit)
        }

        Section("Entities") {
            LabeledContent("Included",
                           value: "\(model.entities(inConfigurationNamed: configurationName).count)")
            if isDefault {
                Text("The default configuration always contains every entity.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Writes through to the stored element, creating it on first use.
    ///
    /// Setting the flag back to false clears it rather than writing
    /// `usedWithCloudKit="NO"`, so an untouched `Default` goes back to being
    /// implicit and drops out of the file again.
    private var usedWithCloudKit: Binding<Bool> {
        Binding(get: { configuration?.usedWithCloudKit ?? false },
                set: { enabled in
                    guard let index = model.indexOfConfiguration(named: configurationName,
                                                                 creatingDefault: true)
                    else { return }
                    model.configurations[index].usedWithCloudKit = enabled ? true : nil
                    if model.configurations[index].isEmptyDefault {
                        model.configurations.remove(at: index)
                    }
                })
    }

    private func rename(to newName: String) {
        guard !newName.isEmpty,
              let index = model.indexOfConfiguration(named: configurationName)
        else { return }
        model.configurations[index].name = newName
    }
}

#Preview("Default") {
    @Previewable @State var model = PreviewSamples.model

    Form { ConfigurationInspector(model: $model, configurationName: ModelConfiguration.defaultName) }
        .formStyle(.grouped)
        .frame(width: 340, height: 340)
}

#Preview("Named configuration") {
    @Previewable @State var model: DataModel = {
        var model = PreviewSamples.model
        var remote = ModelConfiguration(name: "Remote")
        remote.memberEntityNames = ["Employee"]
        remote.usedWithCloudKit = true
        model.configurations = [remote]
        return model
    }()

    Form { ConfigurationInspector(model: $model, configurationName: "Remote") }
        .formStyle(.grouped)
        .frame(width: 340, height: 340)
}
