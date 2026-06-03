//
//  CategoryViewModel.swift
//  MFElite
//

import Foundation
import Observation

/// The visual state of a mastery level within a category.
enum LevelState {
    case mastered
    case inProgress
    case upcoming
    case locked
}

/// Derives Category-detail presentation values from one category and player mastery.
@MainActor
@Observable
final class CategoryViewModel {
    let category: Category
    let discipline: Discipline

    /// Drill IDs the player has mastered.
    private let masteredDrillIDs: Set<String>

    init(category: Category, discipline: Discipline, masteredDrillIDs: Set<String>) {
        self.category = category
        self.discipline = discipline
        self.masteredDrillIDs = masteredDrillIDs
    }

    /// Levels sorted by number.
    var levels: [MasteryLevel] {
        category.levels.sorted { $0.number < $1.number }
    }

    /// A level is mastered when all of its drills are mastered.
    func isLevelMastered(_ level: MasteryLevel) -> Bool {
        guard !level.drills.isEmpty else { return false }
        return level.drills.allSatisfy { masteredDrillIDs.contains($0.id) }
    }

    /// Mastered drills within a single level.
    func masteredDrillCount(_ level: MasteryLevel) -> Int {
        level.drills.filter { masteredDrillIDs.contains($0.id) }.count
    }

    /// The visual state for a level. The lowest non-mastered level is "in progress".
    func levelState(_ level: MasteryLevel) -> LevelState {
        if isLevelMastered(level) { return .mastered }
        if level.number == currentLevelNumber { return .inProgress }
        return .upcoming
    }

    /// All levels in the category are mastered.
    var isCategoryCertified: Bool {
        !levels.isEmpty && levels.allSatisfy { isLevelMastered($0) }
    }

    var masteredLevelCount: Int {
        levels.filter { isLevelMastered($0) }.count
    }

    /// First non-mastered level number, or nil if every level is mastered.
    private var currentLevelNumber: Int? {
        levels.first { !isLevelMastered($0) }?.number
    }
}
