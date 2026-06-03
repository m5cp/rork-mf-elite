//
//  DisciplineViewModel.swift
//  MFElite
//

import Foundation
import Observation

/// Derives Discipline-detail presentation values from one discipline and player mastery.
@MainActor
@Observable
final class DisciplineViewModel {
    let discipline: Discipline

    /// Drill IDs the player has mastered.
    private let masteredDrillIDs: Set<String>

    init(discipline: Discipline, masteredDrillIDs: Set<String>) {
        self.discipline = discipline
        self.masteredDrillIDs = masteredDrillIDs
    }

    /// Categories sorted by their seed order.
    var categories: [Category] {
        discipline.categories.sorted { $0.sortIndex < $1.sortIndex }
    }

    var totalCategories: Int { discipline.categories.count }

    /// Categories where every drill across every level is mastered.
    var certifiedCount: Int {
        categories.filter { isCertified($0) }.count
    }

    var allCertified: Bool {
        !categories.isEmpty && certifiedCount == totalCategories
    }

    /// A category is certified when all of its drills are mastered.
    func isCertified(_ category: Category) -> Bool {
        let drills = category.levels.flatMap { $0.drills }
        guard !drills.isEmpty else { return false }
        return drills.allSatisfy { masteredDrillIDs.contains($0.id) }
    }

    /// Number of fully-mastered levels in a category.
    func masteredLevelCount(_ category: Category) -> Int {
        category.levels.filter { isLevelMastered($0) }.count
    }

    /// Total drills across every level in a category.
    func drillCount(_ category: Category) -> Int {
        category.levels.reduce(0) { $0 + $1.drills.count }
    }

    /// Mastered drills as a fraction of all drills in the category (0...1).
    func completionPercent(_ category: Category) -> Double {
        let drills = category.levels.flatMap { $0.drills }
        guard !drills.isEmpty else { return 0 }
        let mastered = drills.filter { masteredDrillIDs.contains($0.id) }.count
        return Double(mastered) / Double(drills.count)
    }

    /// The current in-progress level number (first non-mastered level), or nil if all mastered.
    func currentLevelNumber(_ category: Category) -> Int? {
        category.levels
            .sorted { $0.number < $1.number }
            .first { !isLevelMastered($0) }?
            .number
    }

    private func isLevelMastered(_ level: MasteryLevel) -> Bool {
        guard !level.drills.isEmpty else { return false }
        return level.drills.allSatisfy { masteredDrillIDs.contains($0.id) }
    }
}
