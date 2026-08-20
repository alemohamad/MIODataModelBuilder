//
//  DiagnosticsSheet.swift
//  MIODataModelEditor
//
//  Created by MIO Research Labs on 2026.
//

import SwiftUI

/// The full issue list. Selecting a row navigates to the offending property.
struct DiagnosticsSheet: View {
    let diagnostics: [Diagnostic]
    let selection: EditorSelection
    let onRepair: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            DiagnosticsSheetHeader(count: diagnostics.count)
            Divider()

            if diagnostics.isEmpty {
                ContentUnavailableView("No Issues", systemImage: "checkmark.circle",
                                       description: Text("This model looks consistent."))
                    .frame(maxHeight: .infinity)
            } else {
                List(diagnostics) { diagnostic in
                    DiagnosticRow(diagnostic: diagnostic)
                        .contentShape(Rectangle())
                        .onTapGesture { reveal(diagnostic) }
                }
            }

            Divider()
            DiagnosticsSheetFooter(canRepair: diagnostics.contains(where: \.kind.isRepairable),
                                   onRepair: onRepair,
                                   onDone: { dismiss() })
        }
        .frame(width: 620, height: 460)
    }

    private func reveal(_ diagnostic: Diagnostic) {
        // Selecting the entity clears the property, so set the property second.
        selection.select(entityNamed: diagnostic.entityName)
        if let property = diagnostic.propertyName {
            selection.select(propertyNamed: property, kind: diagnostic.selectionKind)
        }
        dismiss()
    }
}

extension Diagnostic {
    /// Which table the offending property lives in, so revealing it selects the
    /// right row rather than landing on nothing.
    var selectionKind: EditorSelection.PropertyKind {
        switch kind {
        case .strayDefaultValue: .attribute
        case .danglingDestination, .missingInverse: .relationship
        case .strayAbstract, .duplicateName, .duplicateClassName, .missingParentEntity: .attribute
        }
    }
}

#Preview("With issues") {
    DiagnosticsSheet(diagnostics: PreviewSamples.diagnostics,
                     selection: EditorSelection(),
                     onRepair: {})
}

#Preview("Clean") {
    DiagnosticsSheet(diagnostics: [], selection: EditorSelection(), onRepair: {})
}
