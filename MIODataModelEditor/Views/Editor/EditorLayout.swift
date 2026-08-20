//
//  EditorLayout.swift
//  MIODataModelEditor
//
//  Created by MIO Research Labs on 2026.
//

import SwiftUI

/// The window and column sizes of the editor.
///
/// The detail minimum is derived from the row widths rather than typed in, so
/// widening a column cannot leave the window able to shrink below the table it
/// has to show. Getting that wrong does not truncate text, it clips it: a
/// window narrower than its content's minimum lays the content out at the
/// minimum and cuts off both edges.
enum EditorLayout {
    static let sidebarMinWidth: CGFloat = 200
    static let sidebarIdealWidth: CGFloat = 260

    static let inspectorMinWidth: CGFloat = 300
    static let inspectorIdealWidth: CGFloat = 340
    static let inspectorMaxWidth: CGFloat = 460

    /// Relationships is the widest of the three tables.
    static let detailMinWidth: CGFloat =
        RelationshipRow.nameWidth + RelationshipRow.popupWidth * 2

    /// What the window floor works out to, for reference only.
    static var windowMinWidth: CGFloat { sidebarMinWidth + detailMinWidth + inspectorMaxWidth }

    static let windowMinHeight: CGFloat = 560

    static let windowDefaultWidth: CGFloat = sidebarIdealWidth + detailMinWidth + 160 + inspectorIdealWidth
    static let windowDefaultHeight: CGFloat = 760
}
