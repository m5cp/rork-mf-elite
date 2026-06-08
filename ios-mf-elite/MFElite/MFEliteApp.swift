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

    init() {
        SubscriptionService.shared.configure()
        let schema = Schema([
            Discipline.self,
            Category.self,
            MasteryLevel.self,
            Drill.self,
            DrillProgress.self,
            PlayerState.self
        ])
        container = MFEliteApp.makeContainer(for: schema)
        SeedData.seedIfNeeded(context: container.mainContext)
    }

    /// Builds the SwiftData container. If the on-disk store can't be opened
    /// (for example after a model change that SwiftData can't auto-migrate),
    /// the local store is reset and rebuilt so the app always launches. User
    /// progress is re-derived from the bundled curriculum and re-seeding.
    private static func makeContainer(for schema: Schema) -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // Migration / store failure — wipe the store and reset the seed marker.
            resetLocalStore()
            UserDefaults.standard.removeObject(forKey: "MF_SEEDED_DRILL_COUNT")
            do {
                return try ModelContainer(for: schema, configurations: [configuration])
            } catch {
                // Last resort: in-memory store keeps the app usable this session.
                let memoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                // swiftlint:disable:next force_try
                return try! ModelContainer(for: schema, configurations: [memoryConfig])
            }
        }
    }

    /// Removes the default SwiftData store files (`.store`, `.store-shm`, `.store-wal`).
    private static func resetLocalStore() {
        let fileManager = FileManager.default
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        let storeNames = ["default.store", "default.store-shm", "default.store-wal"]
        for name in storeNames {
            let url = appSupport.appendingPathComponent(name)
            try? fileManager.removeItem(at: url)
        }
    }

    private var showOnboarding: Bool {
        !profileStore.hasCompletedOnboarding
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
                .preferredColorScheme(.dark)
                .onAppear {
                    // No notification permission request on launch — the soft
                    // pre-permission sheet is shown after the first logged drill.
                    // If already authorized, keep the daily reminder scheduled.
                    NotificationService.shared.scheduleDailyReminderIfAuthorized()
                    profileStore.incrementSession()
                    KeyboardWarmup.run()
                }
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                scheduleStreakRiskIfNeeded()
            }
        }
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
