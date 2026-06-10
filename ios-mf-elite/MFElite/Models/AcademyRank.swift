//
//  AcademyRank.swift
//  MFElite
//

import Foundation

/// The five academy ranks. Each raw value is the minimum XP threshold to hold the rank.
enum AcademyRank: Int, CaseIterable, Sendable {
    case trialist = 0
    case cadet = 6000
    case prospect = 16000
    case starter = 30000
    case captain = 52000

    /// Roman numeral for the rank.
    var numeral: String {
        switch self {
        case .trialist: return "I"
        case .cadet: return "II"
        case .prospect: return "III"
        case .starter: return "IV"
        case .captain: return "V"
        }
    }

    /// Display title for the rank.
    var title: String {
        switch self {
        case .trialist: return "New Talent"
        case .cadet: return "Academy"
        case .prospect: return "Prospect"
        case .starter: return "First Eleven"
        case .captain: return "Captain"
        }
    }

    /// Returns the highest rank whose threshold is satisfied by `xp`.
    static func rank(for xp: Int) -> AcademyRank {
        allCases.last { xp >= $0.rawValue } ?? .trialist
    }

    // MARK: - Subscription gating

    /// Number of ranks available on the free tier. The remaining ranks (the
    /// final three) require both the XP threshold AND an active Elite
    /// subscription to hold.
    static let freeRankCount = 2

    /// The highest rank a free player can hold, regardless of how much XP they
    /// have earned.
    static var highestFreeRank: AcademyRank {
        allCases[freeRankCount - 1]
    }

    /// True when holding this rank requires an active Elite subscription.
    var requiresSubscription: Bool {
        (Self.allCases.firstIndex(of: self) ?? 0) >= Self.freeRankCount
    }

    /// The rank the player can actually hold right now: the XP-earned rank,
    /// capped to the highest free rank unless the player has full (Elite)
    /// access. XP is always retained, so re-subscribing instantly restores the
    /// full earned rank.
    static func unlockedRank(for xp: Int, hasFullAccess: Bool) -> AcademyRank {
        let earned = rank(for: xp)
        guard !hasFullAccess else { return earned }
        return earned.rawValue > highestFreeRank.rawValue ? highestFreeRank : earned
    }

    /// True when the player has earned enough XP for a higher rank but it is
    /// locked behind an Elite subscription.
    static func hasLockedEarnedRank(for xp: Int, hasFullAccess: Bool) -> Bool {
        !hasFullAccess && rank(for: xp).rawValue > highestFreeRank.rawValue
    }

    /// Returns the next rank above the current one, or nil if already at max.
    static func nextRank(for xp: Int) -> AcademyRank? {
        let current = rank(for: xp)
        guard let idx = allCases.firstIndex(of: current), idx + 1 < allCases.count else {
            return nil
        }
        return allCases[idx + 1]
    }

    /// XP remaining to reach the next rank, or nil if already at max.
    static func xpToNext(for xp: Int) -> Int? {
        guard let next = nextRank(for: xp) else { return nil }
        return max(0, next.rawValue - xp)
    }

    /// The next rank the player is progressing toward, measured from the rank
    /// they can actually hold given their access level.
    static func nextRank(for xp: Int, hasFullAccess: Bool) -> AcademyRank? {
        let current = unlockedRank(for: xp, hasFullAccess: hasFullAccess)
        guard let idx = allCases.firstIndex(of: current), idx + 1 < allCases.count else {
            return nil
        }
        return allCases[idx + 1]
    }

    /// XP remaining to reach the next rank from the player's current access level.
    static func xpToNext(for xp: Int, hasFullAccess: Bool) -> Int? {
        guard let next = nextRank(for: xp, hasFullAccess: hasFullAccess) else { return nil }
        return max(0, next.rawValue - xp)
    }
}
