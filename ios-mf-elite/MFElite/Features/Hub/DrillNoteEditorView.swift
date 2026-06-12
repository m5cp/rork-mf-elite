//
//  DrillNoteEditorView.swift
//  MFElite
//
//  A small sheet to write or edit a private, local-only note for a single drill.
//  Saving empty text deletes the note (handled by the caller).
//

import SwiftUI

struct DrillNoteEditorView: View {
    /// The note text currently saved (empty when adding a new note).
    let existing: String
    /// Called with the new text when the player taps Save.
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    @FocusState private var isFocused: Bool

    private let charLimit = 300

    init(existing: String, onSave: @escaping (String) -> Void) {
        self.existing = existing
        self.onSave = onSave
        _text = State(initialValue: existing)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: DS.Spacing.s12) {
                TextField(
                    "What clicked? What to work on next time?",
                    text: $text,
                    axis: .vertical
                )
                .style(.body)
                .foregroundStyle(DS.Colors.Ink.primary)
                .lineLimit(6...12)
                .focused($isFocused)
                .padding(DS.Spacing.s16)
                .background(DS.Colors.Bg.elevated)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                .overlay(RoundedRectangle(cornerRadius: DS.Radius.lg).stroke(DS.Colors.Line.hairline, lineWidth: 1))
                .onChange(of: text) { _, newValue in
                    if newValue.count > charLimit {
                        text = String(newValue.prefix(charLimit))
                    }
                }

                Text("\(text.count)/\(charLimit)")
                    .style(.micro)
                    .foregroundStyle(DS.Colors.Ink.tertiary)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                Spacer()
            }
            .padding(DS.Spacing.s20)
            .background(DS.Colors.Bg.base)
            .navigationTitle("My note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(DS.Colors.Ink.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(text)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(DS.Colors.Ink.primary)
                }
            }
            .onAppear { isFocused = true }
        }
        .preferredColorScheme(.dark)
    }
}
