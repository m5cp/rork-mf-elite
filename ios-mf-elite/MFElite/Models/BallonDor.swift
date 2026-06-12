//
//  BallonDor.swift
//  MFElite
//
//  The final, invite-only progression tier above the five academy ranks. Holding
//  it requires both meeting an elite XP + mastery bar AND a coach's explicit
//  approval — it is never unlocked by XP alone.
//

import Foundation

/// The presentation state of the Ballon d'Or tier for the current player.
enum BallonDorState: Equatable {
    /// Requirements not yet met.
    case locked
    /// Requirements met; the request is being recorded / awaiting first sync.
    case eligible
    /// Request recorded, awaiting coach review.
    case pending
    /// Coach-approved and unlocked.
    case approved
}

/// Requirement math for the Ballon d'Or tier. Self-contained and deterministic.
nonisolated enum BallonDor {
    /// XP needed: the player must already hold the top XP rank.
    static var requiredXP: Int { AcademyRank.captain.rawValue }

    /// Fraction of skill areas (categories) that must be certified.
    static let requiredCertFraction = 0.5

    /// Number of certified categories required, given the curriculum size.
    static func requiredCerts(totalCategories: Int) -> Int {
        guard totalCategories > 0 else { return 0 }
        return max(1, Int((Double(totalCategories) * requiredCertFraction).rounded(.up)))
    }

    /// True when the player has met the XP and mastery bar to be considered.
    static func meetsRequirements(xp: Int, certCount: Int, totalCategories: Int) -> Bool {
        guard totalCategories > 0 else { return false }
        return xp >= requiredXP && certCount >= requiredCerts(totalCategories: totalCategories)
    }

    /// One-line human summary of what's required, for the locked state.
    static func requirementSummary(totalCategories: Int) -> String {
        let certs = requiredCerts(totalCategories: totalCategories)
        return "Reach \(AcademyRank.captain.title) · certify \(certs) skill \(certs == 1 ? "area" : "areas")"
    }
}
