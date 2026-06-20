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
    let context: DrillContext
    let queue: TrainingQueue

    /// Advance to the next drill in the queue (swaps in place — never dismisses).
    var onAdvance: () -> Void
    /// End the whole session and dismiss the player.
    var onExit: () -> Void
    /// The final drill was logged — show the session summary.
    var onSessionComplete: () -> Void

    @Environment(\.modelContext) private var modelContext

    @State private var viewModel: DrillPlayerViewModel
    @State private var showStopConfirm = false
    @State private var ambient = AmbientLightMonitor.shared
    @State private var motion = MotionTracker.shared

    @AppStorage("MF_MOTION_REPS") private var motionReps = true
    @AppStorage("MF_SHAKE_ADVANCE") private var shakeAdvance = true
    @AppStorage("MF_MOTION_TRACKING") private var motionTracking = true

    /// Keep the screen awake while a drill is open so it never sleeps mid-set.
    @AppStorage("MF_KEEP_AWAKE") private var keepAwake = true
    /// Gently dim the player in a dark room (uses display brightness as the
    /// store-safe ambient-light proxy).
    @AppStorage("MF_AUTO_DIM") private var autoDim = true
    /// Sets the player has checked off on the tap-to-complete checklist.
    @State private var tappedSets: Set<Int> = []
    /// Whether the optional tap-to-log set checklist is expanded.
    @State private var showManualLog = false

    private var drill: Drill { context.drill }
    private var level: MasteryLevel { context.level }
    private var category: Category { context.category }
    private var discipline: Discipline { context.discipline }

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

    private var breadcrumb: String {
        "\(discipline.name) · \(category.name) · Level \(level.number)"
    }

    /// Announces set/rest transitions to VoiceOver so players know where they are
    /// without looking at the screen.
    private func announce(_ phase: PlayerPhase) {
        let message: String?
        switch phase {
        case .active(let set):
            message = "Set \(set) of \(drill.sets)"
        case .resting(let next):
            message = next <= drill.sets ? "Rest before set \(next)" : "Rest"
        case .logged:
            message = "Drill logged"
        case .ready:
            message = nil
        }
        if let message {
            UIAccessibility.post(notification: .announcement, argument: message)
        }
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
                SessionLoggedView(
                    context: context,
                    queue: queue,
                    viewModel: viewModel,
                    onAdvance: onAdvance,
                    onExit: onExit,
                    onSessionComplete: onSessionComplete
                )
            }

            if autoDim && ambient.isLowLight {
                Color.black
                    .opacity(0.32)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .animation(DS.Motion.standardSpring, value: ambient.isLowLight)
        .safeAreaInset(edge: .top) {
            if queue.isChained {
                sessionProgressBar
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: viewModel.phase) { _, newPhase in
            announce(newPhase)
        }
        .onAppear {
            viewModel.context = modelContext
            UIApplication.shared.isIdleTimerDisabled = keepAwake
            ambient.refresh()
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .alert("End session early?", isPresented: $showStopConfirm) {
            Button("Keep training", role: .cancel) {}
            Button("Log and finish") {
                viewModel.logDrillEarly()
            }
            Button("Quit without logging", role: .destructive) {
                viewModel.stopSession()
                onExit()
            }
        } message: {
            Text(queue.isChained
                 ? "Your completed drills are saved. You can log this one now or quit without logging."
                 : "You can log this drill now or quit without logging.")
        }
    }

    /// A thin full-session progress bar across the very top of the player,
    /// visualizing queue.position / queue.count.
    private var sessionProgressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(DS.Colors.Line.subtle)
                Rectangle()
                    .fill(Color.white)
                    .frame(width: geo.size.width * CGFloat(queue.position) / CGFloat(max(1, queue.count)))
                    .animation(DS.Motion.standardSpring, value: queue.position)
            }
        }
        .frame(height: 3)
        .accessibilityElement()
        .accessibilityLabel("Session progress")
        .accessibilityValue("Drill \(queue.position) of \(queue.count)")
    }

    // MARK: - Phase 1: Get Ready

    private var readyPhase: some View {
        VStack(spacing: 0) {
            HStack {
                IconButton(systemName: "xmark", size: 36) { onExit() }
                Spacer()
                if queue.isChained {
                    Text("Drill \(queue.position) of \(queue.count)")
                        .style(.micro)
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                }
                Spacer()
                DisciplineMark(kind: discipline.mark, size: 24)
            }
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.top, DS.Spacing.s16)

            if queue.source != .single {
                routineProgressHeader
                    .padding(.horizontal, DS.Spacing.s20)
                    .padding(.top, DS.Spacing.s16)
            }

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

                    if let setup = drill.setupSummary {
                        setupLine(setup)
                            .padding(.top, DS.Spacing.s16)
                    }

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

                    if !drill.instructions.isEmpty {
                        Eyebrow(text: "How To Do It")
                            .padding(.top, DS.Spacing.s24)

                        VStack(alignment: .leading, spacing: DS.Spacing.s8) {
                            ForEach(Array(drill.instructions.enumerated()), id: \.offset) { index, step in
                                HStack(alignment: .top, spacing: DS.Spacing.s12) {
                                    Text("\(index + 1).")
                                        .style(.foot)
                                        .foregroundStyle(DS.Colors.Ink.tertiary)
                                        .frame(width: 20, alignment: .leading)
                                    Text(step)
                                        .style(.callout)
                                        .foregroundStyle(DS.Colors.Ink.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                        .padding(.top, DS.Spacing.s12)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DS.Spacing.s20)
                .padding(.top, DS.Spacing.s24)
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)

            startActions
                .padding(.horizontal, DS.Spacing.s20)
                .padding(.bottom, DS.Spacing.s40)
        }
    }

    // MARK: - Start actions

    /// Primary drill action: the guided timer (paced countdown, rest periods,
    /// coaching cues). Tapping each set by hand is an optional choice revealed
    /// below.
    private var startActions: some View {
        VStack(spacing: DS.Spacing.s12) {
            FloatingButton(
                label: "Start Guided Timer",
                hint: "\(drill.sets) × \(Int(viewModel.setDuration))s"
            ) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation(DS.Motion.standardSpring) {
                    viewModel.startSet()
                }
            }
            .accessibilityHint("Runs the paced countdown with rest periods and coaching cues")

            if showManualLog {
                manualChecklist
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(DS.Motion.standardSpring) { showManualLog = true }
                } label: {
                    Label("Log sets manually", systemImage: "checklist")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                        .frame(height: 36)
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityHint("Tap each set as you finish instead of running the timer")
            }
        }
    }

    // MARK: - Tap-to-complete set checklist (optional)

    /// Optional drill action: tap each set as you finish it. Logs automatically
    /// once the last set is checked. "Log all sets" is a one-tap shortcut.
    private var manualChecklist: some View {
        VStack(spacing: DS.Spacing.s12) {
            HStack {
                Eyebrow(text: "Tap Each Set As You Finish")
                    .foregroundStyle(DS.Colors.Ink.quaternary)
                Spacer()
                Text("\(tappedSets.count) of \(drill.sets)")
                    .style(.micro)
                    .foregroundStyle(DS.Colors.Ink.tertiary)
            }

            VStack(spacing: DS.Spacing.s8) {
                ForEach(1...max(1, drill.sets), id: \.self) { setNumber in
                    setChecklistRow(setNumber)
                }
            }

            SecondaryButton(label: "Log all sets") {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation(DS.Motion.standardSpring) {
                    tappedSets = Set(1...max(1, drill.sets))
                }
                logFromChecklist()
            }
            .accessibilityHint("Marks every set complete and logs this drill")
        }
    }

    /// A single tappable set row. Tapping fills it with a check + haptic; checking
    /// the final set logs the drill automatically.
    private func setChecklistRow(_ setNumber: Int) -> some View {
        let done = tappedSets.contains(setNumber)
        return Button {
            guard !tappedSets.contains(setNumber) else { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(DS.Motion.standardSpring) {
                _ = tappedSets.insert(setNumber)
            }
            if tappedSets.count >= max(1, drill.sets) {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                    logFromChecklist()
                }
            }
        } label: {
            HStack(spacing: DS.Spacing.s12) {
                ZStack {
                    Circle()
                        .fill(done ? Color.white : Color.clear)
                        .frame(width: 28, height: 28)
                        .overlay(
                            Circle().stroke(done ? Color.white : DS.Colors.Line.subtle, lineWidth: 1.5)
                        )
                    if done {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(DS.Colors.Ground.primary)
                    }
                }
                Text("Set \(setNumber)")
                    .style(.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(done ? DS.Colors.Ink.tertiary : DS.Colors.Ink.primary)
                Spacer()
                Text(done ? "Logged" : "Tap when done")
                    .style(.micro)
                    .foregroundStyle(DS.Colors.Ink.quaternary)
            }
            .padding(.horizontal, DS.Spacing.s16)
            .frame(height: 56)
            .frame(maxWidth: .infinity)
            .background(DS.Colors.Bg.raised)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel("Set \(setNumber)")
        .accessibilityValue(done ? "Logged" : "Not done")
        .accessibilityHint("Double tap when you finish this set")
    }

    /// Banks the checked sets and logs the drill through the shared path.
    private func logFromChecklist() {
        withAnimation(DS.Motion.standardSpring) {
            viewModel.logFromChecklist(setsCompleted: max(1, tappedSets.count))
        }
    }

    /// Routine/workout progress: source eyebrow, a segmented bar (one segment per
    /// drill, filled as completed), and the current position.
    private var routineProgressHeader: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s8) {
            HStack {
                Eyebrow(text: routineEyebrow)
                    .foregroundStyle(DS.Colors.Ink.secondary)
                Spacer()
                Text("Drill \(queue.position) of \(queue.count)")
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

    /// A compact "SET-UP" row shown on the ready screen when content provides gear/space.
    private func setupLine(_ summary: String) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.s8) {
            Image(systemName: "shippingbox")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(DS.Colors.Ink.tertiary)
            VStack(alignment: .leading, spacing: 2) {
                Eyebrow(text: "Set-Up")
                    .foregroundStyle(DS.Colors.Ink.quaternary)
                Text(summary)
                    .style(.foot)
                    .foregroundStyle(DS.Colors.Ink.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Set up: \(summary)")
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
                if motion.isRunning && (motionReps || motionTracking) {
                    motionStrip
                        .padding(.horizontal, DS.Spacing.s24)
                        .padding(.bottom, DS.Spacing.s24)
                }

                VStack(spacing: DS.Spacing.s16) {
                    HStack(spacing: DS.Spacing.s32) {
                        IconButton(systemName: "forward.end.fill", size: 48) {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            viewModel.skipSet()
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

                    if queue.upNext != nil {
                        skipDrillButton
                    }
                }
                .padding(.bottom, DS.Spacing.s48 + DS.Spacing.s12)
            } else {
                VStack(spacing: DS.Spacing.s16) {
                    if let detail = upNextDetail {
                        VStack(spacing: DS.Spacing.s4) {
                            Eyebrow(text: "Up Next")
                                .foregroundStyle(DS.Colors.Ink.quaternary)
                            Text(detail)
                                .style(.callout)
                                .foregroundStyle(DS.Colors.Ink.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }

                    HStack(spacing: DS.Spacing.s12) {
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(DS.Motion.standardSpring) {
                                viewModel.extendRest()
                            }
                        } label: {
                            Label("+15s", systemImage: "goforward.15")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(DS.Colors.Ink.primary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .overlay(
                                    RoundedRectangle(cornerRadius: DS.Radius.pill)
                                        .stroke(DS.Colors.Line.subtle, lineWidth: 1)
                                )
                        }
                        .buttonStyle(PressableButtonStyle())
                        .accessibilityLabel("Add 15 seconds of rest")

                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            withAnimation(DS.Motion.standardSpring) {
                                viewModel.skipRest()
                            }
                        } label: {
                            Text("Start now")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(DS.Colors.Ground.primary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.pill))
                                .pillLightElevation()
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                    .padding(.horizontal, DS.Spacing.s20)

                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        viewModel.logDrillEarly()
                    } label: {
                        Text("Log and finish")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(DS.Colors.Ink.primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.Radius.pill)
                                    .stroke(DS.Colors.Line.subtle, lineWidth: 1)
                            )
                    }
                    .buttonStyle(PressableButtonStyle())
                    .padding(.horizontal, DS.Spacing.s20)
                }
                .padding(.bottom, DS.Spacing.s48 + DS.Spacing.s12)
            }
        }
    }

    /// Live hands-free readouts during an active set: rep/touch tally and a
    /// movement-intensity meter driven by the phone's motion sensors.
    private var motionStrip: some View {
        HStack(spacing: DS.Spacing.s16) {
            if motionReps {
                VStack(spacing: 2) {
                    Text("\(motion.repCount)")
                        .style(.num(size: 30))
                        .foregroundStyle(DS.Colors.Ink.primary)
                        .contentTransition(.numericText())
                        .animation(DS.Motion.standardSpring, value: motion.repCount)
                    Text("REPS")
                        .style(.microSm)
                        .foregroundStyle(DS.Colors.Ink.quaternary)
                }
                .frame(maxWidth: .infinity)
            }
            if motionTracking {
                VStack(alignment: .leading, spacing: DS.Spacing.s4) {
                    Text("INTENSITY")
                        .style(.microSm)
                        .foregroundStyle(DS.Colors.Ink.quaternary)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(DS.Colors.Line.subtle)
                            Capsule()
                                .fill(Color.white)
                                .frame(width: geo.size.width * CGFloat(min(1, motion.intensity)))
                                .animation(DS.Motion.standardSpring, value: motion.intensity)
                        }
                    }
                    .frame(height: 8)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, DS.Spacing.s12)
        .padding(.horizontal, DS.Spacing.s16)
        .background(DS.Colors.Bg.raised)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(alignment: .topTrailing) {
            if shakeAdvance {
                Text("SHAKE TO ADVANCE")
                    .style(.microSm)
                    .foregroundStyle(DS.Colors.Ink.quaternary)
                    .padding(.top, 6)
                    .padding(.trailing, 10)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(motion.repCount) reps counted")
    }

    /// A small text button that skips the current drill entirely and advances to
    /// the next drill in the queue (separate from skipSet, which only skips the
    /// current set).
    private var skipDrillButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            viewModel.stopSession()
            onAdvance()
        } label: {
            Label("Skip drill", systemImage: "forward.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DS.Colors.Ink.tertiary)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityHint("Skips this drill and moves to the next one")
    }

    /// During rest, surface what comes next with its time: the next set, or — if
    /// this was the final set and the queue has another drill — the next drill.
    private var upNextDetail: String? {
        guard case let .resting(nextSetIndex) = viewModel.phase else { return nil }
        if nextSetIndex <= drill.sets {
            return "Set \(nextSetIndex) of \(drill.sets) · \(Int(viewModel.setDuration))s"
        }
        if let next = queue.upNext {
            return "\(next.drill.title) · ~\(estimatedSessionMinutes(forDrills: [next.drill])) min"
        }
        return nil
    }
}
