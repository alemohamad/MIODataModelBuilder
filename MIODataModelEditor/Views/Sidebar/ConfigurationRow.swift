//
//  ConfigurationRow.swift
//  MIODataModelEditor
//
//  Created by MIO Research Labs on 2026.
//

import SwiftUI

/// One configuration in the sidebar list.
struct ConfigurationRow: View {
    let configuration: ModelConfiguration
    /// Called on every click, including one on the row that is already
    /// selected. Optional so the previews stay one-liners.
    var onClick: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 6) {
            TypeBadge(style: .configuration)
            Text(configuration.name.isEmpty ? "Untitled" : configuration.name)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .tag(EditorSelection.SidebarItem.configuration(configuration.name))
        // See EntityRow: List's selection binding does not fire when the value
        // is unchanged, so a click on the current row would otherwise be dead.
        .simultaneousGesture(TapGesture().onEnded { onClick?() })
    }
}

#Preview {
    List {
        Section("Configurations") {
            ConfigurationRow(configuration: ModelConfiguration(name: "Default"))
            ConfigurationRow(configuration: ModelConfiguration(name: "Remote"))
        }
    }
    .frame(width: 240, height: 140)
}
