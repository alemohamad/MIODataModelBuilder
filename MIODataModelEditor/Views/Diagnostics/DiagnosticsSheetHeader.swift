//
//  DiagnosticsSheetHeader.swift
//  MIODataModelEditor
//
//  Created by MIO Research Labs on 2026.
//

import SwiftUI

/// Title bar of the issue sheet.
struct DiagnosticsSheetHeader: View {
    let count: Int

    var body: some View {
        HStack {
            Text("Model Issues").font(.headline)
            Spacer()
            Text("^[\(count) issue](inflect: true)")
                .foregroundStyle(.secondary)
        }
        .padding(14)
    }
}

#Preview {
    VStack(spacing: 0) {
        DiagnosticsSheetHeader(count: 0)
        Divider()
        DiagnosticsSheetHeader(count: 1)
        Divider()
        DiagnosticsSheetHeader(count: 784)
    }
    .frame(width: 560)
}
