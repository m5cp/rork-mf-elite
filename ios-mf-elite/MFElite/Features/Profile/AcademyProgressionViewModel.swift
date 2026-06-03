//
//  AcademyProgressionViewModel.swift
//  MFElite
//

import Foundation
import Observation

/// Derives Academy Progression presentation values from player state and the curriculum.
@MainActor
@Observable
final class AcademyProgressionViewModel {
    let disciplines: [Discipline]
    let xp: Int
    let streak: Int

    /// Drill IDs the player has mastered.
    private let masteredDrillIDs: Set<String>
    /// Drill IDs the player has logged at least once.
    private let loggedDrillIDs: Set<String>

    init(
        disciplines: [Discipline],
        xp: Int,
        streak: Int,
        masteredDrillIDs: Set<String>,
        loggedDrillIDs: Set<String>
    ) {
        self.disciplines = disciplines.sorted { $0.sortIndex < $1.sortIndex }
        self.xp = xp
        self.streak = streak
        self.masteredDrillIDs = masteredDrillIDs
        self.loggedDrillIDs = loggedDrillIDs
    }

    var currentRank: AcademyRank {
        AcademyRank.rank(for: xp)
    }

    var nextRank: AcademyRank? {
        AcademyRank.nextRank(for: xp)
    }

    var xpToNext: Int? {
        AcademyRank.xpToNext(for: xp)
    }

    /// Progress from the current rank threshold toward the next rank (0...1).
    var progressToNext: Double {
        guard let next = nextRank else { return 1 }
        let floorXP = currentRank.rawValue
        let span = next.rawValue - floorXP
        guard span > 0 else { return 1 }
        return min(1, max(0, Double(xp - floorXP) / Double(span)))
    }

    /// Fraction of drills in a discipline that the player has mastered (0...1).
    func disciplineMasteryPercent(for discipline: Discipline) -> Double {
        let drills = discipline.categories.flatMap { $0.levels.flatMap { $0.drills } }
        guard !drills.isEmpty else { return 0 }
        let mastered = drills.filter { masteredDrillIDs.contains($0.id) }.count
        return Double(mastered) / Double(drills.count)
    }

    /// Total certified categories across all disciplines.
    var certCount: Int {
        disciplines.reduce(0) { partial, discipline in
            partial + discipline.categories.filter { isCertified($0) }.count
        }
    }

    /// Number of distinct drills logged at least once.
    var totalDrillsLogged: Int {
        loggedDrillIDs.count
    }

    /// Approximate weekly consistency — current streak capped at 7 days, as a percentage.
    var weeklyConsistencyPercent: Int {
        Int((Double(min(streak, 7)) / 7.0 * 100).rounded())
    }

    private func isCertified(_ category: Category) -> Bool {
        let drills = category.levels.flatMap { $0.drills }
        guard !drills.isEmpty else { return false }
        return drills.allSatisfy { masteredDrillIDs.contains($0.id) }
    }
}
