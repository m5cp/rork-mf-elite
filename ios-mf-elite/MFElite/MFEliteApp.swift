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

    init() {
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

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .preferredColorScheme(.dark)
                .onAppear {
                    NotificationService.shared.requestPermission { granted in
                        if granted {
                            NotificationService.shared.scheduleDailyReminder()
                        }
                    }
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
