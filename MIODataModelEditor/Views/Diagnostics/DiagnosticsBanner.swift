//
//  DiagnosticsBanner.swift
//  MIODataModelEditor
//
//  Created by MIO Research Labs on 2026.
//

import SwiftUI

/// The warning strip above the editor, shown when a model carries values
/// written under names Core Data ignores.
struct DiagnosticsBanner: View {
    let count: Int
    let onShow: () -> Void
    let onRepair: () -> Void
    let onIgnore: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 1) {
                Text("^[\(count) value](inflect: true) written under a name Core Data ignores")
                    .font(.callout.weight(.medium))
                Text("These parse without complaint and are then discarded, so the defaults and abstract flags never take effect.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Show", action: onShow)
            Button("Repair All", action: onRepair)
                .buttonStyle(.borderedProminent)
            Button("Ignore", action: onIgnore)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(.orange.opacity(0.10))
    }
}

#Preview("Many") {
    VStack(spacing: 0) {
        DiagnosticsBanner(count: 784, onShow: {}, onRepair: {}, onIgnore: {})
        Divider()
        Spacer()
    }
    .frame(width: 880, height: 160)
}

#Preview("One") {
    VStack(spacing: 0) {
        DiagnosticsBanner(count: 1, onShow: {}, onRepair: {}, onIgnore: {})
        Divider()
        Spacer()
    }
    .frame(width: 880, height: 160)
}
