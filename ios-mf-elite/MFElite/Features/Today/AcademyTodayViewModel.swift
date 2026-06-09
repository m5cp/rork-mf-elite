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
    var drillRoute: DrillRoute? = nil
    var levelRoute: LevelRoute? = nil
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

    var playerName: String { PlayerProfileStore.shared.displayName }
    var playerInitials: String { PlayerProfileStore.shared.initials }

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
        "Control the ball. Control the game.",
        "Do it when you don't feel like it. That's the edge.",
        "Touch the ball every single day. No exceptions.",
        "You are what you repeat.",
        "Small sessions, done daily, beat long sessions done occasionally.",
        "The best players in the world were once where you are now.",
        "Your weak foot is not optional. It is a weapon waiting to be built.",
        "Speed without control is just chaos.",
        "Every rep matters. Even the ones nobody sees.",
        "Train like you play. Play like you train.",
        "Focus is a skill. Practice it.",
        "The player who works hardest in the off-season wins in the season.",
        "Master the basics. Then master them again.",
        "Composure under pressure is trained, not given.",
        "Your body follows your mind. Think sharp, move sharp.",
        "Nobody remembers the excuses. They remember the results.",
        "There is no substitute for ball time.",
        "Be the player that coaches trust in the big moments.",
        "You control two things: your effort and your attitude.",
        "Your first touch determines everything that follows.",
        "Champions are built in the dark. Keep training.",
        "Talent is common. Discipline is rare.",
        "You don't rise to the occasion. You fall to the level of your training.",
        "Play with purpose. Every touch has intention.",
        "Rest is part of the process. Recover well.",
        "Mental strength is the most underrated skill in soccer.",
        "Be coachable. The best players always are.",
        "Consistency beats intensity. Show up every day.",
        "Play the game in your head before you play it on the pitch.",
        "Your position is earned. Never stop earning it.",
        "The ball moves faster than your feet. Think ahead.",
        "Make the simple pass. Make it perfectly.",
        "Watch the game. Study the game. Live the game.",
        "Your body is your tool. Respect it. Fuel it. Train it.",
        "The difference between a pass and a great pass is timing.",
        "Soccer is a thinking game played with your feet.",
        "Today's session is tomorrow's instinct.",
        "You miss 100% of the reps you skip.",
        "A strong mind controls a tired body.",
        "The pitch doesn't owe you anything. Earn every yard.",
        "Confidence comes from preparation. Prepare.",
        "Vision is seeing what others don't. Scan more.",
        "Movement off the ball is where games are won.",
        "Every champion was once a beginner who refused to quit.",
        "The players who last are the ones who love the process.",
        "Mistakes are data. Learn from every one.",
        "Be the hardest worker on the pitch. Every single time.",
        "Practice doesn't make perfect. Perfect practice makes perfect.",
        "Speed of thought beats speed of feet.",
        "Stay hungry. Stay humble. Stay sharp.",
        "The grind is the glory. Love the work."
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
        let physicalToday = drillsLoggedToday.contains { disciplineNameByDrill[$0] == "Physical" }
        let mindToday = drillsLoggedToday.contains { disciplineNameByDrill[$0] == "Psychological" }
        return [
            GoalState(
                id: 0, label: "Ball Mastery — 1 drill", done: ballMasteryToday,
                drillRoute: firstUnmasteredDrill { _, category in category.name == "Ball Mastery" }
            ),
            GoalState(
                id: 1, label: "Physical — 1 drill", done: physicalToday,
                drillRoute: firstUnmasteredDrill { discipline, _ in discipline.name == "Physical" }
            ),
            GoalState(
                id: 2, label: "Mind — 1 exercise", done: mindToday,
                drillRoute: firstUnmasteredDrill { discipline, _ in discipline.name == "Psychological" }
            )
        ]
    }

    /// First not-yet-mastered drill matching a discipline/category predicate,
    /// for navigating directly to a goal's next actionable drill.
    private func firstUnmasteredDrill(matching: (Discipline, Category) -> Bool) -> DrillRoute? {
        for discipline in disciplines {
            for category in sortedCategories(discipline) where matching(discipline, category) {
                for level in sortedLevels(category) {
                    if let drill = sortedDrills(level).first(where: { !masteredDrillIDs.contains($0.id) }) {
                        return DrillRoute(discipline: discipline, category: category, level: level, drill: drill)
                    }
                }
            }
        }
        return nil
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
