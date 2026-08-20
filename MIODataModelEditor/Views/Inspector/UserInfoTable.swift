//
//  UserInfoTable.swift
//  MIODataModelEditor
//
//  Created by MIO Research Labs on 2026.
//

import SwiftUI

/// The Key/Value table Xcode shows under "User Info".
struct UserInfoTable: View {
    @Binding var userInfo: UserInfoBlock

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            UserInfoHeader()
            Divider()

            ForEach($userInfo.entries) { $entry in
                UserInfoRow(entry: $entry)
                Divider()
            }
            
            // Minimum height of empty entries.
            ForEach(EmptyUserInfoRow.padding(for: userInfo.entries.count), id: \.self) { _ in
                EmptyUserInfoRow()
            }

            AddRemoveFooter(onAdd: add,
                            onRemove: removeAction,
                            addHelp: "Add entry",
                            removeHelp: "Remove last entry")
        }
    }

    /// Nothing to remove from an empty table.
    /// See `AttributesSection.removeAction` for why this is not a ternary.
    private var removeAction: (() -> Void)? {
        guard !userInfo.entries.isEmpty else { return nil }
        return removeLast
    }

    private func add() {
        // Adding the first entry is also what brings the <userInfo> element
        // into existence.
        userInfo.isPresent = true
        userInfo.entries.append(UserInfoEntry())
    }

    private func removeLast() {
        guard !userInfo.entries.isEmpty else { return }
        userInfo.entries.removeLast()
    }
}

#Preview("Populated") {
    @Previewable @State var userInfo = PreviewSamples.entity.userInfo

    Form {
        Section("User Info") {
            UserInfoTable(userInfo: $userInfo)
        }
    }
    .formStyle(.grouped)
    .frame(width: 340, height: 260)
}

#Preview("Empty") {
    @Previewable @State var userInfo = UserInfoBlock()

    Form {
        Section("User Info") {
            UserInfoTable(userInfo: $userInfo)
        }
    }
    .formStyle(.grouped)
    .frame(width: 340, height: 220)
}
