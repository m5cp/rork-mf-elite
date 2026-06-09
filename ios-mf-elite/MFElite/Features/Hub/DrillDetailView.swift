//
//  DrillDetailView.swift
//  MFElite
//
//  The canonical drill template — every drill renders into this structure.
//

import SwiftUI
import SwiftData

/// Navigation route carrying a drill plus its parents for breadcrumb context.
struct DrillRoute: Hashable, Identifiable {
    let discipline: Discipline
    let category: Category
    let level: MasteryLevel
    let drill: Drill

    var id: String { drill.id }
}

struct DrillDetailView: View {
    let drill: Drill
    let level: MasteryLevel
    let category: Category
    let discipline: Discipline

    @Environment(\.dismiss) private var dismiss
    @Query private var progress: [DrillProgress]
    @State private var activeSession: TrainingQueue?

    private var drillProgress: DrillProgress? {
        progress.first { $0.drillID == drill.id }
    }

    private var viewModel: DrillDetailViewModel {
        DrillDetailViewModel(
            drill: drill,
            level: level,
            category: category,
            discipline: discipline,
            passesLogged: drillProgress?.passesLogged ?? 0,
            isMastered: drillProgress?.isMastered ?? false
        )
    }

    var body: some View {
        let vm = viewModel
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                topBar
                titleBlock(vm)
                statStrip(vm)
                purposeSection
                if drill.isMentalExercise {
                    if !drill.steps.isEmpty {
                        stepsSection
                    }
                    coachingSection
                    if let prompt = drill.journalPrompt {
                        journalPromptSection(prompt)
                    }
                } else {
                    if !drill.instructions.isEmpty {
                        instructionsSection
                    }
                    coachingSection
                    challengeSection
                }
                accountabilitySection(vm)
                bottomCTA(vm)
            }
            .padding(.bottom, 120)
        }
        .background(DS.Colors.Bg.base)
        .scrollIndicators(.hidden)
        .navigationBarHidden(true)
        .fullScreenCover(item: $activeSession) { queue in
            SessionPlayerView(queue: queue)
        }
    }

    /// Builds a session queue starting at this drill, followed by the remaining
    /// drills of the same level in order (so "Next drill" always has somewhere to go).
    private func makeQueue() -> TrainingQueue {
        let ordered = level.drills.sorted { $0.sortIndex < $1.sortIndex }
        let startIndex = ordered.firstIndex { $0.id == drill.id } ?? 0
        let chain = Array(ordered[startIndex...])
        let items = chain.map {
            DrillContext(drill: $0, level: level, category: category, discipline: discipline)
        }
        return TrainingQueue(items: items, source: .single, sourceName: nil)
    }

    // MARK: - 1. Top Bar

    private var topBar: some View {
        HStack {
            IconButton(systemName: "chevron.left", size: 36) {
                dismiss()
            }
            Spacer()
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s12)
    }

    // MARK: - 2. Title Block

    private func titleBlock(_ vm: DrillDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(discipline.name) · \(category.name) · Level \(level.number)")
                .style(.micro)
                .foregroundStyle(DS.Colors.Ink.tertiary)

            Text(drill.title)
                .style(.title1)
                .foregroundStyle(DS.Colors.Ink.primary)
                .padding(.top, DS.Spacing.s8)

            Text(vm.drillCode)
                .style(.micro)
                .foregroundStyle(DS.Colors.Ink.quaternary)
                .padding(.top, DS.Spacing.s4 + 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s20)
    }

    private var setDurationLabel: String {
        let totalSec = drill.durationSec
        let sets = max(1, drill.sets)
        let perSet = totalSec / sets
        let minutes = perSet / 60
        let seconds = perSet % 60
        if seconds == 0 {
            return "\(minutes):00"
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    // MARK: - 3. Stat Strip

    private func statStrip(_ vm: DrillDetailViewModel) -> some View {
        VStack(spacing: 0) {
            Hairline()
            HStack(spacing: 0) {
                if drill.isMentalExercise {
                    statCell(value: "~\(vm.formattedDuration)", label: "Guide")
                    statDivider
                    statCell(value: "\(max(drill.steps.count, 1))", label: "Steps")
                    statDivider
                    statCell(value: kindLabel, label: "Type")
                } else {
                    statCell(value: vm.formattedDuration, label: "Duration")
                    statDivider
                    statCell(value: "\(drill.sets) × \(setDurationLabel)", label: "Sets")
                    statDivider
                    statCell(value: "+\(ProgressionRules.xpPerDrill) XP", label: "Earns")
                }
            }
            Hairline()
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s20)
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: DS.Spacing.s4) {
            Text(value)
                .font(DS.Typography.num(size: 18))
                .tracking(-0.6)
                .foregroundStyle(DS.Colors.Ink.primary)
            Eyebrow(text: label)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.s16 - 2)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(DS.Colors.Line.hairline)
            .frame(width: 1, height: 40)
    }

    // MARK: - 4. Section 01 — Purpose

    private var purposeSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: "PURPOSE")
            Text(drill.how)
                .style(.body)
                .foregroundStyle(DS.Colors.Ink.secondary)
                .padding(.top, DS.Spacing.s12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s24 + 4)
    }

    // MARK: - Instructions

    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: "HOW TO DO IT")

            VStack(alignment: .leading, spacing: DS.Spacing.s16) {
                ForEach(Array(drill.instructions.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: DS.Spacing.s12) {
                        Text("\(index + 1)")
                            .font(DS.Typography.num(size: 16))
                            .foregroundStyle(DS.Colors.Ink.primary)
                            .frame(width: 28, height: 28)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Circle())

                        Text(step)
                            .style(.body)
                            .foregroundStyle(DS.Colors.Ink.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(.top, DS.Spacing.s16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s24 + 4)
    }

    private var kindLabel: String {
        (MentalExerciseKind(rawValue: drill.exerciseKind ?? "") ?? .guided).label
    }

    // MARK: - Mental: Steps

    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: "THE EXERCISE")

            VStack(alignment: .leading, spacing: DS.Spacing.s16) {
                ForEach(Array(drill.steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: DS.Spacing.s12) {
                        Text("\(index + 1)")
                            .font(DS.Typography.num(size: 16))
                            .foregroundStyle(DS.Colors.Ink.primary)
                            .frame(width: 28, height: 28)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Circle())

                        Text(step)
                            .style(.body)
                            .foregroundStyle(DS.Colors.Ink.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(.top, DS.Spacing.s16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s24 + 4)
    }

    // MARK: - Mental: Journal Prompt

    private func journalPromptSection(_ prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: "REFLECT")

            HStack(alignment: .top, spacing: DS.Spacing.s12) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(DS.Colors.Ink.primary)
                Text(prompt)
                    .style(.callout)
                    .foregroundStyle(DS.Colors.Ink.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(DS.Spacing.s20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DS.Colors.Bg.elevated)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
            .padding(.top, DS.Spacing.s12 + 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s24 + 4)
    }

    // MARK: - 5. Section 02 — Coaching Points

    private var coachingSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: "COACHING POINTS")

            VStack(alignment: .leading, spacing: DS.Spacing.s12) {
                ForEach(Array(drill.coachingPoints.enumerated()), id: \.offset) { index, point in
                    HStack(alignment: .top, spacing: DS.Spacing.s12) {
                        Text("\(index + 1)")
                            .style(.foot)
                            .fontWeight(.bold)
                            .foregroundStyle(DS.Colors.Ink.primary)
                            .frame(width: 24, height: 24)
                            .background(DS.Colors.Bg.raised)
                            .clipShape(Circle())

                        Text(point)
                            .style(.callout)
                            .foregroundStyle(DS.Colors.Ink.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(.top, DS.Spacing.s16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s24 + 4)
    }

    // MARK: - 6. Section 03 — The Challenge

    private var challengeSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: "THE CHALLENGE")

            VStack(alignment: .leading, spacing: 0) {
                Text(drill.focus)
                    .style(.title2)
                    .foregroundStyle(DS.Colors.Ground.primary)

                HStack(spacing: DS.Spacing.s8) {
                    challengeTag("\(drill.sets) Sets")
                    challengeTag("\(setDurationLabel) Each")
                    challengeTag("No Loss")
                }
                .padding(.top, DS.Spacing.s12 - 2)
            }
            .padding(DS.Spacing.s24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
            .padding(.top, DS.Spacing.s12 + 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s24 + 4)
    }

    private func challengeTag(_ text: String) -> some View {
        Text(text)
            .style(.foot)
            .foregroundStyle(DS.Colors.Ground.primary)
            .padding(.vertical, 6)
            .padding(.horizontal, DS.Spacing.s12)
            .background(Color.black.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.pill))
    }

    // MARK: - 7. Section 04 — Accountability

    private func accountabilitySection(_ vm: DrillDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: "ACCOUNTABILITY")

            Card {
                VStack(alignment: .leading, spacing: DS.Spacing.s12) {
                    Eyebrow(text: "\(ProgressionRules.masteryPasses) Honest Passes")

                    masteryTrack(passes: vm.passesLogged)

                    Text("\(vm.passesLogged) of \(ProgressionRules.masteryPasses) logged")
                        .style(.foot)
                        .foregroundStyle(DS.Colors.Ink.tertiary)

                    Text("Log each clean run yourself — the work is yours. No video. No proof. Just your word.")
                        .style(.body)
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                }
            }
            .padding(.top, DS.Spacing.s12 + 2)

            honorCode
                .padding(.top, DS.Spacing.s16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s24 + 4)
    }

    private func masteryTrack(passes: Int) -> some View {
        HStack(spacing: DS.Spacing.s4 + 2) {
            ForEach(0..<ProgressionRules.masteryPasses, id: \.self) { index in
                RoundedRectangle(cornerRadius: 3)
                    .fill(index < passes ? Color.white : DS.Colors.Line.subtle)
                    .frame(height: 6)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var honorCode: some View {
        HStack(spacing: DS.Spacing.s12) {
            Image(systemName: "checkmark.shield")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(DS.Colors.Ink.primary)

            VStack(alignment: .leading, spacing: DS.Spacing.s4) {
                Text("The honor code")
                    .style(.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(DS.Colors.Ink.primary)
                Text("Only you know if it was your best · Log it true")
                    .style(.micro)
                    .foregroundStyle(DS.Colors.Ink.tertiary)
            }
        }
    }

    // MARK: - 8. Bottom CTA

    private func bottomCTA(_ vm: DrillDetailViewModel) -> some View {
        HStack(spacing: DS.Spacing.s12) {
            PrimaryButton(
                label: drill.isMentalExercise ? "Begin exercise" : "Start drill",
                hint: vm.drill.durationSec.minutesHint
            ) {
                activeSession = makeQueue()
            }
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s32)
        .padding(.bottom, DS.Spacing.s48)
    }
}
