//
//  LevelViewModel.swift
//  MFElite
//

import Foundation
import Observation

/// Derives Level-detail presentation values from one mastery level and player mastery.
@MainActor
@Observable
final class LevelViewModel {
    let level: MasteryLevel
    let category: Category
    let discipline: Discipline

    /// Passes logged per drill ID (0...masteryPasses).
    private let passesByDrill: [String: Int]
    /// Drill IDs the player has mastered.
    private let masteredDrillIDs: Set<String>

    init(
        level: MasteryLevel,
        category: Category,
        discipline: Discipline,
        passesByDrill: [String: Int],
        masteredDrillIDs: Set<String>
    ) {
        self.level = level
        self.category = category
        self.discipline = discipline
        self.passesByDrill = passesByDrill
        self.masteredDrillIDs = masteredDrillIDs
    }

    /// Drills sorted by sortIndex.
    var drills: [Drill] {
        level.drills.sorted { $0.sortIndex < $1.sortIndex }
    }

    func passesLogged(for drill: Drill) -> Int {
        passesByDrill[drill.id] ?? 0
    }

    func isMastered(_ drill: Drill) -> Bool {
        masteredDrillIDs.contains(drill.id)
    }

    var masteredDrillCount: Int {
        drills.filter { isMastered($0) }.count
    }

    /// First non-mastered drill — the one the player should train next.
    var currentDrill: Drill? {
        drills.first { !isMastered($0) }
    }
}
