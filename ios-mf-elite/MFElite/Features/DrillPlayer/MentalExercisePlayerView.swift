//
//  MentalExercisePlayerView.swift
//  MFElite
//
//  A step-driven player for psychological exercises. Unlike timer-based drills,
//  mental exercises advance one guided step at a time, optionally show a breathing
//  animation, and end on a reflective journal prompt. Completion logs the drill
//  through the shared SessionLoggedView (XP, streak, mastery, celebrations).
//

import SwiftUI
import SwiftData

struct MentalExercisePlayerView: View {
    let context: DrillContext
    let queue: TrainingQueue

    var onAdvance: () -> Void
    var onExit: () -> Void
    var onSessionComplete: () -> Void

    @Environment(\.modelContext) private var modelContext

    @State private var viewModel: DrillPlayerViewModel
    @State private var stage: Stage = .intro
    @State private var stepIndex: Int = 0
    @State private var journalText: String = ""
    @FocusState private var journalFocused: Bool

    private enum Stage {
        case intro
        case steps
        case journal
        case logged
    }

    private var drill: Drill { context.drill }
    private var level: MasteryLevel { context.level }
    private var category: Category { context.category }
    private var discipline: Discipline { context.discipline }

    private var kind: MentalExerciseKind {
        MentalExerciseKind(rawValue: drill.exerciseKind ?? "") ?? .guided
    }

    private var steps: [String] {
        drill.steps.isEmpty ? [drill.how] : drill.steps
    }

    private var breadcrumb: String {
        "\(discipline.name) · \(category.name) · Level \(level.number)"
    }

    init(
        context: DrillContext,
        queue: TrainingQueue,
        onAdvance: @escaping () -> Void,
        onExit: @escaping () -> Void,
        onSessionComplete: @escaping () -> Void
    ) {
        self.context = context
        self.queue = queue
        self.onAdvance = onAdvance
        self.onExit = onExit
        self.onSessionComplete = onSessionComplete
        _viewModel = State(
            initialValue: DrillPlayerViewModel(
                drill: context.drill,
                level: context.level,
                category: context.category,
                discipline: context.discipline,
                source: queue.source.rawValue,
                sourceName: queue.sourceName
            )
        )
    }

    var body: some View {
        ZStack {
            DS.Colors.Bg.base.ignoresSafeArea()

            switch stage {
            case .intro:
                introStage
            case .steps:
                stepsStage
            case .journal:
                journalStage
            case .logged:
                SessionLoggedView(
                    context: context,
                    queue: queue,
                    viewModel: viewModel,
                    onAdvance: onAdvance,
                    onExit: onExit,
                    onSessionComplete: onSessionComplete
                )
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            viewModel.context = modelContext
            UIApplication.shared.isIdleTimerDisabled = UserDefaults.standard.object(forKey: "MF_KEEP_AWAKE") == nil ? true : UserDefaults.standard.bool(forKey: "MF_KEEP_AWAKE")
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    // MARK: - Header

    private func header(showProgress: Bool) -> some View {
        VStack(spacing: DS.Spacing.s16) {
            HStack {
                IconButton(systemName: "xmark", size: 36) { onExit() }
                Spacer()
                if queue.isChained {
                    Text("\(queue.position) of \(queue.count)")
                        .style(.micro)
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                }
                Spacer()
                DisciplineMark(kind: discipline.mark, size: 24)
            }

            if showProgress {
                HStack(spacing: 4) {
                    ForEach(steps.indices, id: \.self) { idx in
                        Capsule()
                            .fill(idx <= stepIndex ? Color.white : DS.Colors.Line.subtle)
                            .frame(height: 4)
                            .frame(maxWidth: .infinity)
                            .animation(DS.Motion.standardSpring, value: stepIndex)
                    }
                }
            }
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s16)
    }

    // MARK: - Intro

    private var introStage: some View {
        VStack(spacing: 0) {
            header(showProgress: false)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: DS.Spacing.s8) {
                        kindBadge
                        infoPill("~\(max(1, drill.durationSec / 60)) min")
                        infoPill("+\(ProgressionRules.xpPerDrill) XP")
                    }

                    Eyebrow(text: breadcrumb)
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                        .padding(.top, DS.Spacing.s20)

                    Text(drill.title)
                        .style(.hero)
                        .foregroundStyle(DS.Colors.Ink.primary)
                        .padding(.top, DS.Spacing.s8)

                    Text(drill.how)
                        .style(.body)
                        .foregroundStyle(DS.Colors.Ink.secondary)
                        .padding(.top, DS.Spacing.s16)

                    if let setup = drill.setupSummary {
                        HStack(alignment: .top, spacing: DS.Spacing.s8) {
                            Image(systemName: "shippingbox")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(DS.Colors.Ink.tertiary)
                            VStack(alignment: .leading, spacing: 2) {
                                Eyebrow(text: "Set-Up")
                                    .foregroundStyle(DS.Colors.Ink.quaternary)
                                Text(setup)
                                    .style(.foot)
                                    .foregroundStyle(DS.Colors.Ink.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, DS.Spacing.s16)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Set up: \(setup)")
                    }

                    if !drill.coachingPoints.isEmpty {
                        Eyebrow(text: "Keep In Mind")
                            .padding(.top, DS.Spacing.s32)

                        VStack(alignment: .leading, spacing: DS.Spacing.s12 + 2) {
                            ForEach(Array(drill.coachingPoints.enumerated()), id: \.offset) { _, point in
                                HStack(alignment: .top, spacing: DS.Spacing.s12) {
                                    Circle()
                                        .fill(DS.Colors.Ink.tertiary)
                                        .frame(width: 5, height: 5)
                                        .padding(.top, 8)
                                    Text(point)
                                        .style(.callout)
                                        .foregroundStyle(DS.Colors.Ink.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                        .padding(.top, DS.Spacing.s16)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DS.Spacing.s20)
                .padding(.top, DS.Spacing.s24)
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)

            VStack(spacing: DS.Spacing.s12) {
                FloatingButton(label: "Begin exercise", hint: "\(steps.count) STEPS") {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    withAnimation(DS.Motion.standardSpring) { stage = .steps }
                }
                SecondaryButton(label: "Log as done — skip steps") {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    viewModel.completeMentalExercise(journal: nil)
                    withAnimation(DS.Motion.standardSpring) { stage = .logged }
                }
                .accessibilityHint("Logs this exercise as completed without going through the steps")

                if queue.upNext != nil {
                    skipDrillButton
                }
            }
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.bottom, DS.Spacing.s40)
        }
    }

    /// A small text button that skips this exercise entirely and advances to the
    /// next drill in the queue (parallels DrillPlayerView's Skip drill). When the
    /// queue has another drill, it surfaces what's coming next.
    private var skipDrillButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onAdvance()
        } label: {
            VStack(spacing: 2) {
                Label("Skip drill", systemImage: "forward.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DS.Colors.Ink.tertiary)
                if let next = queue.upNext {
                    Text("Up next: \(next.drill.title)")
                        .style(.micro)
                        .foregroundStyle(DS.Colors.Ink.quaternary)
                }
            }
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityHint("Skips this exercise and moves to the next one")
    }

    private var kindBadge: some View {
        HStack(spacing: DS.Spacing.s4 + 2) {
            Image(systemName: kind.symbol)
                .font(.system(size: 11, weight: .bold))
            Text(kind.label)
                .style(.micro)
        }
        .foregroundStyle(DS.Colors.Ground.primary)
        .padding(.vertical, 6)
        .padding(.horizontal, DS.Spacing.s12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.pill))
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

    // MARK: - Steps

    private var stepsStage: some View {
        VStack(spacing: 0) {
            header(showProgress: true)

            if kind == .breathing {
                BreathingGuide(pattern: breathPattern)
                    .frame(height: 280)
                    .padding(.top, DS.Spacing.s24)
            } else {
                Spacer(minLength: 0)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.s12) {
                    Eyebrow(text: "Step \(stepIndex + 1) of \(steps.count)")
                        .foregroundStyle(DS.Colors.Ink.quaternary)

                    Text(steps[stepIndex])
                        .style(kind == .breathing ? .title3 : .title2)
                        .foregroundStyle(DS.Colors.Ink.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .animation(DS.Motion.standardSpring, value: stepIndex)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DS.Spacing.s20)
                .padding(.top, DS.Spacing.s24)
                .padding(.bottom, DS.Spacing.s24)
            }
            .scrollIndicators(.hidden)

            VStack(spacing: DS.Spacing.s12) {
                stepControls
                if queue.upNext != nil {
                    skipDrillButton
                }
            }
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.bottom, DS.Spacing.s40)
        }
    }

    private var stepControls: some View {
        HStack(spacing: DS.Spacing.s12) {
            if stepIndex > 0 {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(DS.Motion.standardSpring) { stepIndex -= 1 }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(DS.Colors.Ink.primary)
                        .frame(width: 56, height: 56)
                        .overlay(
                            Circle().stroke(DS.Colors.Line.subtle, lineWidth: 1)
                        )
                }
                .buttonStyle(PressableButtonStyle())
            }

            FloatingButton(
                label: stepIndex < steps.count - 1 ? "Next step" : finishStepLabel
            ) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                if stepIndex < steps.count - 1 {
                    withAnimation(DS.Motion.standardSpring) { stepIndex += 1 }
                } else {
                    advancePastSteps()
                }
            }
        }
    }

    private var finishStepLabel: String {
        drill.journalPrompt == nil ? "Complete exercise" : "Reflect"
    }

    private func advancePastSteps() {
        if drill.journalPrompt != nil {
            withAnimation(DS.Motion.standardSpring) { stage = .journal }
        } else {
            complete()
        }
    }

    // MARK: - Journal

    private var journalStage: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    journalFocused = false
                    withAnimation(DS.Motion.standardSpring) { stage = .steps }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(DS.Colors.Ink.primary)
                        .frame(width: 36, height: 36)
                        .background(DS.Colors.Bg.raised)
                        .clipShape(Circle())
                }
                .buttonStyle(PressableButtonStyle())
                Spacer()
                DisciplineMark(kind: discipline.mark, size: 24)
            }
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.top, DS.Spacing.s16)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Eyebrow(text: "Reflect")
                        .foregroundStyle(DS.Colors.Ink.quaternary)

                    Text(drill.journalPrompt ?? "")
                        .style(.title2)
                        .foregroundStyle(DS.Colors.Ink.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, DS.Spacing.s12)

                    journalEditor
                        .padding(.top, DS.Spacing.s20)

                    Text("Private to you. Saved with this exercise so you can look back.")
                        .style(.micro)
                        .foregroundStyle(DS.Colors.Ink.quaternary)
                        .padding(.top, DS.Spacing.s12)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DS.Spacing.s20)
                .padding(.top, DS.Spacing.s24)
                .padding(.bottom, DS.Spacing.s24)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)

            VStack(spacing: DS.Spacing.s8) {
                FloatingButton(label: "Save & complete") {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    journalFocused = false
                    complete()
                }
                GhostButton(label: "Skip reflection") {
                    journalText = ""
                    journalFocused = false
                    complete()
                }
            }
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.bottom, DS.Spacing.s24)
        }
    }

    private var journalEditor: some View {
        ZStack(alignment: .topLeading) {
            if journalText.isEmpty {
                Text("Write your answer…")
                    .style(.body)
                    .foregroundStyle(DS.Colors.Ink.quaternary)
                    .padding(.top, DS.Spacing.s12 + 2)
                    .padding(.leading, DS.Spacing.s12 + 2)
            }
            TextEditor(text: $journalText)
                .focused($journalFocused)
                .font(.system(size: 17))
                .foregroundStyle(DS.Colors.Ink.primary)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 160)
                .padding(DS.Spacing.s8)
        }
        .background(DS.Colors.Bg.elevated)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .stroke(DS.Colors.Line.subtle, lineWidth: 1)
        )
    }

    // MARK: - Completion

    private func complete() {
        viewModel.completeMentalExercise(journal: journalText)
        withAnimation(DS.Motion.standardSpring) { stage = .logged }
    }

    /// The breathing rhythm: long-exhale resets use 4-in / 8-out; everything else
    /// uses box breathing (4-4-4-4).
    private var breathPattern: [BreathPhase] {
        if drill.id == "psy-d-1-1" || drill.title.localizedCaseInsensitiveContains("exhale") {
            return [
                BreathPhase(label: "Breathe in", seconds: 4, target: 1.0),
                BreathPhase(label: "Long exhale", seconds: 8, target: 0.45)
            ]
        }
        return [
            BreathPhase(label: "Breathe in", seconds: 4, target: 1.0),
            BreathPhase(label: "Hold", seconds: 4, target: 1.0),
            BreathPhase(label: "Breathe out", seconds: 4, target: 0.45),
            BreathPhase(label: "Hold", seconds: 4, target: 0.45)
        ]
    }
}

/// The four mental-exercise formats from the curriculum.
enum MentalExerciseKind: String {
    case guided
    case breathing
    case visualization
    case journal

    var label: String {
        switch self {
        case .guided: return "Guided"
        case .breathing: return "Breathing"
        case .visualization: return "Visualization"
        case .journal: return "Journal"
        }
    }

    var symbol: String {
        switch self {
        case .guided: return "list.bullet"
        case .breathing: return "wind"
        case .visualization: return "eye"
        case .journal: return "square.and.pencil"
        }
    }
}

/// One phase of a breathing cycle.
struct BreathPhase: Equatable {
    let label: String
    let seconds: Int
    let target: CGFloat
}

/// An animated breathing circle that loops a sequence of phases, scaling the
/// circle and showing the current instruction with a per-phase countdown.
struct BreathingGuide: View {
    let pattern: [BreathPhase]

    @State private var index: Int = 0
    @State private var scale: CGFloat = 0.45
    @State private var secondsLeft: Int = 0
    @State private var timer: Timer?

    private var phase: BreathPhase {
        pattern.indices.contains(index) ? pattern[index] : pattern[0]
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.06))
                .frame(width: 260, height: 260)
                .blur(radius: 50)

            Circle()
                .stroke(DS.Colors.Line.subtle, lineWidth: 1)
                .frame(width: 240, height: 240)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.9), Color.white.opacity(0.25)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 120
                    )
                )
                .frame(width: 200, height: 200)
                .scaleEffect(scale)

            VStack(spacing: DS.Spacing.s4) {
                Text(phase.label)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(DS.Colors.Ground.primary)
                Text("\(secondsLeft)")
                    .font(DS.Typography.num(size: 22))
                    .foregroundStyle(Color.black.opacity(0.55))
            }
        }
        .frame(maxWidth: .infinity)
        .onAppear { beginPhase() }
        .onDisappear { timer?.invalidate(); timer = nil }
    }

    private func beginPhase() {
        let current = phase
        secondsLeft = current.seconds
        withAnimation(.easeInOut(duration: Double(current.seconds))) {
            scale = current.target
        }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()

        timer?.invalidate()
        let t = Timer(timeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                secondsLeft -= 1
                if secondsLeft <= 0 {
                    index = (index + 1) % pattern.count
                    beginPhase()
                }
            }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }
}
