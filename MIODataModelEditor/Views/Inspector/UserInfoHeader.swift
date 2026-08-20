//
//  UserInfoHeader.swift
//  MIODataModelEditor
//
//  Created by MIO Research Labs on 2026.
//

import SwiftUI

/// The Key/Value captions above a ``UserInfoTable``.
///
/// Its own view rather than a `PropertyColumnHeader`: the property tables lay
/// out on fixed widths to line up with their rows, while this one splits the
/// available width evenly with the inspector.
struct UserInfoHeader: View {
    var body: some View {
        HStack {
            Text("Key")
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Value")
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 2) {
        UserInfoHeader()
        Divider()
    }
    .padding()
    .frame(width: 300)
}
