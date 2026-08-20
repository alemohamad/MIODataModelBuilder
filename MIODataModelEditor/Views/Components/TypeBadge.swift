//
//  TypeBadge.swift
//  MIODataModelEditor
//
//  Created by MIO Research Labs on 2026.
//

import SwiftUI

/// The small rounded glyph Xcode puts in front of every entity and property.
struct TypeBadge: View {
    enum Style {
        case attribute(AttributeType)
        case relationship(toMany: Bool)
        case entity
        case fetchedProperty
        case configuration
    }

    let style: Style

    private static let size: CGFloat = 16

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(tint)
            TypeBadgeGlyphView(glyph: glyph)
        }
        .frame(width: Self.size, height: Self.size)
        .accessibilityLabel(accessibilityLabel)
    }

    private var glyph: TypeBadgeGlyph {
        switch style {
        case .entity: .letter("E")
        case .fetchedProperty: .letter("F")
        case .configuration: .letter("C")
        case .relationship(let toMany): .letter(toMany ? "M" : "O")
        case .attribute(let type):
            switch type {
            case .string: .letter("S")
            case .boolean: .letter("B")
            case .date: .letter("D")
            case .uri: .letter("U")
            case .transformable, .composite: .letter("T")
            case .undefined: .letter("?")
            case .binary: .symbol("cylinder.split.1x2.fill")
            case .uuid: .symbol("barcode")
            default: .letter("N")
            }
        }
    }

    private var tint: Color {
        switch style {
        case .entity, .configuration: .accentColor
        case .fetchedProperty: .purple
        case .relationship: .red
        case .attribute: Color(red: 0.42, green: 0.47, blue: 0.94)
        }
    }

    private var accessibilityLabel: String {
        switch style {
        case .entity: "Entity"
        case .fetchedProperty: "Fetched property"
        case .configuration: "Configuration"
        case .relationship(let toMany): toMany ? "To-many relationship" : "To-one relationship"
        case .attribute(let type): type.displayName
        }
    }
}

#Preview("Every badge") {
    Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 6) {
        GridRow {
            TypeBadge(style: .entity)
            Text("Entity")
        }
        GridRow {
            TypeBadge(style: .relationship(toMany: false))
            Text("Relationship, to one")
        }
        GridRow {
            TypeBadge(style: .relationship(toMany: true))
            Text("Relationship, to many")
        }
        GridRow {
            TypeBadge(style: .fetchedProperty)
            Text("Fetched property")
        }
        GridRow {
            TypeBadge(style: .configuration)
            Text("Configuration")
        }
        Divider().gridCellUnsizedAxes(.horizontal)
        ForEach(AttributeType.allCases) { type in
            GridRow {
                TypeBadge(style: .attribute(type))
                Text(type.displayName)
            }
        }
    }
    .padding()
}

#Preview("In a row, at real size") {
    VStack(alignment: .leading, spacing: 0) {
        ForEach([AttributeType.binary, .uuid, .string, .date, .decimal], id: \.self) { type in
            PropertyRow(isSelected: type == .binary, onSelect: {}) {
                TypeBadge(style: .attribute(type))
                Text("attribute").frame(width: 200, alignment: .leading)
                Text(type.displayName).foregroundStyle(.secondary)
            }
        }
    }
    .padding()
    .frame(width: 420)
}
