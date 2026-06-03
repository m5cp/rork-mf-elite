//
//  CoachDrillEditorView.swift
//  MFElite
//
//  Add or edit a drill under a level, writing through to Supabase. Presented as
//  a sheet from the Coach Workspace content tree.
//

import SwiftUI

struct CoachDrillEditorView: View {
    /// The level this drill belongs to.
    let levelID: String
    /// Existing drill being edited, or nil when adding a new one.
    let existing: Drill?
    /// Suggested sort index for a new drill (count of drills already in the level).
    var defaultSortIndex: Int = 0
    /// Called after a successful save so the host can show a toast / refresh.
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var focus: String
    @State private var how: String
    @State private var durationText: String
    @State private var setsText: String
    @State private var coachingPoints: [String]
    @State private var isSaving = false
    @State private var errorMessage: String?

    @FocusState private var isFocused: Bool

    init(levelID: String, existing: Drill?, defaultSortIndex: Int = 0, onSaved: @escaping () -> Void) {
        self.levelID = levelID
        self.existing = existing
        self.defaultSortIndex = defaultSortIndex
        self.onSaved = onSaved
        _title = State(initialValue: existing?.title ?? "")
        _focus = State(initialValue: existing?.focus ?? "")
        _how = State(initialValue: existing?.how ?? "")
        _durationText = State(initialValue: String(existing?.durationSec ?? 300))
        _setsText = State(initialValue: String(existing?.sets ?? 3))
        _coachingPoints = State(initialValue: existing?.coachingPoints.isEmpty == false ? existing!.coachingPoints : [""])
    }

    private var isEditing: Bool { existing != nil }
    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && !isSaving
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.s20) {
                    field(label: "Title", text: $title, placeholder: "First touch under pressure")
                    field(label: "Focus", text: $focus, placeholder: "Receiving on the half-turn")
                    multilineField(label: "Instructions", text: $how, placeholder: "How the drill is run…")

                    HStack(spacing: DS.Spacing.s12) {
                        numberField(label: "Duration (sec)", text: $durationText)
                        numberField(label: "Sets", text: $setsText)
                    }

                    coachingPointsSection

                    if let errorMessage {
                        Text(errorMessage)
                            .style(.foot)
                            .foregroundStyle(DS.Colors.Ink.secondary)
                    }
                }
                .padding(DS.Spacing.s20)
            }
            .background(DS.Colors.Bg.base)
            .scrollIndicators(.hidden)
            .navigationTitle(isEditing ? "Edit drill" : "Add drill")
            .navigationBarTitleDisplayMode(.inline)
            .keyboardDoneButton { isFocused = false }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .tint(DS.Colors.Ink.tertiary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving…" : "Save") { Task { await save() } }
                        .tint(DS.Colors.Ink.primary)
                        .disabled(!canSave)
                }
            }
        }
    }

    // MARK: - Coaching points

    private var coachingPointsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s8) {
            Eyebrow(text: "Coaching points")
            ForEach(coachingPoints.indices, id: \.self) { index in
                HStack(spacing: DS.Spacing.s8) {
                    TextField("Coaching point", text: Binding(
                        get: { index < coachingPoints.count ? coachingPoints[index] : "" },
                        set: { if index < coachingPoints.count { coachingPoints[index] = $0 } }
                    ))
                    .style(.callout)
                    .foregroundStyle(DS.Colors.Ink.primary)
                    .focused($isFocused)
                    .submitLabel(.done)
                    .padding(.vertical, DS.Spacing.s12)
                    .padding(.horizontal, DS.Spacing.s16)
                    .background(DS.Colors.Bg.elevated)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))

                    Button {
                        coachingPoints.remove(at: index)
                        if coachingPoints.isEmpty { coachingPoints = [""] }
                    } label: {
                        Image(systemName: "minus.circle")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(DS.Colors.Ink.tertiary)
                    }
                    .buttonStyle(PressableButtonStyle())
                    .accessibilityLabel("Remove coaching point")
                }
            }

            Button {
                coachingPoints.append("")
            } label: {
                HStack(spacing: DS.Spacing.s4 + 2) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                    Text("Add point")
                        .style(.foot)
                }
                .foregroundStyle(DS.Colors.Ink.primary)
            }
            .buttonStyle(PressableButtonStyle())
        }
    }

    // MARK: - Field builders

    private func field(label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s8) {
            Eyebrow(text: label)
            TextField(placeholder, text: text)
                .style(.callout)
                .foregroundStyle(DS.Colors.Ink.primary)
                .focused($isFocused)
                .submitLabel(.done)
                .padding(.vertical, DS.Spacing.s12)
                .padding(.horizontal, DS.Spacing.s16)
                .background(DS.Colors.Bg.elevated)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
        }
    }

    private func multilineField(label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s8) {
            Eyebrow(text: label)
            TextField(placeholder, text: text, axis: .vertical)
                .lineLimit(3...8)
                .style(.callout)
                .foregroundStyle(DS.Colors.Ink.primary)
                .focused($isFocused)
                .padding(.vertical, DS.Spacing.s12)
                .padding(.horizontal, DS.Spacing.s16)
                .background(DS.Colors.Bg.elevated)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
        }
    }

    private func numberField(label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s8) {
            Eyebrow(text: label)
            TextField("0", text: text)
                .keyboardType(.numberPad)
                .font(DS.Typography.num(size: 18))
                .foregroundStyle(DS.Colors.Ink.primary)
                .focused($isFocused)
                .padding(.vertical, DS.Spacing.s12)
                .padding(.horizontal, DS.Spacing.s16)
                .background(DS.Colors.Bg.elevated)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Save

    private func save() async {
        isFocused = false
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        let cleanedPoints = coachingPoints
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let insert = SupabaseDrillInsert(
            levelId: levelID,
            title: title.trimmingCharacters(in: .whitespaces),
            focus: focus.trimmingCharacters(in: .whitespaces),
            how: how.trimmingCharacters(in: .whitespaces),
            videoUrl: existing?.videoURL,
            durationSec: max(0, Int(durationText) ?? 300),
            sets: max(1, Int(setsText) ?? 3),
            coachingPoints: cleanedPoints,
            sortIndex: existing?.sortIndex ?? defaultSortIndex
        )

        do {
            if let existing {
                try await CoachContentService.shared.updateDrill(id: existing.id, drill: insert)
            } else {
                try await CoachContentService.shared.addDrill(to: levelID, drill: insert)
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            onSaved()
            dismiss()
        } catch {
            errorMessage = "Couldn't save. Check your connection and try again."
        }
    }
}
