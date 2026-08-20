//
//  OptionalMarker.swift
//  MIODataModelEditor
//
//  Created by MIO Research Labs on 2026.
//

import SwiftUI

/// Marks an attribute the model allows to hold no value.
///
/// A dimmed `?` rather than an icon, deliberately. 59% of the 2,551 attributes
/// in the Dual Link model are optional, so a mark with the weight of a symbol
/// would land on three rows in five and read as decoration. `?` is also how a
/// Swift developer already reads optionality, so it needs no legend.
///
/// It shares the trailing slot of the name column with ``DerivedMarker``, for
/// the width reason set out there.
struct OptionalMarker: View {
    var body: some View {
        Text("?")
            .font(.callout.weight(.medium))
            .foregroundStyle(.tertiary)
            .help("Optional")
            .accessibilityLabel("Optional")
    }
}

#Preview("Alongside the derived marker") {
    VStack(alignment: .leading, spacing: 10) {
        HStack { Text("color"); OptionalMarker() }
        HStack { Text("folderTitle"); OptionalMarker(); DerivedMarker(expression: "folder.title") }
        HStack { Text("identifier") }
    }
    .padding()
}
