//
//  CombineRetestStore.swift
//  MFElite
//
//  Tracks dismissal of the "Combine retest week" nudge so it stays hidden for
//  the current 28-day cycle. Dismissal is keyed to the last full-combine day —
//  once the player completes a new full combine that day changes, so a future
//  cycle can surface the nudge again. Persisted in UserDefaults.
//

import Foundation

@MainActor
@Observable
final class CombineRetestStore {
    static let shared = CombineRetestStore()

    private let defaults = UserDefaults.standard
    private enum Key { static let dismissedDay = "mf.combine.retestDismissedDay" }

    /// How many days must pass since the last full combine before nudging.
    private let cycleDays = 28

    /// Start-of-day of the full-combine cycle the player already dismissed.
    private var dismissedDay: Date?

    private init() {
        if let stored = defaults.object(forKey: Key.dismissedDay) as? Double {
            dismissedDay = Date(timeIntervalSinceReferenceDate: stored)
        }
    }

    /// Whether to surface the retest nudge: a full combine exists, its last day
    /// is 28+ days ago, and the player hasn't dismissed this cycle's nudge.
    func shouldShow(lastFullDay: Date?) -> Bool {
        guard let lastFullDay else { return false }
        let calendar = Calendar.current
        let from = calendar.startOfDay(for: lastFullDay)
        let to = calendar.startOfDay(for: Date())
        let days = calendar.dateComponents([.day], from: from, to: to).day ?? 0
        guard days >= cycleDays else { return false }
        if let dismissedDay, calendar.isDate(dismissedDay, inSameDayAs: lastFullDay) {
            return false
        }
        return true
    }

    /// Hide the nudge for the cycle anchored on `lastFullDay`.
    func dismiss(for lastFullDay: Date) {
        let day = Calendar.current.startOfDay(for: lastFullDay)
        dismissedDay = day
        defaults.set(day.timeIntervalSinceReferenceDate, forKey: Key.dismissedDay)
    }
}
