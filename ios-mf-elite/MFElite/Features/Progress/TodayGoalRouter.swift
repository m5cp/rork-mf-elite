//
//  TodayGoalRouter.swift
//  MFElite
//
//  Resolves the Progress tab's Today-card pillars (Train / Drills / Mind) to a
//  concrete next drill, mirroring the Today tab's goal routing: walk the
//  curriculum in order and return the first not-yet-mastered drill matching
//  the pillar. Self-contained so the Progress tab doesn't need the Today
//  view model.
//

import Foundation

enum TodayGoalPillar {
    case train, drills, mind
}

enum TodayGoalRouter {

    /// The next actionable drill for a pillar, or nil when everything matching
    /// is mastered (callers hide the chevron / disable navigation in that case).
    static func route(
        for pillar: TodayGoalPillar,
        disciplines: [Discipline],
        progress: [DrillProgress]
    ) -> DrillRoute? {
        let mastered = Set(progress.filter(\.isMastered).map(\.drillID))
        switch pillar {
        case .mind:
            return firstUnmastered(disciplines: disciplines, mastered: mastered) { discipline, _ in
                discipline.name == "Mental"
            }
        case .train, .drills:
            // Recommended next drill: first unmastered anywhere, technical
            // curriculum first (disciplines are already in sort order).
            return firstUnmastered(disciplines: disciplines, mastered: mastered) { _, _ in true }
        }
    }

    private static func firstUnmastered(
        disciplines: [Discipline],
        mastered: Set<String>,
        matching: (Discipline, Category) -> Bool
    ) -> DrillRoute? {
        for discipline in disciplines.sorted(by: { $0.sortIndex < $1.sortIndex }) {
            for category in discipline.categories.sorted(by: { $0.sortIndex < $1.sortIndex })
            where matching(discipline, category) {
                for level in category.levels.sorted(by: { $0.sortIndex < $1.sortIndex }) {
                    let drills = level.drills
                        .filter { !$0.isCoachHidden }
                        .sorted { $0.sortIndex < $1.sortIndex }
                    if let drill = drills.first(where: { !mastered.contains($0.id) }) {
                        return DrillRoute(discipline: discipline, category: category, level: level, drill: drill)
                    }
                }
            }
        }
        return nil
    }
}
