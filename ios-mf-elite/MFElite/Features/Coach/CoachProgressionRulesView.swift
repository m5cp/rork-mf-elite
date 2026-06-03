//
//  CoachProgressionRulesView.swift
//  MFElite
//
//  Edit the XP rewards and free/paid gating, syncing to Supabase. Changes take
//  effect for all players on their next sync.
//

import SwiftUI

struct CoachProgressionRulesView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var xpPerDrill = String(ProgressionRules.xpPerDrill)
    @State private var xpLevelBonus = String(ProgressionRules.xpLevelBonus)
    @State private var xpCategoryCert = String(ProgressionRules.xpCategoryCert)
    @State private var xpDisciplineDiploma = String(ProgressionRules.xpDisciplineDiploma)
    @State private var freeLevels = String(ProgressionRules.freeLevels)
    @State private var masteryPasses = String(ProgressionRules.masteryPasses)

    @State private var rulesID: String?
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String?
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.s12) {
                    if isLoading {
                        ProgressView().tint(DS.Colors.Ink.primary).frame(maxWidth: .infinity)
                    } else {
                        ruleEditor("XP per drill", $xpPerDrill)
                        ruleEditor("Level bonus", $xpLevelBonus)
                        ruleEditor("Certification bonus", $xpCategoryCert)
                        ruleEditor("Discipline diploma", $xpDisciplineDiploma)
                        ruleEditor("Mastery passes", $masteryPasses)
                        ruleEditor("Free tier levels", $freeLevels)

                        Text("Free tier levels controls how many levels free players can access. Changes take effect for all players on their next sync.")
                            .style(.foot)
                            .foregroundStyle(DS.Colors.Ink.tertiary)
                            .padding(.top, DS.Spacing.s4)

                        PrimaryButton(label: isSaving ? "Saving…" : "Save rules") { Task { await save() } }
                            .disabled(isSaving || rulesID == nil)
                            .padding(.top, DS.Spacing.s8)

                        if rulesID == nil {
                            Text("No rules row found on the server yet.")
                                .style(.foot)
                                .foregroundStyle(DS.Colors.Ink.secondary)
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
            .navigationTitle("Progression Rules")
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

    private func ruleEditor(_ label: String, _ value: Binding<String>) -> some View {
        HStack {
            Text(label)
                .style(.callout)
                .foregroundStyle(DS.Colors.Ink.primary)
            Spacer()
            TextField("0", text: value)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .font(DS.Typography.num(size: 18))
                .foregroundStyle(DS.Colors.Ink.primary)
                .focused($isFocused)
                .frame(width: 80)
        }
        .padding(.vertical, DS.Spacing.s12)
        .padding(.horizontal, DS.Spacing.s16)
        .background(DS.Colors.Bg.elevated)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        if let rules = await CurriculumSyncService.shared.syncProgressionRules() {
            rulesID = rules.id
            xpPerDrill = String(rules.xpPerDrill)
            xpLevelBonus = String(rules.xpLevelBonus)
            xpCategoryCert = String(rules.xpCategoryCert)
            xpDisciplineDiploma = String(rules.xpDisciplineDiploma)
            freeLevels = String(rules.freeLevels)
            masteryPasses = String(rules.masteryPasses)
        }
    }

    private func save() async {
        guard let id = rulesID else { return }
        isFocused = false
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        let update = SupabaseProgressionRulesUpdate(
            xpPerDrill: max(0, Int(xpPerDrill) ?? ProgressionRules.xpPerDrill),
            xpLevelBonus: max(0, Int(xpLevelBonus) ?? ProgressionRules.xpLevelBonus),
            xpCategoryCert: max(0, Int(xpCategoryCert) ?? ProgressionRules.xpCategoryCert),
            xpDisciplineDiploma: max(0, Int(xpDisciplineDiploma) ?? ProgressionRules.xpDisciplineDiploma),
            freeLevels: max(1, Int(freeLevels) ?? ProgressionRules.freeLevels),
            masteryPasses: max(1, Int(masteryPasses) ?? ProgressionRules.masteryPasses)
        )

        do {
            try await CoachContentService.shared.updateProgressionRules(update, id: id)
            // Reflect immediately in the local store so gating updates without waiting for sync.
            ProgressionRules.apply(
                xpPerDrill: update.xpPerDrill,
                xpLevelBonus: update.xpLevelBonus,
                xpCategoryCert: update.xpCategoryCert,
                xpDisciplineDiploma: update.xpDisciplineDiploma,
                freeLevels: update.freeLevels,
                masteryPasses: update.masteryPasses
            )
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            dismiss()
        } catch {
            errorMessage = "Couldn't save. Check your connection and try again."
        }
    }
}
