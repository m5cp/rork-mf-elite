//
//  AppActionRouter.swift
//  MFElite
//
//  Lightweight, app-wide router for external entry points (Siri / Shortcuts).
//  Intents set a pending request here; the UI observes it and reacts — switching
//  tabs and, for "start training", launching the recommended session. State is
//  transient (not persisted) and always resolved on the main actor.
//

import Observation

@MainActor
@Observable
final class AppActionRouter {
    static let shared = AppActionRouter()

    /// A tab to switch to on next UI update, then cleared.
    var pendingTab: AppTab?

    /// Bumped each time "start training" is requested, so the Today screen can
    /// launch a fresh recommended session even if it's already visible.
    private(set) var startTrainingToken = 0

    private init() {}

    /// Open the Today tab and launch the recommended session.
    func requestStartTraining() {
        pendingTab = .today
        startTrainingToken += 1
    }

    /// Open the Today tab (the training home) without auto-launching a session.
    func requestOpenToday() {
        pendingTab = .today
    }
}
