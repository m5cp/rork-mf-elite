//
//  DrillLiveActivityIntents.swift
//  MFEliteShared
//
//  Interactive App Intents wired to the Live Activity's pause and skip buttons.
//  As LiveActivityIntents, these run in the app's process, so they simply post
//  a command the running drill player picks up.
//

import AppIntents

nonisolated struct DrillPauseToggleIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Pause or resume drill"
    static var description = IntentDescription("Pause or resume the running drill timer.")

    func perform() async throws -> some IntentResult {
        DrillLiveActivityCommandBus.post(.pauseToggle)
        return .result()
    }
}

nonisolated struct DrillSkipSetIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Skip set"
    static var description = IntentDescription("Skip the current set and move on.")

    func perform() async throws -> some IntentResult {
        DrillLiveActivityCommandBus.post(.skip)
        return .result()
    }
}
