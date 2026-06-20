//
//  LiveActivityController.swift
//  MFElite
//
//  Owns the lifecycle of the drill timer Live Activity (lock screen + Dynamic
//  Island). The drill player starts it when a guided timer begins, updates it on
//  every phase change, and ends it when the drill is logged or the session ends.
//

import Foundation
import ActivityKit

@MainActor
final class LiveActivityController {
    static let shared = LiveActivityController()

    private var activity: Activity<DrillActivityAttributes>?

    private init() {}

    /// Whether the user has Live Activities enabled for this app.
    private var isEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    /// Start (or restart) the Live Activity for a session.
    func start(sessionName: String, state: DrillActivityAttributes.ContentState) {
        guard isEnabled else { return }
        // Replace any stale activity from a previous session.
        if activity != nil {
            update(state)
            return
        }
        let attributes = DrillActivityAttributes(sessionName: sessionName)
        do {
            activity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil),
                pushType: nil
            )
        } catch {
            activity = nil
        }
    }

    /// Push a new state to the running activity.
    func update(_ state: DrillActivityAttributes.ContentState) {
        guard let activity else { return }
        Task {
            await activity.update(.init(state: state, staleDate: nil))
        }
    }

    /// End and dismiss the activity immediately.
    func end() {
        guard let activity else { return }
        let current = activity
        self.activity = nil
        Task {
            await current.end(nil, dismissalPolicy: .immediate)
        }
    }
}
