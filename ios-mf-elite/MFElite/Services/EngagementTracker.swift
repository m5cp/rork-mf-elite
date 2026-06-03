//
//  EngagementTracker.swift
//  MFElite
//
//  Central, persisted gate for two engagement moments:
//   • the soft notification pre-permission prompt (after the first drill), and
//   • App Store review requests (after genuinely positive moments).
//  All counters live in UserDefaults so the rules survive relaunch.
//

import Foundation
import UserNotifications

/// Positive moments that may trigger an App Store review request.
enum ReviewTrigger: String {
    case firstCertification
    case sevenDayStreak
    case tenthDrillMastered
}

@MainActor
@Observable
final class EngagementTracker {
    static let shared = EngagementTracker()

    private let defaults = UserDefaults.standard

    private enum Key {
        static let drillsCompleted = "mf.engagement.drillsCompleted"
        static let notifAskCount = "mf.notif.askCount"
        static let reviewCount = "mf.review.count"
        static let lastReviewDate = "mf.review.lastDate"
        static let firedTriggers = "mf.review.firedTriggers"
    }

    private init() {}

    // MARK: - Drill completions

    /// Total logged drill sessions across the app's lifetime.
    var drillsCompleted: Int { defaults.integer(forKey: Key.drillsCompleted) }

    /// Records a logged drill. Call once per completed drill session.
    @discardableResult
    func recordDrillCompleted() -> Int {
        let next = drillsCompleted + 1
        defaults.set(next, forKey: Key.drillsCompleted)
        return next
    }

    // MARK: - Notification soft prompt

    private var notifAskCount: Int { defaults.integer(forKey: Key.notifAskCount) }

    /// Decides whether to show the soft pre-permission sheet. Only when the
    /// system status is still undetermined, never more than twice: first after
    /// the first drill, then (if deferred) after the third.
    func evaluateNotificationPrompt(completion: @escaping (Bool) -> Void) {
        let count = notifAskCount
        let drills = drillsCompleted

        let eligibleByCount: Bool
        switch count {
        case 0: eligibleByCount = drills >= 1
        case 1: eligibleByCount = drills >= 3
        default: eligibleByCount = false
        }
        guard eligibleByCount else { completion(false); return }

        NotificationService.shared.authorizationStatus { status in
            completion(status == .notDetermined)
        }
    }

    /// Marks that the soft sheet was shown (counts toward the max of two asks).
    func markNotificationAsked() {
        defaults.set(notifAskCount + 1, forKey: Key.notifAskCount)
    }

    // MARK: - App review

    private var reviewCount: Int { defaults.integer(forKey: Key.reviewCount) }

    private var firedTriggers: Set<String> {
        Set(defaults.stringArray(forKey: Key.firedTriggers) ?? [])
    }

    /// Returns true if a review request is appropriate for this trigger, and
    /// records the attempt so the rules (max 3 total, once per 30 days, each
    /// trigger once, min 3 drills) are respected.
    func shouldRequestReview(for trigger: ReviewTrigger) -> Bool {
        guard !firedTriggers.contains(trigger.rawValue) else { return false }
        guard drillsCompleted >= 3 else { return false }
        guard reviewCount < 3 else { return false }

        if let last = defaults.object(forKey: Key.lastReviewDate) as? Date,
           Date().timeIntervalSince(last) < 30 * 24 * 60 * 60 {
            return false
        }

        var fired = firedTriggers
        fired.insert(trigger.rawValue)
        defaults.set(Array(fired), forKey: Key.firedTriggers)
        defaults.set(reviewCount + 1, forKey: Key.reviewCount)
        defaults.set(Date(), forKey: Key.lastReviewDate)
        return true
    }
}
