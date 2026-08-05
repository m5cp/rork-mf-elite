//
//  StreakDetailViewModel.swift
//  MFElite
//
//  Derives the streak dashboard: today status, activity grid, and milestones.
//

import Foundation
import Observation

/// Visual state of one day cell in the activity grid.
enum DayCellState {
    case trained
    case notTrained
    case todayPending
    case future
}

/// One day in the 5-week activity grid.
struct ActivityDay: Identifiable {
    let id: Int
    let date: Date
    let state: DayCellState
}

/// One milestone in the ladder, with progress context.
struct MilestoneState: Identifiable {
    let id: Int
    let name: String
    let days: Int
    let achieved: Bool
    let isCurrentTarget: Bool
    let daysToGo: Int
}

@MainActor
@Observable
final class StreakDetailViewModel {
    let streak: Int
    let freezesRemaining: Int
    let lastTrainedDate: Date?

    private let calendar: Calendar
    private let trainedDates: Set<Date>

    init(streak: Int, freezesRemaining: Int, lastTrainedDate: Date?, trainedDates: Set<Date>) {
        self.streak = streak
        self.freezesRemaining = freezesRemaining
        self.lastTrainedDate = lastTrainedDate

        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday
        self.calendar = cal

        // Real training days from the session log. This grid used to be
        // reconstructed by counting `streak` days back from `lastTrainedDate`,
        // so it drew the streak counter rather than the player's history —
        // filling in days they never trained, and blanking weeks of real work
        // the moment the streak was short.
        self.trainedDates = Set(trainedDates.map { cal.startOfDay(for: $0) })
    }

    // MARK: - Today status

    var trainedToday: Bool {
        guard let last = lastTrainedDate else { return false }
        return calendar.isDateInToday(last)
    }

    var freezeTotal: Int { XPStoreService.maxFreezes }

    // MARK: - Activity grid (5 weeks × 7 days, Monday-first)

    var activityDays: [ActivityDay] {
        let today = calendar.startOfDay(for: Date())

        // Monday of the current week.
        let weekday = calendar.component(.weekday, from: today)
        let daysSinceMonday = (weekday - calendar.firstWeekday + 7) % 7
        guard let currentMonday = calendar.date(byAdding: .day, value: -daysSinceMonday, to: today),
              let firstMonday = calendar.date(byAdding: .day, value: -28, to: currentMonday) else {
            return []
        }

        return (0..<35).compactMap { index in
            guard let date = calendar.date(byAdding: .day, value: index, to: firstMonday) else { return nil }
            let day = calendar.startOfDay(for: date)
            let state: DayCellState
            if day > today {
                state = .future
            } else if trainedDates.contains(day) {
                state = .trained
            } else if calendar.isDate(day, inSameDayAs: today) {
                state = trainedToday ? .trained : .todayPending
            } else {
                state = .notTrained
            }
            return ActivityDay(id: index, date: date, state: state)
        }
    }

    let weekdayInitials: [String] = ["M", "T", "W", "T", "F", "S", "S"]

    // MARK: - Milestones

    private static let milestoneSpecs: [(name: String, days: Int)] = [
        ("Week One", 7),
        ("Fortnight", 14),
        ("The Month", 30),
        ("Fifty", 50),
        ("Century", 100)
    ]

    var milestones: [MilestoneState] {
        let firstUnachievedIndex = Self.milestoneSpecs.firstIndex { streak < $0.days }
        return Self.milestoneSpecs.enumerated().map { index, spec in
            let achieved = streak >= spec.days
            let isCurrent = index == firstUnachievedIndex
            return MilestoneState(
                id: index,
                name: spec.name,
                days: spec.days,
                achieved: achieved,
                isCurrentTarget: isCurrent,
                daysToGo: max(0, spec.days - streak)
            )
        }
    }
}
