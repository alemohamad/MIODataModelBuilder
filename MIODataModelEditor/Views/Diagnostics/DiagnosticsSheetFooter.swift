//
//  DiagnosticsSheetFooter.swift
//  MIODataModelEditor
//
//  Created by MIO Research Labs on 2026.
//

import SwiftUI

/// Action bar of the issue sheet.
///
/// Repair only appears when something is mechanically fixable. Most diagnostics
/// (a dangling destination, a duplicate name) need a decision from the author,
/// so offering a button for them would be a lie.
struct DiagnosticsSheetFooter: View {
    let canRepair: Bool
    let onRepair: () -> Void
    let onDone: () -> Void

    var body: some View {
        HStack {
            if canRepair {
                Button("Repair All", action: onRepair)
                    .buttonStyle(.borderedProminent)
            }
            Spacer()
            Button("Done", action: onDone)
                .keyboardShortcut(.defaultAction)
        }
        .padding(14)
    }
}

#Preview {
    VStack(spacing: 0) {
        DiagnosticsSheetFooter(canRepair: true, onRepair: {}, onDone: {})
        Divider()
        DiagnosticsSheetFooter(canRepair: false, onRepair: {}, onDone: {})
    }
    .frame(width: 560)
}
