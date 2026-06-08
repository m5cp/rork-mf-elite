//
//  AcademyRank.swift
//  MFElite
//

import Foundation

/// The five academy ranks. Each raw value is the minimum XP threshold to hold the rank.
enum AcademyRank: Int, CaseIterable, Sendable {
    case trialist = 0
    case cadet = 1500
    case prospect = 4000
    case starter = 9000
    case captain = 18000

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
}
