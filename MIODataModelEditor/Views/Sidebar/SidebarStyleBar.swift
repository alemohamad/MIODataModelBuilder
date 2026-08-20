//
//  SidebarStyleBar.swift
//  MIODataModelEditor
//
//  Created by MIO Research Labs on 2026.
//

import SwiftUI

/// The strip along the bottom of the sidebar: Xcode's outline-style toggle on
/// the left, Add Entity on the right.
struct SidebarStyleBar: View {
    @Binding var outlineStyle: Bool
    let onAddEntity: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Picker("", selection: $outlineStyle) {
                Image(systemName: "list.bullet").tag(false)
                Image(systemName: "list.bullet.indent").tag(true)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            .help("Flat list or inheritance outline")

            Spacer()

            Button(action: onAddEntity) {
                // .plain hit-tests what the LABEL draws, so the gap between the
                // icon and the text is dead space. The contentShape has to be
                // inside the button, on the label: outside it shapes the button
                // view and the style still hit-tests the glyphs.
                Label("Add Entity", systemImage: "plus.circle.fill")
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Add a new entity")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }
}

#Preview("Both styles") {
    @Previewable @State var outline = false

    VStack(spacing: 0) {
        Text(outline ? "Outline style" : "Flat style")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        Divider()
        SidebarStyleBar(outlineStyle: $outline, onAddEntity: {})
    }
    .frame(width: 260, height: 140)
}
