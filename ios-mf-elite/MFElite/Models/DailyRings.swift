//
//  DailyRings.swift
//  MFElite
//
//  The three daily training rings (Train / Drills / Mind), computed from
//  SessionLogEntry for any given day. Mirrors a fitness-ring calendar: each ring
//  fills toward a small daily goal, and closing all three is a "Perfect Day".
//

import Foundation

/// One day's worth of training, distilled into three ring values.
struct DailyRings: Equatable {
    /// Daily goals.
    static let trainGoalMinutes = 20
    static let drillGoal = 3
    static let mindGoal = 1

    let trainMinutes: Int
    let drillCount: Int
    let mindCount: Int

    init(trainMinutes: Int = 0, drillCount: Int = 0, mindCount: Int = 0) {
        self.trainMinutes = trainMinutes
        self.drillCount = drillCount
        self.mindCount = mindCount
    }

    /// Builds the rings from the session entries that fall on `day`. Apple Watch
    /// workouts on that day fold their minutes into the Train ring only — they
    /// never count as drills or mind exercises, so drill history isn't
    /// double-counted.
    static func make(
        from sessions: [SessionLogEntry],
        workouts: [WorkoutRecord] = [],
        on day: Date,
        calendar: Calendar = .current
    ) -> DailyRings {
        let target = calendar.startOfDay(for: day)
        let dayEntries = sessions.filter { calendar.isDate($0.completedAt, inSameDayAs: target) }
        let totalSec = dayEntries.reduce(0) { $0 + $1.durationSec }
        let drillMinutes = Int((Double(totalSec) / 60).rounded())
        let workoutMinutes = workouts
            .filter { calendar.isDate($0.startedAt, inSameDayAs: target) }
            .reduce(0) { $0 + $1.minutes }
        let mind = dayEntries.filter { $0.disciplineName == "Mental" }.count
        return DailyRings(trainMinutes: drillMinutes + workoutMinutes, drillCount: dayEntries.count, mindCount: mind)
    }

    // MARK: - Progress (0...1)

    var trainProgress: Double { min(1, Double(trainMinutes) / Double(Self.trainGoalMinutes)) }
    var drillProgress: Double { min(1, Double(drillCount) / Double(Self.drillGoal)) }
    var mindProgress: Double { min(1, Double(mindCount) / Double(Self.mindGoal)) }

    // MARK: - Closed state

    var trainClosed: Bool { trainMinutes >= Self.trainGoalMinutes }
    var drillClosed: Bool { drillCount >= Self.drillGoal }
    var mindClosed: Bool { mindCount >= Self.mindGoal }

    /// All three rings closed — a Perfect Day.
    var allClosed: Bool { trainClosed && drillClosed && mindClosed }

    /// Number of closed rings (0...3).
    var closedCount: Int {
        [trainClosed, drillClosed, mindClosed].filter { $0 }.count
    }

    /// True if any training happened at all (used to dim empty calendar cells).
    var hasActivity: Bool { trainMinutes > 0 || drillCount > 0 || mindCount > 0 }
}

/// Persists which days the player closed all three rings, so we can fire the
/// Perfect Day celebration exactly once per day and award the streak badges.
enum PerfectDayStore {
    private static let key = "MF_PERFECT_DAYS"

    private static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(comps.year ?? 0)-\(comps.month ?? 0)-\(comps.day ?? 0)"
    }

    static var recordedDays: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
    }

    static func isRecorded(_ date: Date) -> Bool {
        recordedDays.contains(dayKey(date))
    }

    /// Records `date` as a perfect day. Returns the new total count of perfect days.
    @discardableResult
    static func record(_ date: Date) -> Int {
        var days = recordedDays
        days.insert(dayKey(date))
        UserDefaults.standard.set(Array(days), forKey: key)
        return days.count
    }

    static var count: Int { recordedDays.count }
}
