//
//  PropertySectionHeader.swift
//  MIODataModelEditor
//
//  Created by MIO Research Labs on 2026.
//

import SwiftUI

/// The disclosure title of a property table.
struct PropertySectionHeader: View {
    let title: String
    @Binding var isExpanded: Bool

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) { isExpanded.toggle() }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .frame(width: 20, height: 20)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                Text(title)
                    .font(.headline)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    @Previewable @State var expanded = true
    @Previewable @State var collapsed = false

    VStack(alignment: .leading) {
        PropertySectionHeader(title: "Attributes", isExpanded: $expanded)
        PropertySectionHeader(title: "Relationships", isExpanded: $collapsed)
        Spacer()
    }
    .padding()
    .frame(width: 320, height: 140)
}
