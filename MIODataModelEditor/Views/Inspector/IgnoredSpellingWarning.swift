//
//  IgnoredSpellingWarning.swift
//  MIODataModelEditor
//
//  Created by MIO Research Labs on 2026.
//

import SwiftUI

/// Inline warning for a value written under a name Core Data does not read.
///
/// Both cases (`defaultValue` for `defaultValueString`, `abstract` for
/// `isAbstract`) parse without complaint and are then discarded, so nothing
/// surfaces until behaviour is quietly wrong at runtime. Showing it next to the
/// field is the point: the inspector otherwise displays an empty default and
/// an unchecked box, with no hint that the file disagrees.
struct IgnoredSpellingWarning: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.caption)
            .foregroundStyle(.orange)
    }
}

#Preview {
    Form {
        Section("Default Value") {
            IgnoredSpellingWarning(
                message: "Default is written as defaultValue=\"NO\". Core Data reads defaultValueString, so this attribute has no default."
            )
        }
    }
    .formStyle(.grouped)
    .frame(width: 340)
}
