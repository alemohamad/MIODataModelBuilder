//
//  DiagnosticRow.swift
//  MIODataModelEditor
//
//  Created by MIO Research Labs on 2026.
//

import SwiftUI

/// One line of the issue list.
struct DiagnosticRow: View {
    let diagnostic: Diagnostic

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: diagnostic.severity.symbolName)
                .foregroundStyle(diagnostic.severity.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(diagnostic.location).font(.callout.weight(.medium))
                Text(diagnostic.message).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

extension Diagnostic.Severity {
    var symbolName: String {
        switch self {
        case .error: "xmark.octagon.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .info: "info.circle"
        }
    }

    var tint: Color {
        switch self {
        case .error: .red
        case .warning: .orange
        case .info: .secondary
        }
    }
}

#Preview("Every severity") {
    List {
        DiagnosticRow(diagnostic: Diagnostic(kind: .duplicateName, severity: .error,
                                             entityName: "Employee", propertyName: "name",
                                             message: "Duplicate property name."))
        DiagnosticRow(diagnostic: Diagnostic(kind: .strayDefaultValue, severity: .warning,
                                             entityName: "Task", propertyName: "isDone",
                                             message: "Default is written as defaultValue=\"NO\". Core Data reads defaultValueString and ignores this, so the attribute has no default."))
        DiagnosticRow(diagnostic: Diagnostic(kind: .missingInverse, severity: .info,
                                             entityName: "Employee", propertyName: "manager",
                                             message: "No inverse relationship. Core Data can behave unpredictably without one."))
    }
    .frame(width: 560, height: 220)
}
