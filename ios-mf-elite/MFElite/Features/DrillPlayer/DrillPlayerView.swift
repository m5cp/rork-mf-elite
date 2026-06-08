//
//  DrillPlayerView.swift
//  MFElite
//
//  Full-screen drill session: ready → active → resting → logged.
//

import SwiftUI
import SwiftData
import StoreKit

struct DrillPlayerView: View {
    let drill: Drill
    let level: MasteryLevel
    let category: Category
    let discipline: Discipline

    /// Pushes to the next unmastered drill after dismissal.
    var onNextDrill: ((DrillRoute) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.requestReview) private var requestReview

    @State private var viewModel: DrillPlayerViewModel
    @State private var showStopConfirm = false
    @State private var celebrate = false
    @State private var activeCelebration: CelebrationKind?
    @State private var chainToCert = false
    @State private var showNotificationPrompt = false

    init(
        drill: Drill,
        level: MasteryLevel,
        category: Category,
        discipline: Discipline,
        onNextDrill: ((DrillRoute) -> Void)? = nil
    ) {
        self.drill = drill
        self.level = level
        self.category = category
        self.discipline = discipline
        self.onNextDrill = onNextDrill
        _viewModel = State(
            initialValue: DrillPlayerViewModel(
                drill: drill,
                level: level,
                category: category,
                discipline: discipline
            )
        )
    }

    private var breadcrumb: String {
        "\(discipline.name) · \(category.name) · Level \(level.number)"
    }

    var body: some View {
        ZStack {
            DS.Colors.Bg.base.ignoresSafeArea()

            switch viewModel.phase {
            case .ready:
                readyPhase
            case .active, .resting:
                activePhase
            case .logged:
                loggedPhase
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            viewModel.context = modelContext
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .alert("End session early?", isPresented: $showStopConfirm) {
            Button("Keep training", role: .cancel) {}
            Button("End session", role: .destructive) {
                viewModel.stopSession()
                dismiss()
            }
        } message: {
            Text("Your progress for this drill won't be logged.")
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
    }

    /// A celebration to present over the logged screen.
    enum CelebrationKind: String, Identifiable {
        case level
        case cert
        var id: String { rawValue }
    }

    /// After a celebration cover closes, chain to the cert award if needed,
    /// otherwise dismiss the whole player back to the level.
    private func handleCelebrationDismiss() {
        if chainToCert {
            chainToCert = false
            activeCelebration = .cert
        } else {
            dismiss()
        }
    }

    // MARK: - Phase 1: Get Ready

    private var readyPhase: some View {
        VStack(spacing: 0) {
            HStack {
                IconButton(systemName: "xmark", size: 36) { dismiss() }
                Spacer()
                DisciplineMark(kind: discipline.mark, size: 24)
            }
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.top, DS.Spacing.s16)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Eyebrow(text: breadcrumb)
                        .foregroundStyle(DS.Colors.Ink.tertiary)

                    Text(drill.title)
                        .style(.hero)
                        .foregroundStyle(DS.Colors.Ink.primary)
                        .multilineTextAlignment(.leading)
                        .padding(.top, DS.Spacing.s12)

                    HStack(spacing: DS.Spacing.s8) {
                        infoPill("\(drill.sets) Sets")
                        infoPill("\(Int(viewModel.setDuration))s Each")
                        infoPill("+\(ProgressionRules.xpPerDrill) XP")
                    }
                    .padding(.top, DS.Spacing.s20)

                    Eyebrow(text: "Hold These In Mind")
                        .padding(.top, DS.Spacing.s32)

                    VStack(alignment: .leading, spacing: DS.Spacing.s12 + 2) {
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
                .padding(.top, DS.Spacing.s24)
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)

            FloatingButton(label: "Start set", hint: "SET 1 OF \(drill.sets)") {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation(DS.Motion.standardSpring) {
                    viewModel.startSet()
                }
            }
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.bottom, DS.Spacing.s40)
        }
    }

    private func infoPill(_ text: String) -> some View {
        Text(text)
            .style(.micro)
            .foregroundStyle(DS.Colors.Ink.primary)
            .padding(.vertical, 6)
            .padding(.horizontal, DS.Spacing.s12 + 2)
            .background(DS.Colors.Bg.raised)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.pill))
    }

    // MARK: - Phase 2: Active / Resting

    private var isResting: Bool {
        if case .resting = viewModel.phase { return true }
        return false
    }

    private var activePhase: some View {
        VStack(spacing: 0) {
            VStack(spacing: DS.Spacing.s8) {
                HStack(spacing: 6) {
                    ForEach(1...max(1, drill.sets), id: \.self) { setNumber in
                        Circle()
                            .fill(setNumber < viewModel.currentSetIndex || (setNumber == viewModel.currentSetIndex && !isResting) ? Color.white : Color.clear)
                            .frame(width: 10, height: 10)
                            .overlay(
                                Circle().stroke(DS.Colors.Line.subtle, lineWidth: 1)
                            )
                    }
                }
                Text(isResting ? "Rest Before Set \(viewModel.currentSetIndex + 1)" : "Set \(viewModel.currentSetIndex) Of \(drill.sets)")
                    .style(.micro)
                    .foregroundStyle(DS.Colors.Ink.tertiary)
            }
            .padding(.top, DS.Spacing.s40)

            Spacer()

            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 300, height: 300)
                    .blur(radius: 60)

                PitchRing(
                    size: 250,
                    progress: viewModel.progress,
                    strokeWidth: 10,
                    value: viewModel.formattedTime,
                    label: isResting ? "Rest" : "Remaining"
                )
            }

            Text(isResting ? "Rest — next set in \(Int(ceil(viewModel.timeRemaining)))s" : viewModel.currentCoachingCue)
                .style(.title2)
                .foregroundStyle(DS.Colors.Ink.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, DS.Spacing.s24)
                .padding(.top, DS.Spacing.s24)
                .animation(DS.Motion.standardSpring, value: viewModel.currentCoachingCue)

            Spacer()

            if !isResting {
                HStack(spacing: DS.Spacing.s32) {
                    IconButton(systemName: "backward.end.fill", size: 48) {
                        viewModel.timeRemaining = viewModel.setDuration
                    }

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        viewModel.pauseResume()
                    } label: {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 84, height: 84)
                            .overlay(
                                Image(systemName: viewModel.isPaused ? "play.fill" : "pause.fill")
                                    .font(.system(size: 30, weight: .bold))
                                    .foregroundStyle(DS.Colors.Ground.primary)
                                    .offset(x: viewModel.isPaused ? 2 : 0)
                            )
                            .floatingElevation()
                    }
                    .buttonStyle(PressableButtonStyle())

                    IconButton(systemName: "stop.fill", size: 48) {
                        showStopConfirm = true
                    }
                }
                .padding(.bottom, DS.Spacing.s48 + DS.Spacing.s12)
            } else {
                Color.clear.frame(height: 84 + DS.Spacing.s48 + DS.Spacing.s12)
            }
        }
    }

    // MARK: - Phase 3: Logged

    private var loggedPhase: some View {
        ScrollView {
            VStack(spacing: 0) {
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

                Eyebrow(text: "Set \(drill.sets) Of \(drill.sets) · Logged")
                    .padding(.top, DS.Spacing.s24)

                Text(drill.title)
                    .style(.title1)
                    .foregroundStyle(DS.Colors.Ink.primary)
                    .multilineTextAlignment(.center)
                    .padding(.top, DS.Spacing.s8)

                Text("Logged honestly — clean run, no losses.")
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
                    PrimaryButton(label: "Next drill", hint: "LEVEL \(level.number)") {
                        goToNextDrill()
                    }
                    SecondaryButton(label: "Back to level") {
                        dismiss()
                    }
                }
                .padding(.top, DS.Spacing.s32)
            }
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.bottom, 80)
        }
        .scrollIndicators(.hidden)
        .onAppear {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(DS.Motion.celebrationSpring) {
                celebrate = true
            }
            handleDrillLogged()
            if viewModel.levelJustMastered {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    activeCelebration = .level
                }
            }
        }
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

    /// Runs once when the logged screen appears: counts the completion, gates the
    /// soft notification prompt (first drill) and any positive-moment review ask.
    private func handleDrillLogged() {
        EngagementTracker.shared.recordDrillCompleted()

        // Soft notification prompt after the first (and, if deferred, third) drill.
        EngagementTracker.shared.evaluateNotificationPrompt { show in
            guard show else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                showNotificationPrompt = true
            }
        }

        // App review on positive moments — never mid-level celebration.
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

    private func goToNextDrill() {
        // Find the next unmastered drill in the level (excluding the just-logged one).
        let ordered = level.drills.sorted { $0.sortIndex < $1.sortIndex }
        let next = ordered.first { candidate in
            guard candidate.id != drill.id else { return false }
            let candidateID = candidate.id
            let mastered = (try? modelContext.fetch(
                FetchDescriptor<DrillProgress>(predicate: #Predicate { $0.drillID == candidateID })
            ).first?.isMastered) ?? false
            return mastered != true
        }

        dismiss()
        if let next, let onNextDrill {
            let route = DrillRoute(discipline: discipline, category: category, level: level, drill: next)
            onNextDrill(route)
        }
    }
}
