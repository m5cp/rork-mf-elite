//
//  AcademyHubViewModel.swift
//  MFElite
//

import Foundation
import Observation

/// Derives Academy Hub presentation values from the curriculum and player state.
@MainActor
@Observable
final class AcademyHubViewModel {
    let disciplines: [Discipline]
    let xp: Int
    /// Earned + purchased XP, used only for rank/level DISPLAY (never leaderboards).
    let rankXP: Int
    let streak: Int

    /// Drill IDs the player has mastered.
    private let masteredDrillIDs: Set<String>

    init(disciplines: [Discipline], xp: Int, rankXP: Int, streak: Int, masteredDrillIDs: Set<String>) {
        self.disciplines = disciplines.sorted { $0.sortIndex < $1.sortIndex }
        self.xp = xp
        self.rankXP = rankXP
        self.streak = streak
        self.masteredDrillIDs = masteredDrillIDs
    }

    var currentRank: AcademyRank {
        AcademyRank.unlockedRank(for: rankXP, hasFullAccess: SubscriptionService.shared.hasFullAccess)
    }

    var totalCategories: Int {
        disciplines.reduce(0) { $0 + $1.categories.count }
    }

    var totalLevels: Int {
        disciplines.reduce(0) { partial, discipline in
            partial + discipline.categories.reduce(0) { $0 + $1.levels.count }
        }
    }

    var totalDrills: Int {
        disciplines.reduce(0) { $0 + drillCount(for: $1) }
    }

    /// Total number of drills across every level and category in a discipline.
    func drillCount(for discipline: Discipline) -> Int {
        discipline.categories.reduce(0) { partial, category in
            partial + category.levels.reduce(0) { $0 + $1.drills.count }
        }
    }

    /// Number of certified categories — those where every drill in every level is mastered.
    func certifiedCount(for discipline: Discipline) -> Int {
        discipline.categories.filter { isCertified($0) }.count
    }

    /// A category is certified when all of its drills are mastered.
    private func isCertified(_ category: Category) -> Bool {
        let drills = category.levels.flatMap { $0.drills }
        guard !drills.isEmpty else { return false }
        return drills.allSatisfy { masteredDrillIDs.contains($0.id) }
    }
}
