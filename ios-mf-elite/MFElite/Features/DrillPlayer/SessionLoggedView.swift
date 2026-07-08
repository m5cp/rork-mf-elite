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
    @Query private var allProgress: [DrillProgress]
    @Query(sort: \GameIQLesson.sortIndex) private var gameIQLessons: [GameIQLesson]

    @State private var activeLesson: GameIQLesson?

    @State private var nextSession: TrainingQueue?
    @State private var celebrate = false
    @State private var activeCelebration: CelebrationKind?
    @State private var chainToCert = false
    @State private var showNotificationPrompt = false
    @State private var didRecordSummary = false
    @State private var showPerfectDay = false

    /// Seconds left before auto-advancing to the next drill, or `nil` when not
    /// counting down (toggle off, last drill, single drill, or cancelled by a tap).
    @State private var autoAdvanceCountdown: Int?
    @State private var autoAdvanceTimer: Timer?
    @AppStorage("MF_AUTO_ADVANCE") private var autoAdvanceEnabled = true

    private var drill: Drill { context.drill }
    private var level: MasteryLevel { context.level }
    private var category: Category { context.category }
    private var discipline: Discipline { context.discipline }

    private var isMental: Bool { drill.isMentalExercise }

    /// Next not-yet-mastered drill in this discipline, excluding the one just
    /// logged. Mirrors the Today tab's goal traversal: categories sorted by
    /// sortIndex → levels by number → drills by sortIndex, first unmastered.
    /// Only offered after a single-drill session (routines/workouts auto-advance).
    private var upNext: DrillContext? {
        guard queue.source == .single else { return nil }
        let mastered = Set(allProgress.filter { $0.isMastered }.map { $0.drillID })
        for category in discipline.categories.sorted(by: { $0.sortIndex < $1.sortIndex }) {
            for level in category.levels.sorted(by: { $0.number < $1.number }) {
                let drills = level.drills.sorted { $0.sortIndex < $1.sortIndex }
                if let next = drills.first(where: { !mastered.contains($0.id) && $0.id != drill.id }) {
                    return DrillContext(drill: next, level: level, category: category, discipline: discipline)
                }
            }
        }
        return nil
    }

    /// After a single TACTICAL drill, the uncompleted Game IQ lesson that deepens
    /// the drill's category, surfaced instead of the next-drill suggestion.
    private var upNextLesson: GameIQLesson? {
        guard queue.source == .single else { return nil }
        guard discipline.name == "Tactical" || discipline.id == "d-tact" else { return nil }
        return gameIQLessons.first { $0.relatedCategoryID == category.id && !$0.isCompleted }
    }

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
                            label: autoAdvanceCountdown.map { "Next in \($0)\u{2009}s" } ?? "Next — \(queue.position + 1) of \(queue.count)",
                            hint: next.drill.title.uppercased()
                        ) {
                            cancelAutoAdvance()
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            onAdvance()
                        }
                        SecondaryButton(label: "End session") {
                            cancelAutoAdvance()
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

                VStack(spacing: DS.Spacing.s8) {
                    SyncStatusChip()
                    Text("Logged on your device — backs up automatically when you're online.")
                        .style(.micro)
                        .foregroundStyle(DS.Colors.Ink.quaternary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, DS.Spacing.s20)

                if let lesson = upNextLesson {
                    gameIQUpNextCard(lesson)
                        .padding(.top, DS.Spacing.s32)
                } else if let upNext {
                    upNextCard(upNext)
                        .padding(.top, DS.Spacing.s32)
                }
            }
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.bottom, 80)
        }
        .scrollIndicators(.hidden)
        // Any tap anywhere on the logged screen cancels the auto-advance so the
        // player can read their stats without being rushed. Buttons still fire.
        .simultaneousGesture(
            TapGesture().onEnded {
                if autoAdvanceCountdown != nil { cancelAutoAdvance() }
            }
        )
        .overlay {
            if showPerfectDay {
                PerfectDayOverlay {
                    withAnimation(DS.Motion.standardSpring) { showPerfectDay = false }
                }
                .transition(.opacity)
                .zIndex(10)
            }
        }
        .fullScreenCover(item: $nextSession) { queue in
            SessionPlayerView(queue: queue)
        }
        .fullScreenCover(item: $activeLesson) { lesson in
            GameIQLessonView(lesson: lesson) { activeLesson = nil }
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
            case .streak(let days):
                StreakMilestoneView(days: days, onClose: {})
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
                // The overlay fires its own success haptic on appear.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(DS.Motion.standardSpring) { showPerfectDay = true }
                }
            }
            if viewModel.levelJustMastered {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    activeCelebration = .level
                }
            }
            startAutoAdvanceIfNeeded()
        }
        .onDisappear { cancelAutoAdvance() }
    }

    // MARK: - Auto-advance

    /// Eligible only inside a routine/workout, when there's a next drill, the
    /// toggle is on, and no full-screen celebration is taking over the screen.
    private var canAutoAdvance: Bool {
        autoAdvanceEnabled
        && queue.isChained
        && !queue.isLastDrill
        && queue.upNext != nil
        && !viewModel.levelJustMastered
        && !viewModel.categoryJustCertified
        && !viewModel.perfectDayJustClosed
    }

    private func startAutoAdvanceIfNeeded() {
        guard canAutoAdvance else { return }
        autoAdvanceCountdown = 6
        let timer = Timer(timeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                guard let current = autoAdvanceCountdown else { return }
                if current <= 1 {
                    cancelAutoAdvance()
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onAdvance()
                } else {
                    autoAdvanceCountdown = current - 1
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        autoAdvanceTimer = timer
    }

    private func cancelAutoAdvance() {
        autoAdvanceTimer?.invalidate()
        autoAdvanceTimer = nil
        autoAdvanceCountdown = nil
    }

    /// A celebration to present over the logged screen.
    enum CelebrationKind: Identifiable {
        case level
        case cert
        case streak(Int)

        var id: String {
            switch self {
            case .level: return "level"
            case .cert: return "cert"
            case .streak(let days): return "streak-\(days)"
            }
        }
    }

    /// Celebrations never stack: level first, then certification, then a streak
    /// milestone — each presented only after the previous one is dismissed.
    private func handleCelebrationDismiss() {
        if chainToCert {
            chainToCert = false
            activeCelebration = .cert
        } else if let days = StreakMilestones.claim(for: viewModel.newStreak) {
            activeCelebration = .streak(days)
        } else {
            onExit()
        }
    }

    // MARK: - Up next (single-drill recommendation)

    private func upNextCard(_ next: DrillContext) -> some View {
        Card(raised: true) {
            VStack(alignment: .leading, spacing: DS.Spacing.s12) {
                Eyebrow(text: "Up Next For You")

                Text(next.drill.title)
                    .style(.title3)
                    .foregroundStyle(DS.Colors.Ink.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text("\(next.category.name) · Level \(next.level.number) · ~\(estimatedSessionMinutes(forDrills: [next.drill])) min")
                    .style(.micro)
                    .foregroundStyle(DS.Colors.Ink.tertiary)

                PrimaryButton(label: "Train it now", hint: nil) {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    nextSession = TrainingQueue(items: [next], source: .single, sourceName: nil)
                }
                .padding(.top, DS.Spacing.s4)
            }
        }
    }

    /// Game IQ suggestion shown after a tactical drill: take the matching lesson next.
    private func gameIQUpNextCard(_ lesson: GameIQLesson) -> some View {
        Card(raised: true) {
            VStack(alignment: .leading, spacing: DS.Spacing.s12) {
                Eyebrow(text: "Level Up Your Game IQ")

                Text(lesson.title)
                    .style(.title3)
                    .foregroundStyle(DS.Colors.Ink.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text("\(lesson.keyPoints.count) points · \(lesson.quiz.count)-question quiz")
                    .style(.micro)
                    .foregroundStyle(DS.Colors.Ink.tertiary)

                PrimaryButton(label: "Take the lesson", hint: nil) {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    activeLesson = lesson
                }
                .padding(.top, DS.Spacing.s4)
            }
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
