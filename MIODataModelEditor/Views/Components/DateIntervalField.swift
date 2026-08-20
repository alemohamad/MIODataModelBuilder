//
//  DateIntervalField.swift
//  MIODataModelEditor
//
//  Created by MIO Research Labs on 2026.
//
//  A Date attribute's default and bounds are stored as seconds since Core
//  Data's reference date, 2001-01-01 UTC. Typed as a raw number they are
//  unreadable: two values in the models here read -725850000 and -725882400,
//  which are the same calendar day nine hours apart, and nothing in a text
//  field makes that visible.
//
//  So: a picker for choosing, and the raw interval shown underneath for
//  checking. The interval is the part that matters when somebody assumes Unix
//  time, where 0 would be 1970 rather than 2001.
//

import SwiftUI

struct DateIntervalField: View {
    @Binding var date: Date?

    /// What the file holds, shown verbatim. Not derived from `date`, so a
    /// value this editor cannot parse is still visible.
    let raw: String?

    var prompt: String = "No Value"

    var body: some View {
        // The whole field yields horizontally. Nothing in here should be the
        // reason the inspector cannot be 340pt wide.
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                if date == nil {
                    Text(prompt)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Button("Set") { date = Date() }
                        .buttonStyle(.link)
                } else {
                    // .field, not the default stepper field: the steppers add
                    // width this column does not have. The inspector is 340pt
                    // wide and the label eats a third of it, so a picker that
                    // asks for more makes the split view's width constraint
                    // unsatisfiable and AppKit starts breaking constraints.
                    DatePicker("", selection: chosen, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.field)
                        .labelsHidden()
                    Button {
                        date = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("Clear the value")
                }
            }

            if let raw, raw.isEmpty == false {
                // Wraps rather than demanding width. The full sentence is in
                // the tooltip, where it costs no layout.
                Text("\(raw) s")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .help("\(raw) seconds since 2001-01-01 UTC, Core Data's reference date. Not the Unix epoch: 0 here is 2001, and -978307200 is 1970.")
            }
        }
    }

    /// DatePicker needs a value. Editing one that was absent starts from now,
    /// which is what the Set button already committed.
    private var chosen: Binding<Date> {
        Binding(get: { date ?? Date() },
                set: { date = $0 })
    }
}

#Preview("Set") {
    @Previewable @State var date: Date? = Date(timeIntervalSinceReferenceDate: -725850000)

    Form {
        LabeledContent("Default") {
            DateIntervalField(date: $date, raw: "-725850000", prompt: "No Default Value")
        }
    }
    .formStyle(.grouped)
    .frame(width: 340)
}

#Preview("Empty") {
    @Previewable @State var date: Date? = nil

    Form {
        LabeledContent("Default") {
            DateIntervalField(date: $date, raw: nil, prompt: "No Default Value")
        }
    }
    .formStyle(.grouped)
    .frame(width: 340)
}
