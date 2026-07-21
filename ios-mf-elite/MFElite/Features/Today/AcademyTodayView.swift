//
// AcademyTodayView.swift
// MFElite
//
// Tab 1 — the daily launchpad: greeting, today's session, goals, and match day.
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
 @Query(sort: \GameIQLesson.sortIndex) private var gameIQLessons: [GameIQLesson]
 @Query(sort: \GameEntry.date) private var games: [GameEntry]
 @Query(sort: \Announcement.createdAt, order: .reverse) private var announcements: [Announcement]
 @Query(sort: \CoachWorkout.createdAt, order: .reverse) private var coachWorkouts: [CoachWorkout]
 @Query private var activePlans: [ActivePlan]
 @Environment(SubscriptionService.self) private var subscription
 @Environment(\.modelContext) private var modelContext
 @State private var profile = PlayerProfileStore.shared
 @State private var workoutIndexCache = TodayWorkoutIndexCache()
 @State private var activeSession: TrainingQueue?
 @State private var router = AppActionRouter.shared
 @State private var matchDay: MatchDayLaunch?
 @State private var announcementStore = AnnouncementStore.shared
 @State private var announcementExpanded = false
 @State private var announcementPopup: Announcement?
 @State private var resumeStore = ResumeStore.shared
 @State private var syncEngine = SyncEngine.shared
 @State private var auth = SupabaseAuth.shared
 @State private var appeared = false
 @State private var pendingPlanAdvance: PendingPlanAdvance?
 @State private var showChangePlanConfirm = false
 @State private var coachFocusText: String = ""

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

 /// Drill IDs logged at least once today, for the "done" checkmarks on the
 /// Today's Session drill list.
 private var loggedTodayIDs: Set<String> {
 let cal = Calendar.current
 return Set(
 sessions
 .filter { cal.isDateInToday($0.completedAt) }
 .map(\.drillID)
 )
 }

 private var viewModel: AcademyTodayViewModel {
 AcademyTodayViewModel(
 disciplines: disciplines,
 xp: players.first?.xp ?? 0,
 rankXP: players.first?.rankXP ?? 0,
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
 salutation(vm).entrance(0, appeared: appeared)
 if todaysGame != nil {
 // Match prep outranks training on game day.
 matchDayCard(vm).entrance(1, appeared: appeared)
 }
 todaySessionCard.entrance(2, appeared: appeared)
 goalsCard(vm).entrance(3, appeared: appeared)
 nextGameChip.entrance(4, appeared: appeared)
 announcementBanner.entrance(5, appeared: appeared)
 coachFocusCard.entrance(5, appeared: appeared)
 resumeCard.entrance(6, appeared: appeared)
 if profile.shouldPromptProfileCompletion {
 completeProfileBanner.entrance(7, appeared: appeared)
 }
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
 .navigationDestination(for: MyGamesRoute.self) { _ in
 MyGamesView()
 }
 }
 .fullScreenCover(item: $activeSession, onDismiss: advancePlanIfNeeded) { queue in
 SessionPlayerView(queue: queue)
 }
 .fullScreenCover(item: $matchDay) { launch in
 MatchDayFlowView(items: launch.items, cueLine: launch.cueLine)
 }
 .task {
 await CoachWorkoutFeed.refresh(context: modelContext)
 await AnnouncementFeed.refresh(context: modelContext)
 await CurriculumOverlay.applyAndMaybeRefresh(context: modelContext)
 maybePresentAnnouncementPopup()
 await refreshCoachFocus()
 }
 .alert(
 announcementPopup?.title ?? "Team announcement",
 isPresented: Binding(
 get: { announcementPopup != nil },
 set: { showing in
 if !showing {
 if let a = announcementPopup { announcementStore.markPopped(a.id) }
 announcementPopup = nil
 }
 }
 ),
 presenting: announcementPopup
 ) { _ in
 Button("Got it", role: .cancel) {}
 } message: { announcement in
 if !announcement.body.isEmpty { Text(announcement.body) }
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
 // Free players only rotate through routines they can actually start;
 // if the filter empties the list, fall back to the unfiltered catalog.
 let all = RoutineCatalog.all
 let unlocked = all.filter { spec in
 !spec.isLocked(hasFullAccess: subscription.hasFullAccess, resolve: { index[$0] })
 }
 let specs = unlocked.isEmpty ? all : unlocked
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

 DrillSequenceList(
 resolved: session.items.map {
 ResolvedDrill(drill: $0.drill, level: $0.level, category: $0.category, discipline: $0.discipline)
 },
 loggedToday: loggedTodayIDs,
 onStart: { idx in startTodaySession(session, from: idx) }
 )

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
 /// `startIndex` lets a tapped drill row begin the session partway through.
 private func startTodaySession(_ session: (source: TodaySessionSource, items: [DrillContext]), from startIndex: Int = 0) {
 guard !session.items.isEmpty, activeSession == nil else { return }
 UIImpactFeedbackGenerator(style: .medium).impactOccurred()
 let queue: TrainingQueue
 switch session.source {
 case .activePlan(let plan):
 queue = TrainingQueue(
 items: session.items,
 source: plan.kind == ActivePlanKind.routine.rawValue ? .routine : .workout,
 sourceName: plan.title
 )
 pendingPlanAdvance = PendingPlanAdvance(planID: plan.id, queue: queue)
 case .coachWorkout(let wod):
 queue = TrainingQueue(items: session.items, source: .workout, sourceName: wod.title)
 case .appDefault(let spec):
 queue = TrainingQueue(items: session.items, source: .routine, sourceName: spec.title)
 }
 queue.currentIndex = min(max(0, startIndex), session.items.count - 1)
 activeSession = queue
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

 /// Presents the one-time pop-up alert for the newest announcement the player
 /// hasn't seen as a pop-up yet. The dismissable banner still shows afterwards.
 private func maybePresentAnnouncementPopup() {
 guard let announcement = activeAnnouncement,
 !announcementStore.hasPopped(announcement.id) else { return }
 announcementPopup = announcement
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

 // MARK: - Coach's focus

 /// The coach-set focus for this player, shown once a coach fills it in.
 @ViewBuilder
 private var coachFocusCard: some View {
 if !coachFocusText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
 Card(padding: DS.Spacing.s16) {
 VStack(alignment: .leading, spacing: DS.Spacing.s8) {
 HStack(spacing: DS.Spacing.s8) {
 Image(systemName: "target")
 .font(.system(size: 13, weight: .bold))
 .foregroundStyle(DS.Colors.Gold.base)
 Eyebrow(text: "Coach's Focus")
 }
 Text(coachFocusText)
 .style(.callout)
 .foregroundStyle(DS.Colors.Ink.primary)
 .fixedSize(horizontal: false, vertical: true)
 }
 }
 .padding(.horizontal, DS.Spacing.s20)
 .padding(.top, DS.Spacing.s16)
 }
 }

 /// Fetch this player's own coach_focus once per launch (lightweight GET).
 private func refreshCoachFocus() async {
 guard let uid = auth.userID else { return }
 if let rows = await SupabaseClient.shared.get(
 table: "player_profiles",
 query: [
 URLQueryItem(name: "id", value: "eq.\(uid)"),
 URLQueryItem(name: "select", value: "coach_focus"),
 URLQueryItem(name: "limit", value: "1")
 ]
 ), let focus = rows.first?["coach_focus"] as? String {
 coachFocusText = focus
 }
 }

 // MARK: - Match Day

 /// Carries the assembled routine + cue line into the Match Day flow cover.
 private struct MatchDayLaunch: Identifiable {
 let id = UUID()
 let items: [DrillContext]
 let cueLine: String
 }

 /// The scheduled game happening today, if any — drives the Match Day card.
 private var todaysGame: GameEntry? {
 games.first { Calendar.current.isDateInToday($0.date) }
 }

 /// The earliest scheduled game from today onward, for the next-game chip.
 private var nextGame: GameEntry? {
 let start = Calendar.current.startOfDay(for: Date())
 return games.first { $0.date >= start }
 }

 private var matchDayTitle: String {
 if let opponent = todaysGame?.opponent, !opponent.isEmpty {
 return "Game today vs \(opponent)"
 }
 return "Game today. Lock in."
 }

 /// Schedule-driven Match Day card — rendered above the hero card on game
 /// day only. Launches the existing Match Day flow exactly as before.
 private func matchDayCard(_ vm: AcademyTodayViewModel) -> some View {
 Card(padding: DS.Spacing.s20, raised: true) {
 VStack(alignment: .leading, spacing: DS.Spacing.s12) {
 HStack(alignment: .top) {
 HStack(spacing: DS.Spacing.s8) {
 Image(systemName: "soccerball.inverse")
 .font(.system(size: 14, weight: .bold))
 .foregroundStyle(DS.Colors.Ink.primary)
 Eyebrow(text: "Match Day")
 }
 Spacer(minLength: DS.Spacing.s8)
 NavigationLink(value: MyGamesRoute()) {
 Text("My Games")
 .style(.micro)
 .foregroundStyle(DS.Colors.Ink.tertiary)
 .underline()
 .frame(minHeight: 28)
 .contentShape(Rectangle())
 }
 .buttonStyle(PressableButtonStyle())
 .accessibilityLabel("Edit game schedule")
 }

 Text(matchDayTitle)
 .style(.title2)
 .foregroundStyle(DS.Colors.Ink.primary)
 .fixedSize(horizontal: false, vertical: true)

 Text("Match Day routine · activate, visualize, lock in")
 .style(.micro)
 .foregroundStyle(DS.Colors.Ink.tertiary)

 PrimaryButton(label: "Start Match Day prep") {
 launchMatchDay(vm)
 }
 .padding(.top, DS.Spacing.s4)
 }
 }
 .padding(.horizontal, DS.Spacing.s20)
 .padding(.top, DS.Spacing.s24)
 }

 private func launchMatchDay(_ vm: AcademyTodayViewModel) {
 UIImpactFeedbackGenerator(style: .light).impactOccurred()
 let items = vm.matchDayItems()
 guard !items.isEmpty else { return }
 matchDay = MatchDayLaunch(items: items, cueLine: vm.matchDayCueLine(drillIndex: drillIndex))
 }

 /// One compact line under the goals strip: the next game when it's within
 /// 7 days, or the add-your-schedule discovery line when nothing is planned.
 @ViewBuilder
 private var nextGameChip: some View {
 if todaysGame == nil {
 if let game = nextGame {
 let cal = Calendar.current
 let days = cal.dateComponents(
 [.day],
 from: cal.startOfDay(for: Date()),
 to: cal.startOfDay(for: game.date)
 ).day ?? Int.max
 if days <= 7 {
 gameScheduleLine(icon: "calendar", text: nextGameLabel(game))
 }
 } else {
 gameScheduleLine(icon: "calendar.badge.plus", text: "Add your game schedule")
 }
 }
 }

 private func nextGameLabel(_ game: GameEntry) -> String {
 let day = game.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
 return game.opponent.isEmpty
 ? "Next game: \(day)"
 : "Next game: \(day) · vs \(game.opponent)"
 }

 private func gameScheduleLine(icon: String, text: String) -> some View {
 NavigationLink(value: MyGamesRoute()) {
 HStack(spacing: DS.Spacing.s12) {
 Image(systemName: icon)
 .font(.system(size: 14, weight: .semibold))
 .foregroundStyle(DS.Colors.Ink.primary)
 Text(text)
 .style(.foot)
 .foregroundStyle(DS.Colors.Ink.secondary)
 .lineLimit(1)
 Spacer(minLength: DS.Spacing.s8)
 Image(systemName: "chevron.right")
 .font(.system(size: 12, weight: .semibold))
 .foregroundStyle(DS.Colors.Ink.quaternary)
 }
 .padding(.vertical, DS.Spacing.s12)
 .padding(.horizontal, DS.Spacing.s16)
 .background(DS.Colors.Bg.elevated)
 .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
 .overlay(RoundedRectangle(cornerRadius: DS.Radius.lg).stroke(DS.Colors.Line.hairline, lineWidth: 1))
 .contentShape(Rectangle())
 }
 .buttonStyle(PressableButtonStyle())
 .padding(.horizontal, DS.Spacing.s20)
 .padding(.top, DS.Spacing.s16)
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

