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
            ZStack {
                MainTabView()
                    .preferredColorScheme(.dark)
                    .fullScreenCover(isPresented: .constant(showOnboarding)) {
                        OnboardingView {
                            // Onboarding marks completion in PlayerProfileStore,
                            // which flips `showOnboarding` and dismisses the cover.
                        }
                        .modelContainer(container)
                    }

                // Hold a launch splash over everything until the session
                // restore finishes, so the home screen never flashes before
                // onboarding (new users) or before content loads (returning users).
                if auth.isLoading {
                    LaunchSplashView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: auth.isLoading)
            .preferredColorScheme(.dark)
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

/// Pure-black launch splash held over the app until the auth session restore
/// finishes, preventing the home screen from flashing before onboarding.
private struct LaunchSplashView: View {
    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            DiagonalStripes(opacity: 0.4)

            Image("mf-logo-white")
                .resizable()
                .scaledToFit()
                .frame(height: 200)
                .opacity(appeared ? 1 : 0)
                .accessibilityLabel("MF Elite")
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8)) { appeared = true }
        }
    }
}
