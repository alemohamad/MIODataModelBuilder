//
//  OptionalBindings.swift
//  MIODataModelEditor
//
//  Created by MIO Research Labs on 2026.
//

import SwiftUI

extension Binding where Value == Bool? {
    /// Presents an absent `YES`/`NO` attribute as off, and writes *absent*
    /// rather than an explicit `NO` when switched off.
    ///
    /// Toggling something on and off again therefore leaves the file exactly as
    /// it was found, instead of littering it with `optional="NO"` on attributes
    /// that never carried it.
    var asFlag: Binding<Bool> {
        Binding<Bool>(get: { wrappedValue ?? false },
                      set: { wrappedValue = $0 ? true : nil })
    }
}

extension Binding where Value == String? {
    /// Presents an absent string attribute as empty, and writes absent back
    /// when cleared.
    var orEmpty: Binding<String> {
        Binding<String>(get: { wrappedValue ?? "" },
                        set: { wrappedValue = $0.isEmpty ? nil : $0 })
    }
}

#Preview("Optional bindings") {
    @Previewable @State var flag: Bool? = nil
    @Previewable @State var text: String? = nil

    Form {
        Toggle("Flag", isOn: $flag.asFlag)
        TextField("Text", text: $text.orEmpty, prompt: Text("absent"))
        LabeledContent("Stored flag", value: flag.map(String.init(describing:)) ?? "nil")
        LabeledContent("Stored text", value: text ?? "nil")
    }
    .formStyle(.grouped)
    .frame(width: 320)
}
