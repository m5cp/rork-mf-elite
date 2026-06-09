//
//  SessionLoggedView.swift
//  MFElite
//
//  The shared "logged" screen shown after a drill (timer-based or mental) is
//  completed: checkmark, rewards, mastery progress, and the next/finish CTA.
//  Owns all post-completion celebration handling (level mastered, certification,
//  perfect day, notification + review prompts).
//

import SwiftUI
import SwiftData
import StoreKit

struct SessionLoggedView: View {
    let context: DrillContext
    let queue: TrainingQueue
    let viewModel: DrillPlayerViewModel

    var onAdvance: () -> Void
    var onExit: () -> Void
    var onSessionComplete: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.requestReview) private var requestReview

    @State private var celebrate = false
    @State private var activeCelebration: CelebrationKind?
    @State private var chainToCert = false
    @State private var showNotificationPrompt = false
    @State private var didRecordSummary = false
    @State private var showPerfectDay = false

    private var drill: Drill { context.drill }
    private var level: MasteryLevel { context.level }
    private var category: Category { context.category }
    private var discipline: Discipline { context.discipline }

    private var isMental: Bool { drill.isMentalExercise }

    private var headerEyebrow: String {
        isMental ? "Exercise · Logged" : "Set \(drill.sets) Of \(drill.sets) · Logged"
    }

    private var subtitle: String {
        isMental ? "Logged true — the mind is a muscle." : "Logged honestly — clean run, no losses."
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if queue.source != .single {
                    routineProgressHeader
                        .padding(.top, DS.Spacing.s16)
                }

                Circle()
                    .fill(Color.white)
                    .frame(width: 100, height: 100)
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 44, weight: .bold))
                            .foregroundStyle(DS.Colors.Ground.primary)
                    )
                    .scaleEffect(celebrate ? 1 : 0)
                    .padding(.top, DS.Spacing.s64)

                Eyebrow(text: headerEyebrow)
                    .padding(.top, DS.Spacing.s24)

                Text(drill.title)
                    .style(.title1)
                    .foregroundStyle(DS.Colors.Ink.primary)
                    .multilineTextAlignment(.center)
                    .padding(.top, DS.Spacing.s8)

                Text(subtitle)
                    .style(.body)
                    .foregroundStyle(DS.Colors.Ink.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.top, DS.Spacing.s8)

                masteryCard
                    .padding(.top, DS.Spacing.s32)

                HStack(spacing: DS.Spacing.s12) {
                    rewardTile(label: "Earned", value: "+\(ProgressionRules.xpPerDrill) XP")
                    rewardTile(label: "Streak", value: "\(viewModel.newStreak) DAY", suffix: "+1")
                }
                .padding(.top, DS.Spacing.s20)

                VStack(spacing: DS.Spacing.s12) {
                    if !queue.isLastDrill, let next = queue.upNext {
                        PrimaryButton(
                            label: "Next — \(queue.position + 1) of \(queue.count)",
                            hint: next.drill.title.uppercased()
                        ) {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            onAdvance()
                        }
                        SecondaryButton(label: "End session") {
                            onExit()
                        }
                    } else {
                        PrimaryButton(label: "Finish session", hint: nil) {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            onSessionComplete()
                        }
                    }
                }
                .padding(.top, DS.Spacing.s32)
            }
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.bottom, 80)
        }
        .scrollIndicators(.hidden)
        .overlay {
            if showPerfectDay {
                PerfectDayOverlay {
                    withAnimation(DS.Motion.standardSpring) { showPerfectDay = false }
                }
                .transition(.opacity)
                .zIndex(10)
            }
        }
        .sheet(isPresented: $showNotificationPrompt) {
            NotificationPromptSheet()
                .presentationDetents([.medium, .large])
        }
        .fullScreenCover(item: $activeCelebration, onDismiss: handleCelebrationDismiss) { kind in
            switch kind {
            case .level:
                LevelMasteredView(
                    level: level,
                    category: category,
                    discipline: discipline,
                    onClose: { chainToCert = viewModel.categoryJustCertified }
                )
            case .cert:
                CertificationAwardView(
                    category: category,
                    discipline: discipline,
                    onClose: {}
                )
            }
        }
        .onAppear {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(DS.Motion.celebrationSpring) {
                celebrate = true
            }
            recordCompletedSummary()
            handleDrillLogged()
            if viewModel.perfectDayJustClosed {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(DS.Motion.standardSpring) { showPerfectDay = true }
                }
            }
            if viewModel.levelJustMastered {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    activeCelebration = .level
                }
            }
        }
    }

    /// A celebration to present over the logged screen.
    enum CelebrationKind: String, Identifiable {
        case level
        case cert
        var id: String { rawValue }
    }

    private func handleCelebrationDismiss() {
        if chainToCert {
            chainToCert = false
            activeCelebration = .cert
        } else {
            onExit()
        }
    }

    private var routineProgressHeader: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s8) {
            HStack {
                Eyebrow(text: routineEyebrow)
                    .foregroundStyle(DS.Colors.Ink.secondary)
                Spacer()
                Text("\(queue.position) of \(queue.count)")
                    .style(.micro)
                    .foregroundStyle(DS.Colors.Ink.tertiary)
            }
            HStack(spacing: 4) {
                ForEach(0..<max(1, queue.count), id: \.self) { idx in
                    Capsule()
                        .fill(idx < queue.completed.count ? Color.white : DS.Colors.Line.subtle)
                        .frame(height: 4)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var routineEyebrow: String {
        let label = queue.source == .workout ? "Workout" : "Routine"
        if let name = queue.sourceName {
            return "\(label) — \(name)"
        }
        return label
    }

    private var masteryCard: some View {
        Card {
            VStack(alignment: .leading, spacing: DS.Spacing.s12) {
                HStack {
                    Eyebrow(text: "Drill Mastery")
                    Spacer()
                    if viewModel.justMastered {
                        HStack(spacing: DS.Spacing.s4) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .bold))
                            Text("Mastered")
                                .style(.micro)
                        }
                        .foregroundStyle(DS.Colors.Ink.primary)
                    }
                }

                HStack(spacing: DS.Spacing.s4 + 2) {
                    ForEach(0..<ProgressionRules.masteryPasses, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(index < viewModel.newPassesLogged ? Color.white : DS.Colors.Line.subtle)
                            .frame(height: 6)
                            .frame(maxWidth: .infinity)
                    }
                }

                Text("\(viewModel.newPassesLogged) of \(ProgressionRules.masteryPasses) complete")
                    .style(.foot)
                    .foregroundStyle(DS.Colors.Ink.tertiary)
            }
        }
    }

    private func rewardTile(label: String, value: String, suffix: String? = nil) -> some View {
        Card {
            VStack(alignment: .leading, spacing: DS.Spacing.s8) {
                Eyebrow(text: label)
                HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.s4) {
                    Text(value)
                        .style(.num(size: 28))
                        .foregroundStyle(DS.Colors.Ink.primary)
                    if let suffix {
                        Text(suffix)
                            .style(.micro)
                            .foregroundStyle(DS.Colors.Ink.tertiary)
                    }
                }
            }
        }
    }

    private func handleDrillLogged() {
        EngagementTracker.shared.recordDrillCompleted()

        EngagementTracker.shared.evaluateNotificationPrompt { show in
            guard show else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                showNotificationPrompt = true
            }
        }

        if !viewModel.levelJustMastered {
            if viewModel.newStreak == 7,
               EngagementTracker.shared.shouldRequestReview(for: .sevenDayStreak) {
                requestReviewSoon()
            } else if masteredCount() == 10,
                      EngagementTracker.shared.shouldRequestReview(for: .tenthDrillMastered) {
                requestReviewSoon()
            }
        }
    }

    private func requestReviewSoon() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            requestReview()
        }
    }

    private func masteredCount() -> Int {
        let mastered = (try? modelContext.fetch(
            FetchDescriptor<DrillProgress>(predicate: #Predicate { $0.isMastered })
        )) ?? []
        return mastered.count
    }

    private func recordCompletedSummary() {
        guard !didRecordSummary else { return }
        didRecordSummary = true
        queue.recordCompleted(
            CompletedDrillSummary(
                title: drill.title,
                disciplineMark: discipline.mark,
                durationSec: viewModel.loggedDurationSec,
                xp: ProgressionRules.xpPerDrill
            )
        )
    }
}
