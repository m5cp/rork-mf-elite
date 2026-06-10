//
//  MFAppIntents.swift
//  MFElite
//
//  Siri & Shortcuts entry points. Two voice/Shortcuts actions:
//   • "Start my training" — opens the app and launches today's recommended session.
//   • "Open today's plan" — opens the app to the daily training home.
//  Both run on the main actor and route through `AppActionRouter`, which the UI
//  observes. Registered via `MFAppShortcuts` at launch so Siri finds them.
//

import AppIntents

/// Opens MF Elite and immediately launches the recommended training session.
struct StartTrainingIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Training"
    static var description = IntentDescription("Opens MF Elite and starts today's recommended session.")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AppActionRouter.shared.requestStartTraining()
        return .result()
    }
}

/// Opens MF Elite to the daily training home (the Today tab).
struct OpenTodayIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Today's Plan"
    static var description = IntentDescription("Opens MF Elite to today's training plan.")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AppActionRouter.shared.requestOpenToday()
        return .result()
    }
}

/// Registers the shortcuts so they appear in Siri, Spotlight, and the Shortcuts
/// app without any user setup.
struct MFAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartTrainingIntent(),
            phrases: [
                "Start my training in \(.applicationName)",
                "Start training with \(.applicationName)",
                "Start my \(.applicationName) session",
                "Train with \(.applicationName)"
            ],
            shortTitle: "Start Training",
            systemImageName: "figure.run"
        )
        AppShortcut(
            intent: OpenTodayIntent(),
            phrases: [
                "Open today's plan in \(.applicationName)",
                "Show my \(.applicationName) plan",
                "Open \(.applicationName) today"
            ],
            shortTitle: "Today's Plan",
            systemImageName: "calendar"
        )
    }

    static var shortcutTileColor: ShortcutTileColor = .grayBlue
}
