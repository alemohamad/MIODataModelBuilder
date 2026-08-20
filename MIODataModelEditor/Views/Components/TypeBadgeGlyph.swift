//
//  TypeBadgeGlyph.swift
//  MIODataModelEditor
//
//  Created by MIO Research Labs on 2026.
//

import SwiftUI

/// What sits inside a ``TypeBadge``.
///
/// Most types read best as a single letter, the way Xcode draws them. A few
/// have a symbol that says more than an initial does, so the badge takes
/// either.
enum TypeBadgeGlyph: Hashable {
    case letter(String)
    case symbol(String)
}

/// Draws a ``TypeBadgeGlyph`` in white, sized for the badge square.
struct TypeBadgeGlyphView: View {
    let glyph: TypeBadgeGlyph

    /// Symbols carry more detail than a letterform, so they need a little more
    /// room inside the same square to stay legible at this size.
    static let letterSize: CGFloat = 10
    static let symbolSize: CGFloat = 10

    var body: some View {
        switch glyph {
        case .letter(let text):
            Text(text)
                .font(.system(size: Self.letterSize, weight: .bold))
                .foregroundStyle(.white)
        case .symbol(let name):
            Image(systemName: name)
                .font(.system(size: Self.symbolSize, weight: .semibold))
                .foregroundStyle(.white)
        }
    }
}

#Preview("Letter and symbol") {
    HStack(spacing: 12) {
        ForEach([TypeBadgeGlyph.letter("S"),
                 .letter("?"),
                 .symbol("cylinder.split.1x2.fill"),
                 .symbol("barcode")], id: \.self) { glyph in
            ZStack {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Color(red: 0.42, green: 0.47, blue: 0.94))
                TypeBadgeGlyphView(glyph: glyph)
            }
            .frame(width: 16, height: 16)
        }
    }
    .padding()
}
