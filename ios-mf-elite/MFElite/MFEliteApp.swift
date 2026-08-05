//
//  MFEliteApp.swift
//  MFElite
//

import SwiftUI
import SwiftData
import AppIntents

@main
struct MFEliteApp: App {
    let container: ModelContainer
    @Environment(\.scenePhase) private var scenePhase
    @State private var profileStore = PlayerProfileStore.shared
    @State private var openingDone = false

    init() {
        SubscriptionService.shared.configure()
        GameCenterService.shared.authenticate()
        MFAppShortcuts.updateAppShortcutParameters()
        let schema = Schema([
            Discipline.self,
            Category.self,
            MasteryLevel.self,
            Drill.self,
            DrillProgress.self,
            PlayerState.self,
            SessionLogEntry.self,
            CustomWorkout.self,
            ProgramEnrollment.self,
            DrillNote.self,
            CombineTest.self,
            CombineResult.self,
            GameIQLesson.self,
            PendingOp.self,
            CoachWorkout.self,
            CurriculumEditCache.self,
            Announcement.self,
            ActivePlan.self,
            GameEntry.self,
            DrillResult.self,
            WorkoutRecord.self
        ])
        container = MFEliteApp.makeContainer(for: schema)
        SeedData.seedIfNeeded(context: container.mainContext)
        CombineSeed.seedIfNeeded(context: container.mainContext)
        GameIQSeed.seedIfNeeded(context: container.mainContext)
        SyncEngine.shared.configure(context: container.mainContext)
        ShareXPService.shared.configure(context: container.mainContext)
        XPStoreService.shared.configure(context: container.mainContext)
        WatchSyncBridge.shared.configure(context: container.mainContext)
        SupportAdjustments.shared.configure(context: container.mainContext)
    }

    /// True when the on-disk store could not be opened and this session is
    /// running against a temporary in-memory store. Nothing recorded now will
    /// survive, so the UI warns the player instead of quietly losing it.
    static private(set) var isRunningOnFallbackStore = false

    /// Builds the SwiftData container.
    ///
    /// This used to delete the store outright on ANY open error — including a
    /// transient I/O failure, not just genuine corruption — taking XP, streak,
    /// the whole session history, custom workouts, drill notes, combine results
    /// and watch workouts with it, silently and with no backup. A store that
    /// fails to open once is very often fine on the next launch, so destroying
    /// it is the worst available response.
    ///
    /// Now: retry once, then fall back to a temporary in-memory store and flag
    /// it. The on-disk file is left untouched so a later launch (or an app
    /// update carrying the right migration) can still recover it, and a player
    /// who signs in can restore from the cloud. The store is only ever removed
    /// by explicit user action.
    private static func makeContainer(for schema: Schema) -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // One retry — transient failures (a file still locked by a
            // terminating previous instance, momentary I/O pressure) clear.
            if let container = try? ModelContainer(for: schema, configurations: [configuration]) {
                return container
            }

            // Preserve the unreadable store for diagnosis and later recovery
            // rather than deleting it.
            archiveUnreadableStore()
            isRunningOnFallbackStore = true

            let memoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            // swiftlint:disable:next force_try
            return try! ModelContainer(for: schema, configurations: [memoryConfig])
        }
    }

    /// Copies the unreadable store aside (once) so the data still exists on
    /// disk if it can be recovered later. Never deletes the original.
    private static func archiveUnreadableStore() {
        let fileManager = FileManager.default
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        let backupDirectory = appSupport.appendingPathComponent("UnreadableStore", isDirectory: true)
        guard !fileManager.fileExists(atPath: backupDirectory.path) else { return }
        try? fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
        for name in ["default.store", "default.store-shm", "default.store-wal"] {
            let source = appSupport.appendingPathComponent(name)
            guard fileManager.fileExists(atPath: source.path) else { continue }
            try? fileManager.copyItem(at: source, to: backupDirectory.appendingPathComponent(name))
        }
    }

    private var showOnboarding: Bool {
        !profileStore.hasCompletedOnboarding
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                MainTabView()
                    // Rebuild the tree when the accent changes so every token
                    // consumer repaints immediately (live accent switching).
                    .id(profileStore.accentID)
                    .preferredColorScheme(.dark)
                    .fullScreenCover(isPresented: .constant(showOnboarding && openingDone)) {
                        OnboardingView {
                            // Onboarding marks completion in PlayerProfileStore,
                            // which flips `showOnboarding` and dismisses the cover.
                        }
                        .modelContainer(container)
                    }
                    .onAppear {
                        // No notification permission request on launch — the soft
                        // pre-permission sheet is shown after the first logged drill.
                        // If already authorized, keep the daily reminder scheduled.
                        NotificationService.shared.scheduleDailyReminderIfAuthorized()
                        reconcileStreak()
                        backfillMasteryDates()
                        profileStore.incrementSession()
                        KeyboardWarmup.run()
                        submitTotalXPToGameCenter()
                        WidgetBridge.refresh(context: container.mainContext)
                        WatchSyncBridge.shared.refreshAndPush()
                        Task { await AppConfigStore.shared.refresh() }
                        Task { await SupportAdjustments.shared.applyPending() }
                    }

                if !openingDone {
                    MFEliteOpeningView {
                        withAnimation(.easeOut(duration: 0.45)) { openingDone = true }
                    }
                    .transition(.opacity)
                    .zIndex(1)
                }
            }
            .preferredColorScheme(.dark)
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                scheduleStreakRiskIfNeeded()
            } else if newPhase == .active {
                reconcileStreak()
                SyncEngine.shared.onForeground()
                WatchSyncBridge.shared.refreshAndPush()
                Task { await AppConfigStore.shared.refresh() }
                Task { await SupportAdjustments.shared.applyPending() }
            }
        }
    }

    /// One-time backfill for `DrillProgress.masteredAt`, which is nil for every
    /// drill mastered before it existed.
    ///
    /// Without this, the parent report would tell every existing family their
    /// child mastered zero drills this month and grade them a C — the report is
    /// exported as the PDF that goes home. `lastLoggedAt` is the best available
    /// approximation of when mastery happened, and it is always in the past for
    /// these rows, so they correctly fall outside the current month unless the
    /// drill really was trained recently.
    private func backfillMasteryDates() {
        let key = "MF_MASTERED_AT_BACKFILL_DONE"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        let context = container.mainContext
        let descriptor = FetchDescriptor<DrillProgress>(
            predicate: #Predicate { $0.isMastered == true && $0.masteredAt == nil }
        )
        // Only mark this done once it actually succeeded. Setting the flag
        // unconditionally meant a single transient SwiftData failure would skip
        // the backfill permanently for that install — and the parent report is
        // exactly what this protects.
        guard let rows = try? context.fetch(descriptor) else { return }
        for row in rows {
            row.masteredAt = row.lastLoggedAt ?? Date.distantPast
        }
        do {
            try context.save()
        } catch {
            return  // try again next launch
        }
        UserDefaults.standard.set(true, forKey: key)
    }

    /// Settle the streak against today's date on launch and on every return to
    /// the foreground, spending streak freezes to cover missed days and
    /// breaking the streak when they can't cover it. Without this the number
    /// only ever moved upward, so a player who stopped training for a month
    /// still saw their old streak waiting for them.
    private func reconcileStreak() {
        let context = container.mainContext
        guard let player = try? context.fetch(FetchDescriptor<PlayerState>()).first else { return }
        guard StreakEngine.reconcile(player) else { return }
        try? context.save()
        SyncEngine.shared.enqueuePlayerState(player)
        WidgetBridge.refresh(context: context)
        WatchSyncBridge.shared.refreshAndPush()
    }

    /// Push the player's current total XP to Game Center once authenticated, so
    /// the leaderboards reflect progress earned while signed out.
    private func submitTotalXPToGameCenter() {
        let context = container.mainContext
        guard let player = try? context.fetch(FetchDescriptor<PlayerState>()).first else { return }
        GameCenterService.shared.submitXP(player.xp)
    }

    /// When backgrounding, warn the player tonight if they haven't trained today.
    /// If they HAVE trained, keep the streak defended for tomorrow evening
    /// instead of leaving no warning queued at all.
    private func scheduleStreakRiskIfNeeded() {
        let context = container.mainContext
        guard let player = try? context.fetch(FetchDescriptor<PlayerState>()).first else { return }
        let trainedToday = Calendar.current.isDateInToday(player.lastTrainedDate ?? .distantPast)
        if trainedToday {
            NotificationService.shared.scheduleStreakRiskNextEvening(streak: player.streak)
        } else {
            NotificationService.shared.scheduleStreakRisk(streak: player.streak)
        }
    }
}
