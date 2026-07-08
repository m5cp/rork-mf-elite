//
//  StreakMilestones.swift
//  MFElite
//
//  Presentation bookkeeping for streak milestone celebrations (7, 30, 50, 100
//  days). Tracks the last celebrated tier in UserDefaults so each milestone
//  fires its full-screen celebration exactly once. Never touches streak
//  computation, XP, or history — celebrations are pure presentation.
//

import Foundation

/// A streak milestone pending celebration. Identifiable so it can drive a
/// `fullScreenCover(item:)`.
struct StreakMilestone: Identifiable {
    let days: Int
    var id: Int { days }
}

enum StreakMilestones {
    /// The celebrated tiers, ascending.
    static let tiers: [Int] = [7, 30, 50, 100]

    private static let key = "MF_LAST_CELEBRATED_STREAK_MILESTONE"

    /// The highest milestone already celebrated (`lastCelebratedStreakMilestone`).
    static var lastCelebrated: Int {
        UserDefaults.standard.integer(forKey: key)
    }

    /// True when `streak` has just crossed a tier that hasn't been celebrated.
    /// Read-only — does not mark anything.
    static func pending(for streak: Int) -> Bool {
        tiers.contains(streak) && streak > lastCelebrated
    }

    /// Atomic check-and-claim: if `streak` sits exactly on an uncelebrated tier,
    /// marks it celebrated and returns the tier — otherwise nil. Claim right at
    /// presentation time so overlapping hooks (session summary, quick log,
    /// celebration queue) can never double-celebrate the same milestone.
    static func claim(for streak: Int) -> Int? {
        guard pending(for: streak) else { return nil }
        UserDefaults.standard.set(streak, forKey: key)
        return streak
    }
}
