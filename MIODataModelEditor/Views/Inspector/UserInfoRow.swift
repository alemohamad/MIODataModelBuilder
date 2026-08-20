//
//  UserInfoRow.swift
//  MIODataModelEditor
//
//  Created by MIO Research Labs on 2026.
//

import SwiftUI

/// One editable `<entry key="…" value="…"/>` of a ``UserInfoTable``.
struct UserInfoRow: View {
    @Binding var entry: UserInfoEntry

    var body: some View {
        HStack {
            CommittingTextField("Key", value: entry.key, prompt: "key") { entry.key = $0 }
                .textFieldStyle(.plain)
            CommittingTextField("Value", value: entry.value, prompt: "value") { entry.value = $0 }
                .textFieldStyle(.plain)
        }
    }
}

#Preview {
    @Previewable @State var filled = UserInfoEntry(key: "syncPolicy", value: "server")
    @Previewable @State var blank = UserInfoEntry()

    VStack(alignment: .leading, spacing: 2) {
        UserInfoHeader()
        Divider()
        UserInfoRow(entry: $filled)
        Divider()
        UserInfoRow(entry: $blank)
        Divider()
    }
    .padding()
    .frame(width: 300)
}
