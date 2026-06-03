//
//  CoachWorkspaceViewModel.swift
//  MFElite
//

import Foundation
import Observation

/// Derives live curriculum counts for the coach admin workspace.
@MainActor
@Observable
final class CoachWorkspaceViewModel {
    let disciplines: [Discipline]

    init(disciplines: [Discipline]) {
        self.disciplines = disciplines.sorted { $0.sortIndex < $1.sortIndex }
    }

    var pathwayCount: Int { disciplines.count }

    var totalCategories: Int {
        disciplines.reduce(0) { $0 + $1.categories.count }
    }

    var totalLevels: Int {
        disciplines.reduce(0) { partial, discipline in
            partial + discipline.categories.reduce(0) { $0 + $1.levels.count }
        }
    }

    var totalDrills: Int {
        disciplines.reduce(0) { partial, discipline in
            partial + drillCount(for: discipline)
        }
    }

    func categoryCount(for discipline: Discipline) -> Int {
        discipline.categories.count
    }

    func drillCount(for discipline: Discipline) -> Int {
        discipline.categories.reduce(0) { partial, category in
            partial + category.levels.reduce(0) { $0 + $1.drills.count }
        }
    }

    func levelCount(for category: Category) -> Int {
        category.levels.count
    }

    func drillCount(for category: Category) -> Int {
        category.levels.reduce(0) { $0 + $1.drills.count }
    }

    func sortedCategories(for discipline: Discipline) -> [Category] {
        discipline.categories.sorted { $0.sortIndex < $1.sortIndex }
    }
}
