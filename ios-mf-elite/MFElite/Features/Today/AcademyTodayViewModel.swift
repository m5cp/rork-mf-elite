//
//  AcademyTodayViewModel.swift
//  MFElite
//
//  Derives the daily dashboard presentation from the curriculum and player state.
//

import Foundation
import Observation

/// A single daily goal and whether it has been satisfied today.
struct GoalState: Identifiable {
    let id: Int
    let label: String
    let done: Bool
}

/// The player's current in-progress level plus its parent context.
struct CurrentFocus {
    let level: MasteryLevel
    let category: Category
    let discipline: Discipline
}

/// One recommended drill for a discipline, carrying full navigation context.
struct Recommendation: Identifiable {
    let drill: Drill
    let category: Category
    let level: MasteryLevel
    let discipline: Discipline
    let reason: String

    var id: String { drill.id }
}

@MainActor
@Observable
final class AcademyTodayViewModel {
    let disciplines: [Discipline]
    let xp: Int
    let streak: Int

    private let masteredDrillIDs: Set<String>
    private let passesByDrill: [String: Int]
    private let drillsLoggedToday: Set<String>
    /// drillID → owning discipline name, for resolving today's activity.
    private let disciplineNameByDrill: [String: String]
    /// drillID → owning category name.
    private let categoryNameByDrill: [String: String]

    init(
        disciplines: [Discipline],
        xp: Int,
        streak: Int,
        progress: [DrillProgress]
    ) {
        let sorted = disciplines.sorted { $0.sortIndex < $1.sortIndex }
        self.disciplines = sorted
        self.xp = xp
        self.streak = streak

        self.masteredDrillIDs = Set(progress.filter { $0.isMastered }.map { $0.drillID })
        self.passesByDrill = Dictionary(
            progress.map { ($0.drillID, $0.passesLogged) },
            uniquingKeysWith: { a, _ in a }
        )

        let calendar = Calendar.current
        self.drillsLoggedToday = Set(
            progress
                .filter { entry in
                    guard let date = entry.lastLoggedAt else { return false }
                    return calendar.isDateInToday(date)
                }
                .map { $0.drillID }
        )

        var disciplineMap: [String: String] = [:]
        var categoryMap: [String: String] = [:]
        for discipline in sorted {
            for category in discipline.categories {
                for level in category.levels {
                    for drill in level.drills {
                        disciplineMap[drill.id] = discipline.name
                        categoryMap[drill.id] = category.name
                    }
                }
            }
        }
        self.disciplineNameByDrill = disciplineMap
        self.categoryNameByDrill = categoryMap
    }

    // MARK: - Salutation

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case ..<12:  return "Good morning,"
        case 12..<17: return "Good afternoon,"
        default:     return "Good evening,"
        }
    }

    var playerName: String { "Player One" }
    var playerInitials: String { "P1" }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE d MMM"
        let day = formatter.string(from: Date()).uppercased()
        return "\(day) · Season 25—26"
    }

    // MARK: - Daily quote

    private static let quotes: [String] = [
        "Full effort is the only standard.",
        "The ball doesn't care about yesterday.",
        "Train like you've never won. Play like you've never lost.",
        "Discipline is choosing what you want most over what you want now.",
        "Every touch is a chance to improve.",
        "Champions are built in the sessions nobody sees.",
        "Your feet are your tools. Sharpen them daily.",
        "Pressure is a privilege.",
        "The difference between good and great is one more rep.",
        "Control the ball. Control the game."
    ]

    var dailyQuote: String {
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        return Self.quotes[(dayOfYear - 1) % Self.quotes.count]
    }

    // MARK: - Rank

    var currentRank: AcademyRank { AcademyRank.rank(for: xp) }

    // MARK: - Daily goals

    var goalStates: [GoalState] {
        let ballMasteryToday = drillsLoggedToday.contains { categoryNameByDrill[$0] == "Ball Mastery" }
        let mindToday = drillsLoggedToday.contains { disciplineNameByDrill[$0] == "Psychological" }
        return [
            GoalState(id: 0, label: "Ball Mastery — 1 drill", done: ballMasteryToday),
            GoalState(id: 1, label: "Daily film — watched", done: false),
            GoalState(id: 2, label: "Mind — 1 exercise", done: mindToday)
        ]
    }

    var dailyGoalsTotal: Int { goalStates.count }
    var dailyGoalsCompleted: Int { goalStates.filter { $0.done }.count }
    var todaysDrillCount: Int { drillsLoggedToday.count }

    var totalDrills: Int {
        disciplines.reduce(0) { partial, discipline in
            partial + discipline.categories.reduce(0) { sub, category in
                sub + category.levels.reduce(0) { $0 + $1.drills.count }
            }
        }
    }

    // MARK: - Continue your pathway

    /// First level with progress that isn't fully mastered; falls back to the
    /// first level anywhere that still has unmastered drills.
    var currentFocus: CurrentFocus? {
        if let focus = firstLevel(requireProgress: true) { return focus }
        return firstLevel(requireProgress: false)
    }

    private func firstLevel(requireProgress: Bool) -> CurrentFocus? {
        for discipline in disciplines {
            for category in sortedCategories(discipline) {
                for level in sortedLevels(category) {
                    let drills = level.drills
                    guard !drills.isEmpty else { continue }
                    let allMastered = drills.allSatisfy { masteredDrillIDs.contains($0.id) }
                    if allMastered { continue }
                    if requireProgress {
                        let anyProgress = drills.contains { (passesByDrill[$0.id] ?? 0) > 0 }
                        if !anyProgress { continue }
                    }
                    return CurrentFocus(level: level, category: category, discipline: discipline)
                }
            }
        }
        return nil
    }

    func masteredDrillCount(in level: MasteryLevel) -> Int {
        level.drills.filter { masteredDrillIDs.contains($0.id) }.count
    }

    // MARK: - Recommendations

    var recommendations: [Recommendation] {
        disciplines.compactMap { recommendation(for: $0) }
    }

    private func recommendation(for discipline: Discipline) -> Recommendation? {
        // Prefer the next unmastered drill in a level the player has started.
        for category in sortedCategories(discipline) {
            for level in sortedLevels(category) {
                let drills = sortedDrills(level)
                let anyProgress = drills.contains { (passesByDrill[$0.id] ?? 0) > 0 }
                guard anyProgress else { continue }
                if let next = drills.first(where: { !masteredDrillIDs.contains($0.id) }) {
                    return Recommendation(
                        drill: next, category: category, level: level,
                        discipline: discipline, reason: "Next in pathway"
                    )
                }
            }
        }
        // No progress yet — surface the very first drill.
        if let category = sortedCategories(discipline).first,
           let level = sortedLevels(category).first,
           let drill = sortedDrills(level).first {
            return Recommendation(
                drill: drill, category: category, level: level,
                discipline: discipline, reason: "Try something new"
            )
        }
        return nil
    }

    // MARK: - Sorting helpers

    private func sortedCategories(_ discipline: Discipline) -> [Category] {
        discipline.categories.sorted { $0.sortIndex < $1.sortIndex }
    }

    private func sortedLevels(_ category: Category) -> [MasteryLevel] {
        category.levels.sorted { $0.number < $1.number }
    }

    private func sortedDrills(_ level: MasteryLevel) -> [Drill] {
        level.drills.sorted { $0.sortIndex < $1.sortIndex }
    }
}
