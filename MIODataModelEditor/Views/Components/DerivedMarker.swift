//
//  DerivedMarker.swift
//  MIODataModelEditor
//
//  Created by MIO Research Labs on 2026.
//

import SwiftUI

/// The marker on a derived attribute's row.
///
/// It sits inside the name column rather than in a column of its own. The
/// attributes table is width-matched to the relationships table, and
/// ``EditorLayout/detailMinWidth`` is computed from the relationships row on
/// the stated assumption that it is the wider of the two. A fourth column would
/// quietly make that false, and the failure mode there is clipping, not
/// truncation.
///
/// Orange when the attribute is marked derived with no expression, because Core
/// Data cannot evaluate that and nothing else in the table would say so.
struct DerivedMarker: View {
    let expression: String?

    var body: some View {
        Image(systemName: "function")
            .font(.caption)
            .foregroundStyle(tint)
            .help(label)
            .accessibilityLabel(label)
    }

    private var text: String? {
        guard let expression = expression?.trimmingCharacters(in: .whitespaces),
              expression.isEmpty == false
        else { return nil }
        return expression
    }

    private var tint: AnyShapeStyle {
        text == nil ? AnyShapeStyle(.orange) : AnyShapeStyle(.secondary)
    }

    private var label: String {
        guard let text else { return "Derived, with no derivation expression" }
        return "Derived from \(text)"
    }
}

#Preview("Both states") {
    VStack(alignment: .leading, spacing: 10) {
        HStack { DerivedMarker(expression: "legalEntity.name"); Text("legalEntityName") }
        HStack { DerivedMarker(expression: nil); Text("documentNumber") }
    }
    .padding()
}
