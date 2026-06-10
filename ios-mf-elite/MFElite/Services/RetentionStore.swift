//
//  RetentionStore.swift
//  MFElite
//
//  Local, on-device gate for the retention surfaces:
//   • the weekly "Your week in review" recap (shown once per completed week), and
//   • the comeback / welcome-back moment (shown once per lapse).
//  All state lives in UserDefaults so the rules survive relaunch.
//

import Foundation
import Observation

@MainActor
@Observable
final class RetentionStore {
    static let shared = RetentionStore()

    private let defaults = UserDefaults.standard

    private enum Key {
        /// Reference-date timestamp of the Monday whose recap has been seen.
        static let lastRecapWeekStart = "mf.retention.lastRecapWeekStart"
        /// The `lastTrainedDate` value present when the last comeback was shown,
        /// so the same lapse never re-triggers.
        static let comebackAckTrainedAt = "mf.retention.comebackAckTrainedAt"
    }

    private init() {}

    // MARK: - Weekly recap

    /// True once the recap for the week beginning `weekStart` has been shown.
    func hasSeenRecap(weekStart: Date) -> Bool {
        let stored = defaults.double(forKey: Key.lastRecapWeekStart)
        guard stored > 0 else { return false }
        return abs(stored - weekStart.timeIntervalSinceReferenceDate) < 1
    }

    /// Record that the recap for the week beginning `weekStart` has been shown.
    func markRecapSeen(weekStart: Date) {
        defaults.set(weekStart.timeIntervalSinceReferenceDate, forKey: Key.lastRecapWeekStart)
    }

    // MARK: - Comeback

    /// Decide whether to surface the welcome-back moment. We show it when the
    /// player has trained before but has been away for `lapseDays`+ days, and we
    /// haven't already acknowledged this exact lapse.
    func shouldShowComeback(lastTrainedDate: Date?, lapseDays: Int = 3) -> Bool {
        guard let last = lastTrainedDate else { return false }
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: last), to: cal.startOfDay(for: Date())).day ?? 0
        guard days >= lapseDays else { return false }

        let acked = defaults.double(forKey: Key.comebackAckTrainedAt)
        // Same lapse already shown → don't repeat until they train again.
        return abs(acked - last.timeIntervalSinceReferenceDate) >= 1
    }

    /// Mark the current lapse (keyed by the player's last trained date) as shown.
    func markComebackShown(lastTrainedDate: Date?) {
        guard let last = lastTrainedDate else { return }
        defaults.set(last.timeIntervalSinceReferenceDate, forKey: Key.comebackAckTrainedAt)
    }
}
