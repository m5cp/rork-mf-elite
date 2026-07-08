//
//  AcademyTodayView.swift
//  MFElite
//
//  Tab 1 — the daily dashboard: greeting, standard, goals, pathway, recommendations.
//

import SwiftUI
import SwiftData

/// Reference-type memo so the drillID→context map is built once and reused
/// across body evaluations, rebuilding only when the curriculum graph changes.
private final class TodayWorkoutIndexCache {
    var signature: Int = -1
    var index: [String: DrillContext] = [:]
}

struct AcademyTodayView: View {
    @Query(sort: \Discipline.sortIndex) private var disciplines: [Discipline]
    @Query private var players: [PlayerState]
    @Query private var progress: [DrillProgress]
    @Query private var sessions: [SessionLogEntry]
    @Query(sort: \CustomWorkout.updatedAt, order: .reverse) private var workouts: [CustomWorkout]
    @Query(sort: \CombineTest.sortIndex) private var combineTests: [CombineTest]
    @Query private var combineResults: [CombineResult]
    @Query(sort: \GameIQLesson.sortIndex) private var gameIQLessons: [GameIQLesson]
    @Query(sort: \Announcement.createdAt, order: .reverse) private var announcements: [Announcement]
    @Query(sort: \CoachWorkout.createdAt, order: .reverse) private var coachWorkouts: [CoachWorkout]
    @Query private var activePlans: [ActivePlan]
    @Environment(SubscriptionService.self) private var subscription
    @Environment(\.modelContext) private var modelContext
    @State private var profile = PlayerProfileStore.shared
    @State private var favorites = FavoritesStore.shared
    @State private var workoutIndexCache = TodayWorkoutIndexCache()
    @State private var activeSession: TrainingQueue?
    @State private var showBuilder = false
    @State private var router = AppActionRouter.shared
    @State private var retestStore = CombineRetestStore.shared
    @State private var activeLesson: GameIQLesson?
    @State private var matchDay: MatchDayLaunch?
    @State private var announcementStore = AnnouncementStore.shared
    @State private var announcementExpanded = false
    @State private var resumeStore = ResumeStore.shared
    @State private var recapShareImage: ShareableImage?
    @State private var syncEngine = SyncEngine.shared
    @State private var auth = SupabaseAuth.shared
    @State private var appeared = false
    @State private var pendingPlanAdvance: PendingPlanAdvance?
    @State private var showChangePlanConfirm = false

    /// Most recent workouts shown inline on the home strip before "See all".
    private let homeWorkoutLimit = 6

    /// Free players may keep a single custom workout; Elite is unlimited.
    private var canCreateWorkout: Bool {
        subscription.hasFullAccess || workouts.count < 1
    }

    /// drillID → resolved context, rebuilt only when the curriculum graph changes.
    private var drillIndex: [String: DrillContext] {
        let signature = disciplines.map { ObjectIdentifier($0) }.hashValue
        if workoutIndexCache.signature != signature {
            var map: [String: DrillContext] = [:]
            for discipline in disciplines {
                for category in discipline.categories {
                    for level in category.levels {
                        for drill in level.drills {
                            map[drill.id] = DrillContext(
                                drill: drill, level: level, category: category, discipline: discipline
                            )
                        }
                    }
                }
            }
            workoutIndexCache.index = map
            workoutIndexCache.signature = signature
        }
        return workoutIndexCache.index
    }

    private var viewModel: AcademyTodayViewModel {
        AcademyTodayViewModel(
            disciplines: disciplines,
            xp: players.first?.xp ?? 0,
            streak: players.first?.streak ?? 0,
            progress: progress,
            sessions: sessions,
            positionCode: profile.positionCode,
            startingLevelBias: profile.startingLevelBias,
            gameIQLessons: gameIQLessons
        )
    }

    var body: some View {
        let vm = viewModel
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    topBar(vm)
                    if profile.shouldPromptProfileCompletion {
                        completeProfileBanner.entrance(0, appeared: appeared)
                    }
                    resumeCard.entrance(1, appeared: appeared)
                    salutation(vm).entrance(2, appeared: appeared)
                    todaySessionCard.entrance(3, appeared: appeared)
                    announcementBanner.entrance(4, appeared: appeared)
                    combineRetestNudge.entrance(5, appeared: appeared)
                    dailyStandard(vm).entrance(6, appeared: appeared)
                    goalsCard(vm).entrance(7, appeared: appeared)
                    weeklyRecapCard.entrance(8, appeared: appeared)
                    CoachsChoiceSection().entrance(9, appeared: appeared)
                    matchDayRow(vm).entrance(10, appeared: appeared)
                    todaysFocusCard(vm).entrance(11, appeared: appeared)
                    myWorkoutsSection.entrance(12, appeared: appeared)
                    continuePathway(vm).entrance(13, appeared: appeared)
                }
                .padding(.bottom, 120)
            }
            .background(DS.Colors.Bg.base)
            .scrollIndicators(.hidden)
            .navigationBarHidden(true)
            .navigationDestination(for: LevelRoute.self) { route in
                LevelView(level: route.level, category: route.category, discipline: route.discipline)
            }
            .navigationDestination(for: DrillRoute.self) { route in
                DrillDetailView(drill: route.drill, level: route.level, category: route.category, discipline: route.discipline)
            }
            .navigationDestination(for: StreakRoute.self) { _ in
                StreakDetailView()
            }
            .navigationDestination(for: SettingsRoute.self) { _ in
                SettingsView()
            }
            .navigationDestination(for: RoutinesRoute.self) { _ in
                RoutinesView()
            }
            .navigationDestination(for: DrillLibraryRoute.self) { _ in
                DrillLibraryView()
            }
            .navigationDestination(for: MyWorkoutsRoute.self) { _ in
                MyWorkoutsView()
            }
            .navigationDestination(for: FavoritesRoute.self) { _ in
                FavoritesView()
            }
            .navigationDestination(for: CombineRoute.self) { _ in
                CombineView()
            }
            .navigationDestination(for: PlayerCardRoute.self) { _ in
                PlayerCardView()
            }
        }
        .fullScreenCover(item: $activeSession, onDismiss: advancePlanIfNeeded) { queue in
            SessionPlayerView(queue: queue)
        }
        .fullScreenCover(item: $activeLesson) { lesson in
            GameIQLessonView(lesson: lesson) { activeLesson = nil }
        }
        .fullScreenCover(item: $matchDay) { launch in
            MatchDayFlowView(items: launch.items, cueLine: launch.cueLine)
        }
        .sheet(item: $recapShareImage) { item in
            ShareSheet(items: [item.image])
                .presentationDetents([.medium, .large])
        }
        .task {
            await CoachWorkoutFeed.refresh(context: modelContext)
            await AnnouncementFeed.refresh(context: modelContext)
            await CurriculumOverlay.applyAndMaybeRefresh(context: modelContext)
        }
        .sheet(isPresented: $showBuilder) {
            WorkoutBuilderView()
        }
        .confirmationDialog(
            "Change your plan?",
            isPresented: $showChangePlanConfirm,
            titleVisibility: .visible
        ) {
            Button("Clear my plan", role: .destructive) { clearActivePlan() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Today's session will fall back to the coach's workout of the day or the daily routine.")
        }
        .onChange(of: router.startTrainingToken) { _, _ in
            startRecommendedSession(vm)
        }
        .onChange(of: router.starterSessionToken) { _, _ in
            startStarterSession()
        }
        .onAppear {
            // A freshly-onboarded player is dropped straight into a short starter
            // session instead of an empty Today screen.
            if router.starterSessionToken > 0 { startStarterSession() }
            resumeStore.refresh()
            if !appeared { appeared = true }
        }
    }

    // MARK: - Today's Session hero card

    /// Where today's hero session comes from.
    private enum TodaySessionSource {
        case activePlan(ActivePlan)
        case coachWorkout(CoachWorkout)
        case appDefault(RoutineSpec)
    }

    /// Tracks a session started from the active plan so the plan advances only
    /// after the queue actually completed at least one drill.
    private struct PendingPlanAdvance {
        let planID: UUID
        let queue: TrainingQueue
    }

    /// Fallback chain: player's plan → latest coach workout → day-of-week default.
    /// Sources that resolve to zero known drills are skipped so the card never
    /// renders empty.
    private func resolveTodaySession() -> (source: TodaySessionSource, items: [DrillContext]) {
        let index = drillIndex
        if let plan = activePlans.first, !plan.isFinished {
            let idx = min(max(plan.currentSessionIndex, 0), plan.sessions.count - 1)
            let items = plan.sessions.indices.contains(idx)
                ? plan.sessions[idx].compactMap { index[$0] }
                : []
            if !items.isEmpty { return (.activePlan(plan), items) }
        }
        if let wod = coachWorkouts.max(by: { $0.createdAt < $1.createdAt }) {
            let items = wod.drillIDs.compactMap { index[$0] }
            if !items.isEmpty { return (.coachWorkout(wod), items) }
        }
        let specs = RoutineCatalog.all
        let dayIndex = Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
        let spec = specs[dayIndex % specs.count]
        return (.appDefault(spec), spec.drillIDs.compactMap { index[$0] })
    }

    /// The one-decision hero card: the player's next session and a Start button.
    private var todaySessionCard: some View {
        let session = resolveTodaySession()
        let eyebrowText: String
        let title: String
        let progress: String
        var isPlan = false
        switch session.source {
        case .activePlan(let plan):
            eyebrowText = "Your Plan"
            title = plan.title
            progress = plan.progressLabel
            isPlan = true
        case .coachWorkout(let wod):
            eyebrowText = "From Coach \(wod.coachName.uppercased())"
            title = wod.title
            progress = ""
        case .appDefault(let spec):
            eyebrowText = "Workout of the Day"
            title = spec.title
            progress = ""
        }
        let minutes = estimatedSessionMinutes(forDrills: session.items.map(\.drill))
        return VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: "Today's Session")
                .padding(.horizontal, DS.Spacing.s20)

            Card(padding: DS.Spacing.s20, raised: true) {
                VStack(alignment: .leading, spacing: DS.Spacing.s12) {
                    HStack(alignment: .top) {
                        Eyebrow(text: eyebrowText)
                        Spacer(minLength: DS.Spacing.s8)
                        if isPlan {
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                showChangePlanConfirm = true
                            } label: {
                                Text("Change")
                                    .style(.micro)
                                    .foregroundStyle(DS.Colors.Ink.tertiary)
                                    .underline()
                                    .frame(minHeight: 28)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(PressableButtonStyle())
                            .accessibilityLabel("Change plan")
                        }
                    }

                    Text(title)
                        .style(.title2)
                        .foregroundStyle(DS.Colors.Ink.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: DS.Spacing.s8) {
                        if !progress.isEmpty {
                            Text(progress)
                                .style(.micro)
                                .foregroundStyle(DS.Colors.Ink.primary)
                            Text("·")
                                .style(.micro)
                                .foregroundStyle(DS.Colors.Ink.quaternary)
                        }
                        Text("\(session.items.count) \(session.items.count == 1 ? "drill" : "drills") · \(minutes) min")
                            .style(.micro)
                            .foregroundStyle(DS.Colors.Ink.tertiary)
                    }

                    PrimaryButton(label: "Start session", hint: "\(minutes) MIN") {
                        startTodaySession(session)
                    }
                    .padding(.top, DS.Spacing.s4)
                }
            }
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.top, DS.Spacing.s12)
        }
        .padding(.top, DS.Spacing.s24 + 4)
    }

    /// Start the resolved hero session through the standard queue pipeline so
    /// XP, history, streak, rings and Game Center all record normally.
    private func startTodaySession(_ session: (source: TodaySessionSource, items: [DrillContext])) {
        guard !session.items.isEmpty, activeSession == nil else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        switch session.source {
        case .activePlan(let plan):
            let queue = TrainingQueue(
                items: session.items,
                source: plan.kind == ActivePlanKind.routine.rawValue ? .routine : .workout,
                sourceName: plan.title
            )
            pendingPlanAdvance = PendingPlanAdvance(planID: plan.id, queue: queue)
            activeSession = queue
        case .coachWorkout(let wod):
            activeSession = TrainingQueue(items: session.items, source: .workout, sourceName: wod.title)
        case .appDefault(let spec):
            activeSession = TrainingQueue(items: session.items, source: .routine, sourceName: spec.title)
        }
    }

    /// After the session cover dismisses, advance the active plan by one session
    /// if the queue that just ran was built from the plan and completed anything.
    /// XP/logging happened inside the player — this only moves the plan pointer.
    private func advancePlanIfNeeded() {
        guard let pending = pendingPlanAdvance else { return }
        pendingPlanAdvance = nil
        guard !pending.queue.completed.isEmpty,
              let plan = activePlans.first(where: { $0.id == pending.planID }),
              !plan.isFinished else { return }
        plan.currentSessionIndex += 1
        try? modelContext.save()
    }

    /// Remove the committed plan so the fallback chain takes over.
    private func clearActivePlan() {
        for plan in activePlans { modelContext.delete(plan) }
        try? modelContext.save()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    // MARK: - Siri / Shortcuts entry

    /// Launch a session built from today's unlocked recommendations. Triggered by
    /// the "Start my training" Siri shortcut.
    private func startRecommendedSession(_ vm: AcademyTodayViewModel) {
        guard activeSession == nil else { return }
        let unlocked = vm.recommendations.filter { !subscription.isLevelNumberLocked($0.level.number) }
        let items = unlocked.prefix(5).map {
            DrillContext(drill: $0.drill, level: $0.level, category: $0.category, discipline: $0.discipline)
        }
        guard !items.isEmpty else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        activeSession = TrainingQueue(items: Array(items), source: .workout, sourceName: "Recommended")
    }

    // MARK: - Combine retest nudge

    /// A dismissable prompt to re-run the full combine once the last completed
    /// combine is 28+ days old. Tapping opens the combine; dismissing hides it
    /// until the next cycle.
    @ViewBuilder
    private var combineRetestNudge: some View {
        let lastFullDay = CombineStats.lastFullCombineDay(tests: combineTests, results: combineResults)
        if retestStore.shouldShow(lastFullDay: lastFullDay), let lastFullDay {
            Card(padding: DS.Spacing.s16) {
                HStack(spacing: DS.Spacing.s12) {
                    Image(systemName: "stopwatch")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(DS.Colors.Ink.primary)
                        .frame(width: 40, height: 40)
                        .background(DS.Colors.Bg.raised)
                        .clipShape(Circle())

                    NavigationLink(value: CombineRoute()) {
                        VStack(alignment: .leading, spacing: DS.Spacing.s4) {
                            Text("Combine retest week")
                                .style(.callout)
                                .foregroundStyle(DS.Colors.Ink.primary)
                            Text("See how far you've come.")
                                .style(.micro)
                                .foregroundStyle(DS.Colors.Ink.tertiary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableButtonStyle())

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(DS.Motion.standardSpring) {
                            retestStore.dismiss(for: lastFullDay)
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(DS.Colors.Ink.quaternary)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(PressableButtonStyle())
                    .accessibilityLabel("Dismiss")
                }
            }
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.top, DS.Spacing.s16)
        }
    }

    // MARK: - Weekly recap

    /// A compact recap of this week's training, shown once the player has logged
    /// anything this week. Tapping share exports a branded image.
    @ViewBuilder
    private var weeklyRecapCard: some View {
        let recap = WeekRecap(
            sessions: sessions,
            currentXP: players.first?.xp ?? 0,
            currentStreak: players.first?.streak ?? 0
        )
        if recap.hasActivity {
            WeeklyRecapCompactCard(recap: recap) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                if let image = ShareCardRenderer.render(
                    WeeklyRecapShareCard(recap: recap, playerName: profile.displayName)
                ) {
                    recapShareImage = ShareableImage(image: image)
                }
            }
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.top, DS.Spacing.s16)
        }
    }

    // MARK: - Resume training

    /// A card surfaced at the top of Today when an interrupted multi-drill session
    /// is still resumable. Resume drops the player back in at the exact drill.
    @ViewBuilder
    private var resumeCard: some View {
        if let saved = resumeStore.session, saved.count > 1 {
            let items = saved.drillIDs.compactMap { drillIndex[$0] }
            if items.count == saved.count {
                Card(padding: DS.Spacing.s16) {
                    VStack(alignment: .leading, spacing: DS.Spacing.s12) {
                        HStack(spacing: DS.Spacing.s12) {
                            Image(systemName: "arrow.uturn.forward")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(DS.Colors.Ink.primary)
                                .frame(width: 40, height: 40)
                                .background(DS.Colors.Bg.raised)
                                .clipShape(Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text(resumeTitle(saved))
                                    .style(.title3)
                                    .foregroundStyle(DS.Colors.Ink.primary)
                                    .lineLimit(1)
                                Text("Drill \(saved.position) of \(saved.count) · pick up where you left off")
                                    .style(.micro)
                                    .foregroundStyle(DS.Colors.Ink.tertiary)
                            }
                            Spacer(minLength: DS.Spacing.s8)
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                withAnimation(DS.Motion.standardSpring) { resumeStore.clear() }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(DS.Colors.Ink.quaternary)
                                    .frame(width: 28, height: 28)
                            }
                            .buttonStyle(PressableButtonStyle())
                            .accessibilityLabel("Dismiss resume")
                        }

                        HStack(spacing: 4) {
                            ForEach(0..<saved.count, id: \.self) { idx in
                                Capsule()
                                    .fill(idx < saved.index ? Color.white : DS.Colors.Line.subtle)
                                    .frame(height: 4)
                                    .frame(maxWidth: .infinity)
                            }
                        }

                        PrimaryButton(label: "Resume training", size: .medium) {
                            resume(saved, items: items)
                        }
                    }
                }
                .padding(.horizontal, DS.Spacing.s20)
                .padding(.top, DS.Spacing.s16)
            }
        }
    }

    private func resumeTitle(_ saved: ResumeSession) -> String {
        if let name = saved.sourceName, !name.isEmpty { return name }
        switch SessionSource(rawValue: saved.source) {
        case .routine: return "Routine"
        case .workout: return "Workout"
        default: return "Training session"
        }
    }

    /// Rebuild the queue, jump to the saved drill, and present the player.
    private func resume(_ saved: ResumeSession, items: [DrillContext]) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let source = SessionSource(rawValue: saved.source) ?? .workout
        let queue = TrainingQueue(items: items, source: source, sourceName: saved.sourceName)
        queue.currentIndex = min(saved.index, items.count - 1)
        activeSession = queue
    }

    // MARK: - Coach announcement banner

    /// The newest cached announcement the player hasn't dismissed.
    private var activeAnnouncement: Announcement? {
        announcements.first { !announcementStore.isDismissed($0.id) }
    }

    /// A slim, dismissable banner showing the latest coach announcement. Tapping
    /// expands it to reveal the full message body.
    @ViewBuilder
    private var announcementBanner: some View {
        if let announcement = activeAnnouncement {
            VStack(alignment: .leading, spacing: DS.Spacing.s8) {
                HStack(spacing: DS.Spacing.s12) {
                    Image(systemName: "megaphone.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(DS.Colors.Ground.primary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(announcement.title)
                            .style(.callout)
                            .fontWeight(.bold)
                            .foregroundStyle(DS.Colors.Ground.primary)
                            .lineLimit(announcementExpanded ? nil : 1)
                        if !announcementExpanded, !announcement.body.isEmpty {
                            Text(announcement.body)
                                .style(.micro)
                                .foregroundStyle(DS.Colors.Ground.primary.opacity(0.7))
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: DS.Spacing.s8)
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(DS.Motion.standardSpring) {
                            announcementStore.dismiss(announcement.id)
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(DS.Colors.Ground.primary.opacity(0.6))
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(PressableButtonStyle())
                    .accessibilityLabel("Dismiss announcement")
                }

                if announcementExpanded, !announcement.body.isEmpty {
                    Text(announcement.body)
                        .style(.foot)
                        .foregroundStyle(DS.Colors.Ground.primary.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(DS.Spacing.s16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
            .contentShape(Rectangle())
            .onTapGesture {
                if !announcement.body.isEmpty {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(DS.Motion.standardSpring) { announcementExpanded.toggle() }
                }
            }
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.top, DS.Spacing.s16)
        }
    }

    // MARK: - Match Day

    /// Carries the assembled routine + cue line into the Match Day flow cover.
    private struct MatchDayLaunch: Identifiable {
        let id = UUID()
        let items: [DrillContext]
        let cueLine: String
    }

    /// Entry to the pre-game routine, sitting just under Quick Train.
    private func matchDayRow(_ vm: AcademyTodayViewModel) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            let items = vm.matchDayItems()
            guard !items.isEmpty else { return }
            matchDay = MatchDayLaunch(items: items, cueLine: vm.matchDayCueLine(drillIndex: drillIndex))
        } label: {
            HStack(spacing: DS.Spacing.s16) {
                Image(systemName: "soccerball.inverse")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(DS.Colors.Ink.primary)
                    .frame(width: 52, height: 52)
                    .background(DS.Colors.Bg.raised)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                    .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(DS.Colors.Line.hairline, lineWidth: 1))

                VStack(alignment: .leading, spacing: DS.Spacing.s4) {
                    Text("Game today? Get ready.")
                        .style(.title3)
                        .foregroundStyle(DS.Colors.Ink.primary)
                    Text("Match Day routine · activate, visualize, lock in")
                        .style(.micro)
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DS.Colors.Ink.quaternary)
            }
            .padding(DS.Spacing.s16)
            .background(DS.Colors.Bg.elevated)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.lg).stroke(DS.Colors.Line.hairline, lineWidth: 1))
        }
        .buttonStyle(PressableButtonStyle())
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s12)
    }

    /// Build a time-boxed queue and start it in the existing session player,
    /// logged under the "Quick Train" workout source so it fills the right rings.
    private func startQuickTrain(minutes: Int) {
        let items = viewModel.quickTrainItems(budgetSeconds: minutes * 60)
        guard !items.isEmpty else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        activeSession = TrainingQueue(items: items, source: .workout, sourceName: "Quick Train")
    }

    /// Launch the one-time 5-minute starter Quick Train for a new player, then
    /// clear the token so it never fires again.
    private func startStarterSession() {
        guard activeSession == nil, router.starterSessionToken > 0 else { return }
        router.consumeStarterSession()
        // Defer slightly so the onboarding cover finishes dismissing before the
        // session player is presented, avoiding a presentation conflict.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            startQuickTrain(minutes: 5)
        }
    }

    // MARK: - My Workouts strip

    private var myWorkoutsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s12) {
            HStack {
                Eyebrow(text: "My Workouts")
                Spacer()
                if !workouts.isEmpty {
                    NavigationLink(value: MyWorkoutsRoute()) {
                        HStack(spacing: 3) {
                            Text("See all")
                                .style(.micro)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
            .padding(.horizontal, DS.Spacing.s20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.s12) {
                    ForEach(workouts.prefix(homeWorkoutLimit)) { workout in
                        workoutChip(workout)
                    }
                    buildChip
                }
                .padding(.horizontal, DS.Spacing.s20)
            }
        }
        .padding(.top, DS.Spacing.s24 + 4)
    }

    private func workoutChip(_ workout: CustomWorkout) -> some View {
        let resolved = workout.drillIDs.compactMap { drillIndex[$0] }
        return Button {
            guard !resolved.isEmpty else { return }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            activeSession = TrainingQueue(items: resolved, source: .workout, sourceName: workout.title)
        } label: {
            VStack(alignment: .leading, spacing: DS.Spacing.s8) {
                Image(systemName: "figure.run")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(DS.Colors.Ink.primary)
                Spacer(minLength: 0)
                Text(workout.title)
                    .style(.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(DS.Colors.Ink.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(resolved.count) drills · \(estimatedSessionMinutes(forDrills: resolved.map(\.drill))) min")
                    .style(.micro)
                    .foregroundStyle(DS.Colors.Ink.tertiary)
            }
            .padding(DS.Spacing.s16)
            .frame(width: 168, height: 132, alignment: .leading)
            .background(DS.Colors.Bg.elevated)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .stroke(DS.Colors.Line.hairline, lineWidth: 1)
            )
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityHint("Start workout")
    }

    private var buildChip: some View {
        Button {
            if canCreateWorkout {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                showBuilder = true
            } else {
                subscription.presentPaywall()
            }
        } label: {
            VStack(spacing: DS.Spacing.s8) {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .bold))
                Text("Build a workout")
                    .style(.micro)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(DS.Colors.Ink.secondary)
            .frame(width: 132, height: 132)
            .background(DS.Colors.Bg.raised)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                    .foregroundStyle(DS.Colors.Line.subtle)
            )
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - Favorites hero card

    private var favoritesCard: some View {
        NavigationLink(value: FavoritesRoute()) {
            HStack(spacing: DS.Spacing.s16) {
                Image(systemName: favorites.isEmpty ? "heart" : "heart.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(DS.Colors.Ink.primary)
                    .frame(width: 52, height: 52)
                    .background(DS.Colors.Bg.raised)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                    .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(DS.Colors.Line.hairline, lineWidth: 1))

                VStack(alignment: .leading, spacing: DS.Spacing.s4) {
                    Text("Favorites")
                        .style(.title3)
                        .foregroundStyle(DS.Colors.Ink.primary)
                    Text(favorites.isEmpty
                         ? "Heart any drill, routine or workout to save it"
                         : "\(favorites.totalCount) saved · drills, routines & workouts")
                        .style(.micro)
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DS.Colors.Ink.quaternary)
            }
            .padding(DS.Spacing.s16)
            .background(DS.Colors.Bg.elevated)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.lg).stroke(DS.Colors.Line.hairline, lineWidth: 1))
        }
        .buttonStyle(PressableButtonStyle())
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s24 + 4)
    }

    // MARK: - Complete-profile banner (skipped onboarding)

    private var completeProfileBanner: some View {
        Card(padding: DS.Spacing.s16) {
            HStack(spacing: DS.Spacing.s12) {
                VStack(alignment: .leading, spacing: DS.Spacing.s4) {
                    Text("Complete your profile")
                        .style(.callout)
                        .foregroundStyle(DS.Colors.Ink.primary)
                    Text("Add your name, position and kit number.")
                        .style(.micro)
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                }
                Spacer(minLength: DS.Spacing.s8)
                NavigationLink(value: SettingsRoute()) {
                    Text("Set up")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(DS.Colors.Ground.primary)
                        .padding(.vertical, DS.Spacing.s8)
                        .padding(.horizontal, DS.Spacing.s16)
                        .background(Color.white)
                        .clipShape(Capsule())
                }
                .buttonStyle(PressableButtonStyle())
                Button {
                    withAnimation(DS.Motion.standardSpring) {
                        profile.profilePromptDismissed = true
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(DS.Colors.Ink.quaternary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel("Dismiss")
            }
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s16)
    }

    // MARK: - 1. Top Bar

    private func topBar(_ vm: AcademyTodayViewModel) -> some View {
        HStack(spacing: DS.Spacing.s12) {
            NavigationLink(value: PlayerCardRoute()) {
                Avatar(size: 36, initials: vm.playerInitials)
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel("View player card")

            Spacer()

            Image("mf-logo-white")
                .resizable()
                .scaledToFit()
                .frame(height: 20)
                .accessibilityLabel("MF Elite")

            Spacer()

            HStack(spacing: DS.Spacing.s8) {
                if auth.isSignedIn && syncEngine.pendingCount > 0 {
                    SyncStatusChip(compact: true)
                }

                if !subscription.hasFullAccess {
                    upgradeButton
                }

                NavigationLink(value: StreakRoute()) {
                    HStack(spacing: DS.Spacing.s4 + 2) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(DS.Colors.Ink.primary)
                        CountUp(value: vm.streak)
                            .font(DS.Typography.num(size: 14))
                            .foregroundStyle(DS.Colors.Ink.primary)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, DS.Spacing.s12)
                    .background(DS.Colors.Bg.raised)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.pill))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.pill)
                            .stroke(DS.Colors.Line.hairline, lineWidth: 1)
                    )
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s12)
    }

    /// Always-visible upgrade entry point for free (Trialist) players.
    private var upgradeButton: some View {
        Button {
            subscription.presentPaywall()
        } label: {
            HStack(spacing: DS.Spacing.s4 + 1) {
                Text("UPGRADE")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.2)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                Image(systemName: "arrow.up.circle")
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundStyle(DS.Colors.Ground.primary)
            .padding(.vertical, 6)
            .padding(.horizontal, DS.Spacing.s12 + 2)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.pill))
            .pillLightElevation()
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel("Upgrade to Elite")
    }

    // MARK: - 2. Salutation

    private func salutation(_ vm: AcademyTodayViewModel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: vm.formattedDate)
            Text("\(vm.greeting)\n\(vm.playerName)")
                .style(.hero)
                .foregroundStyle(DS.Colors.Ink.primary)
                .lineSpacing(-6)
                .padding(.top, DS.Spacing.s12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s24)
    }

    // MARK: - 3. Today's Standard

    private func dailyStandard(_ vm: AcademyTodayViewModel) -> some View {
        VStack(spacing: 0) {
            SlashRule()

            Eyebrow(text: "Today's Standard")
                .padding(.top, DS.Spacing.s16)

            Text("\u{201C}\(vm.dailyQuote)\u{201D}")
                .font(.system(size: 27, weight: .medium).italic())
                .foregroundStyle(DS.Colors.Ink.primary)
                .lineSpacing(7)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, DS.Spacing.s16)

            SlashRule()
                .padding(.top, DS.Spacing.s16)
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s24 + 4)
    }

    // MARK: - 4. Daily Goals + Standing

    private func goalsCard(_ vm: AcademyTodayViewModel) -> some View {
        let rank = vm.currentRank
        return Card(padding: DS.Spacing.s20) {
            HStack(alignment: .top, spacing: DS.Spacing.s20) {
                PitchRing(
                    size: 90,
                    progress: Double(vm.dailyGoalsCompleted) / Double(max(1, vm.dailyGoalsTotal)),
                    strokeWidth: 7,
                    value: "\(vm.dailyGoalsCompleted)/\(vm.dailyGoalsTotal)",
                    label: "Goals"
                )

                VStack(alignment: .leading, spacing: DS.Spacing.s8) {
                    Eyebrow(text: "Rank \(rank.numeral)")
                    Text(rank.title)
                        .style(.title3)
                        .foregroundStyle(DS.Colors.Ink.primary)

                    HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.s4) {
                        CountUp(value: vm.xp)
                            .font(DS.Typography.num(size: 30))
                            .foregroundStyle(DS.Colors.Ink.primary)
                        Text("XP")
                            .style(.foot)
                            .foregroundStyle(DS.Colors.Ink.tertiary)
                    }

                    VStack(alignment: .leading, spacing: DS.Spacing.s8) {
                        ForEach(vm.goalStates) { goal in
                            if let route = goal.drillRoute {
                                NavigationLink(value: route) {
                                    goalRow(goal)
                                }
                                .buttonStyle(PressableButtonStyle())
                            } else if let levelRoute = goal.levelRoute {
                                NavigationLink(value: levelRoute) {
                                    goalRow(goal)
                                }
                                .buttonStyle(PressableButtonStyle())
                            } else {
                                goalRow(goal)
                            }
                        }
                    }
                    .padding(.top, DS.Spacing.s8 + 2)
                }
            }
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s24 + 4)
    }

    private func goalRow(_ goal: GoalState) -> some View {
        HStack(spacing: DS.Spacing.s8) {
            RoundedRectangle(cornerRadius: 4)
                .fill(goal.done ? Color.white : Color.clear)
                .frame(width: 18, height: 18)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(goal.done ? Color.clear : DS.Colors.Line.subtle, lineWidth: 1)
                )
                .overlay {
                    if goal.done {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(DS.Colors.Ground.primary)
                    }
                }

            Text(goal.label)
                .style(.foot)
                .foregroundStyle(goal.done ? DS.Colors.Ink.primary : DS.Colors.Ink.tertiary)

            Spacer(minLength: DS.Spacing.s4)

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DS.Colors.Ink.quaternary)
        }
        .contentShape(Rectangle())
    }

    // MARK: - 4b. Today's Focus (adaptive)

    @ViewBuilder
    private func todaysFocusCard(_ vm: AcademyTodayViewModel) -> some View {
        if let focus = vm.todaysFocus {
            let locked = subscription.isLevelNumberLocked(focus.level.number)
            VStack(alignment: .leading, spacing: 0) {
                Eyebrow(text: "Today's Focus")
                    .padding(.horizontal, DS.Spacing.s20)

                Group {
                    if locked {
                        Button { subscription.presentPaywall() } label: {
                            focusCardBody(focus, locked: true)
                        }
                        .buttonStyle(PressableButtonStyle())
                    } else {
                        NavigationLink(value: DrillRoute(
                            discipline: focus.discipline,
                            category: focus.category,
                            level: focus.level,
                            drill: focus.drill
                        )) {
                            focusCardBody(focus, locked: false)
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                }
                .padding(.horizontal, DS.Spacing.s20)
                .padding(.top, DS.Spacing.s12)
            }
            .padding(.top, DS.Spacing.s24 + 4)
        }
    }

    private func focusCardBody(_ focus: PlanFocus, locked: Bool) -> some View {
        Card(padding: DS.Spacing.s20, raised: true) {
            VStack(alignment: .leading, spacing: DS.Spacing.s12) {
                HStack(spacing: DS.Spacing.s12) {
                    DisciplineMark(kind: focus.discipline.mark, size: 22)
                        .frame(width: 44, height: 44)
                        .background(DS.Colors.Bg.card)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(DS.Colors.Line.hairline, lineWidth: 1)
                        )
                    VStack(alignment: .leading, spacing: DS.Spacing.s4) {
                        Eyebrow(text: focus.headline)
                        Text(focus.drill.title)
                            .style(.title3)
                            .foregroundStyle(DS.Colors.Ink.primary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: DS.Spacing.s4)
                    Image(systemName: locked ? "lock.fill" : "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DS.Colors.Ink.quaternary)
                }

                Text(focus.reason)
                    .style(.foot)
                    .foregroundStyle(DS.Colors.Ink.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let momentum = focus.momentum {
                    HStack(spacing: DS.Spacing.s8) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(DS.Colors.Ink.primary)
                        Text(momentum)
                            .style(.micro)
                            .foregroundStyle(DS.Colors.Ink.tertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, DS.Spacing.s4)
                }
            }
            .opacity(locked ? 0.7 : 1)
        }
    }

    // MARK: - 5. Continue Your Pathway

    @ViewBuilder
    private func continuePathway(_ vm: AcademyTodayViewModel) -> some View {
        if let focus = vm.currentFocus {
            VStack(alignment: .leading, spacing: 0) {
                Eyebrow(text: "Continue Your Pathway")
                    .padding(.horizontal, DS.Spacing.s20)

                pathwayCard(vm, focus: focus)
                    .padding(.horizontal, DS.Spacing.s20)
                    .padding(.top, DS.Spacing.s12)
            }
            .padding(.top, DS.Spacing.s24 + 4)
        }
    }

    private func pathwayCard(_ vm: AcademyTodayViewModel, focus: CurrentFocus) -> some View {
        let total = focus.level.drills.count
        let done = vm.masteredDrillCount(in: focus.level)
        return Card(padding: 0, raised: true) {
            VStack(alignment: .leading, spacing: 0) {
                DisciplineHero(height: 140, disciplineName: focus.discipline.name, label: focus.discipline.name)
                    .overlay(alignment: .topLeading) {
                        DisciplineMark(kind: focus.discipline.mark, size: 28)
                            .padding(DS.Spacing.s12)
                    }

                VStack(alignment: .leading, spacing: 0) {
                    Eyebrow(text: "\(focus.discipline.name) · \(focus.category.name)")
                    Eyebrow(text: "Level \(focus.level.number)")
                        .padding(.top, DS.Spacing.s4 + 2)
                    Text(focus.level.name)
                        .style(.display)
                        .foregroundStyle(DS.Colors.Ink.primary)
                        .padding(.top, DS.Spacing.s4 + 2)
                    Text("\(done)/\(total) drills")
                        .style(.micro)
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                        .padding(.top, DS.Spacing.s8)

                    NavigationLink(value: LevelRoute(
                        discipline: focus.discipline,
                        category: focus.category,
                        level: focus.level
                    )) {
                        resumeButtonLabel(started: done > 0)
                    }
                    .buttonStyle(PressableButtonStyle())
                    .padding(.top, DS.Spacing.s16)
                }
                .padding(DS.Spacing.s16)
            }
        }
    }

    /// Styled to match PrimaryButton (medium) but usable as a NavigationLink label.
    /// Reads "Start level" until the player has mastered at least one drill.
    private func resumeButtonLabel(started: Bool) -> some View {
        Text(started ? "Resume level" : "Start level")
            .font(.system(size: 17, weight: .bold))
            .tracking(0.1)
            .foregroundStyle(DS.Colors.Ground.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.pill))
            .pillLightElevation()
    }

    // MARK: - 6. Recommended For You

    private func recommendedSection(_ vm: AcademyTodayViewModel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Eyebrow(text: "Recommended For You")
                Spacer()
                Eyebrow(text: "From \(vm.totalDrills) Drills", color: DS.Colors.Ink.quaternary)
            }
            .padding(.horizontal, DS.Spacing.s20)

            VStack(spacing: 0) {
                let recs = vm.recommendations
                ForEach(Array(recs.enumerated()), id: \.element.id) { index, rec in
                    let isLast = index == recs.count - 1
                    if vm.isTactical(rec.discipline), let lesson = vm.tacticalLessonSuggestion {
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            activeLesson = lesson
                        } label: {
                            gameIQRecommendationRow(lesson, isLast: isLast)
                        }
                        .buttonStyle(PressableButtonStyle())
                    } else {
                        let locked = subscription.isLevelNumberLocked(rec.level.number)
                        if locked {
                            Button {
                                subscription.presentPaywall()
                            } label: {
                                recommendationRow(rec, isLocked: true, isLast: isLast)
                            }
                            .buttonStyle(PressableButtonStyle())
                        } else {
                            NavigationLink(value: DrillRoute(
                                discipline: rec.discipline,
                                category: rec.category,
                                level: rec.level,
                                drill: rec.drill
                            )) {
                                recommendationRow(rec, isLast: isLast)
                            }
                            .buttonStyle(PressableButtonStyle())
                        }
                    }
                }
            }
            .padding(.top, DS.Spacing.s12)
        }
        .padding(.top, DS.Spacing.s24 + 4)
    }

    /// A Tactical recommendation row that opens a Game IQ lesson instead of a drill.
    private func gameIQRecommendationRow(_ lesson: GameIQLesson, isLast: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: DS.Spacing.s16) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(DS.Colors.Ink.primary)
                    .frame(width: 44, height: 44)
                    .background(DS.Colors.Bg.card)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(DS.Colors.Line.hairline, lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: DS.Spacing.s4) {
                    Text(lesson.title)
                        .style(.title3)
                        .foregroundStyle(DS.Colors.Ink.primary)
                    Text("Tactical · Game IQ: \(lesson.title)")
                        .style(.micro)
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                        .lineLimit(1)
                }

                Spacer(minLength: DS.Spacing.s8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DS.Colors.Ink.quaternary)
            }
            .padding(.vertical, DS.Spacing.s12 + 2)

            if !isLast {
                Hairline()
            }
        }
        .padding(.horizontal, DS.Spacing.s20)
        .contentShape(Rectangle())
    }

    private func recommendationRow(_ rec: Recommendation, isLocked: Bool = false, isLast: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: DS.Spacing.s16) {
                DisciplineMark(kind: rec.discipline.mark, size: 22)
                    .frame(width: 44, height: 44)
                    .background(DS.Colors.Bg.card)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(DS.Colors.Line.hairline, lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: DS.Spacing.s4) {
                    Text(rec.drill.title)
                        .style(.title3)
                        .foregroundStyle(DS.Colors.Ink.primary)
                    Text("\(rec.discipline.name) · \(rec.reason)")
                        .style(.micro)
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                }

                Spacer(minLength: DS.Spacing.s8)

                Image(systemName: isLocked ? "lock.fill" : "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DS.Colors.Ink.quaternary)
            }
            .opacity(isLocked ? 0.6 : 1)
            .padding(.vertical, DS.Spacing.s12 + 2)

            if !isLast {
                Hairline()
            }
        }
        .padding(.horizontal, DS.Spacing.s20)
        .contentShape(Rectangle())
    }
}

#Preview {
    AcademyTodayView()
        .preferredColorScheme(.dark)
        .environment(SubscriptionService.shared)
        .modelContainer(for: [
            Discipline.self, Category.self, MasteryLevel.self,
            Drill.self, DrillProgress.self, PlayerState.self
        ])
}
