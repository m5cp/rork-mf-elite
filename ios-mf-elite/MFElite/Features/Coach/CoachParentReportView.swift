//
//  CoachParentReportView.swift
//  MFElite
//
//  Author the monthly coach note that appears on the parent report.
//

import SwiftUI

struct CoachParentReportView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var note = ""
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var savedConfirmation = false
    @State private var errorMessage: String?
    @FocusState private var isFocused: Bool

    private let month = CoachContentService.currentMonthKey()

    private var monthLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM"
        guard let date = formatter.date(from: month) else { return month }
        let out = DateFormatter()
        out.dateFormat = "MMMM yyyy"
        return out.string(from: date)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.s16) {
                    Eyebrow(text: "Covers · \(monthLabel)")

                    if isLoading {
                        ProgressView().tint(DS.Colors.Ink.primary).frame(maxWidth: .infinity)
                    } else {
                        TextField("Write this month's note to parents…", text: $note, axis: .vertical)
                            .lineLimit(8...20)
                            .style(.body)
                            .foregroundStyle(DS.Colors.Ink.primary)
                            .focused($isFocused)
                            .padding(DS.Spacing.s16)
                            .background(DS.Colors.Bg.elevated)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))

                        PrimaryButton(label: isSaving ? "Saving…" : "Save note") { Task { await save() } }
                            .disabled(isSaving)

                        if savedConfirmation {
                            Text("Note saved.")
                                .style(.foot)
                                .foregroundStyle(DS.Colors.Ink.tertiary)
                        }
                        if let errorMessage {
                            Text(errorMessage).style(.foot).foregroundStyle(DS.Colors.Ink.secondary)
                        }
                    }
                }
                .padding(DS.Spacing.s20)
            }
            .background(DS.Colors.Bg.base)
            .scrollIndicators(.hidden)
            .navigationTitle("Player Report")
            .navigationBarTitleDisplayMode(.inline)
            .keyboardDoneButton { isFocused = false }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .tint(DS.Colors.Ink.primary)
                }
            }
            .task { await load() }
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            note = try await CoachContentService.shared.fetchCoachNote(month: month)?.body ?? ""
        } catch {
            errorMessage = "Couldn't load the note."
        }
    }

    private func save() async {
        isFocused = false
        isSaving = true
        errorMessage = nil
        savedConfirmation = false
        defer { isSaving = false }
        do {
            try await CoachContentService.shared.saveCoachNote(month: month, body: note.trimmingCharacters(in: .whitespacesAndNewlines))
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            savedConfirmation = true
        } catch {
            errorMessage = "Couldn't save. Check your connection and try again."
        }
    }
}
