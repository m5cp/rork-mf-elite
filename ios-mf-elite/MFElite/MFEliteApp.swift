//
//  MFEliteApp.swift
//  MFElite
//

import SwiftUI
import SwiftData

@main
struct MFEliteApp: App {
    let container: ModelContainer
    @Environment(\.scenePhase) private var scenePhase
    @State private var profileStore = PlayerProfileStore.shared
    @State private var auth = AuthService.shared

    init() {
        SubscriptionService.shared.configure()
        do {
            let schema = Schema([
                Discipline.self,
                Category.self,
                MasteryLevel.self,
                Drill.self,
                DrillProgress.self,
                PlayerState.self
            ])
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            container = try ModelContainer(for: schema, configurations: [configuration])
            SeedData.seedIfNeeded(context: container.mainContext)
        } catch {
            fatalError("Failed to configure ModelContainer: \(error)")
        }
    }

    private var showOnboarding: Bool {
        // Wait until the session restore finishes so returning authenticated
        // users don't see a flash of onboarding on launch.
        !auth.isLoading && !auth.isAuthenticated && !profileStore.hasCompletedOnboarding
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .preferredColorScheme(.dark)
                .fullScreenCover(isPresented: .constant(showOnboarding)) {
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
                    profileStore.incrementSession()
                    Task { await bootstrapBackend() }
                }
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                scheduleStreakRiskIfNeeded()
            }
        }
    }

    /// Restore the Rork Auth session, then (if signed in) pull the latest
    /// curriculum and player progress from Supabase. The local SwiftData seed is
    /// always present as an offline-first fallback, so this is purely additive.
    private func bootstrapBackend() async {
        let context = container.mainContext
        await AuthService.shared.checkSession()
        guard AuthService.shared.isAuthenticated else { return }
        await CurriculumSyncService.shared.syncCurriculum(context: context)
        await ProgressSyncService.shared.pullPlayerState(context: context)
        await ProgressSyncService.shared.pullPlayerProgress(context: context)
    }

    /// When backgrounding, warn the player tonight if they haven't trained today.
    private func scheduleStreakRiskIfNeeded() {
        let context = container.mainContext
        guard let player = try? context.fetch(FetchDescriptor<PlayerState>()).first else { return }
        let trainedToday = Calendar.current.isDateInToday(player.lastTrainedDate ?? .distantPast)
        if trainedToday {
            NotificationService.shared.cancelStreakRisk()
        } else {
            NotificationService.shared.scheduleStreakRisk(streak: player.streak)
        }
    }
}
