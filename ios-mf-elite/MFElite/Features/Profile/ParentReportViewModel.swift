//
//  ParentReportViewModel.swift
//  MFElite
//
//  Derives the monthly parent report: pillar stats, certified categories, and attendance.
//

import Foundation
import Observation

/// A letter grade for one report-card pillar.
enum ReportGrade: String {
    case aPlus = "A+"
    case a = "A"
    case aMinus = "A−"
    case bPlus = "B+"
    case b = "B"
    case c = "C"
}

@MainActor
@Observable
final class ParentReportViewModel {
    let disciplines: [Discipline]
    let xp: Int
    let streak: Int
    let lastTrainedDate: Date?

    /// Drill IDs the player has mastered, all time.
    private let masteredDrillIDs: Set<String>
    /// Sessions logged THIS MONTH. Previously this was the lifetime pass total
    /// while the surrounding copy said "this month".
    let sessionsLogged: Int
    /// Drills whose mastery was reached this month.
    let drillsMastered: Int

    private let calendar: Calendar
    /// Days the player actually trained, taken from the session log. This used
    /// to be synthesised by walking `streak` days back from `lastTrainedDate`,
    /// which meant the parent-facing attendance grid was a drawing of the
    /// streak counter rather than a record of anything: a player who trained
    /// four times a week for two months but skipped yesterday showed one filled
    /// cell out of fifty-six.
    private let trainedDates: Set<Date>

    init(
        disciplines: [Discipline],
        xp: Int,
        streak: Int,
        lastTrainedDate: Date?,
        masteredDrillIDs: Set<String>,
        drillsMasteredThisMonth: Int,
        sessionsThisMonth: Int,
        trainedDates: Set<Date>
    ) {
        self.disciplines = disciplines.sorted { $0.sortIndex < $1.sortIndex }
        self.xp = xp
        self.streak = streak
        self.lastTrainedDate = lastTrainedDate
        self.masteredDrillIDs = masteredDrillIDs
        self.drillsMastered = drillsMasteredThisMonth
        self.sessionsLogged = sessionsThisMonth

        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday
        self.calendar = cal
        self.trainedDates = Set(trainedDates.map { cal.startOfDay(for: $0) })
    }

    /// Start of the current calendar month, for callers assembling the inputs.
    static func startOfMonth(_ now: Date = Date(), calendar: Calendar = .current) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: now))
            ?? calendar.startOfDay(for: now)
    }

    var currentRank: AcademyRank { AcademyRank.rank(for: xp) }

    // MARK: - Pillar stats

    /// Weekly consistency: days actually trained in the last seven, from the
    /// session log rather than from the streak counter.
    var consistencyPercent: Int {
        let today = calendar.startOfDay(for: Date())
        let trainedInLastWeek = (0..<7).compactMap {
            calendar.date(byAdding: .day, value: -$0, to: today)
        }.filter { trainedDates.contains($0) }.count
        guard trainedInLastWeek > 0 else { return 0 }
        return Int((Double(trainedInLastWeek) / 7.0 * 100).rounded())
    }

    /// Categories fully certified, ALL TIME. Named `newCertifications` for
    /// historical reasons; the UI caption says "to date" so the number isn't
    /// presented as monthly. Scoping this to the month would need a
    /// `certifiedAt` date the app doesn't record yet.
    var newCertifications: Int { certifiedCategoryNames.count }

    // MARK: - Certifications

    var certifiedCategoryNames: [String] {
        disciplines.flatMap { discipline in
            discipline.categories
                .sorted { $0.sortIndex < $1.sortIndex }
                .filter { isCertified($0) }
                .map { $0.certName }
        }
    }

    private func isCertified(_ category: Category) -> Bool {
        let drills = category.levels.flatMap { $0.drills }
        guard !drills.isEmpty else { return false }
        return drills.allSatisfy { masteredDrillIDs.contains($0.id) }
    }

    // MARK: - Grades (derived from pillar stats)

    var consistencyGrade: ReportGrade {
        if consistencyPercent >= 80 { return .a }
        if consistencyPercent >= 65 { return .bPlus }
        if consistencyPercent >= 50 { return .b }
        return .c
    }

    var disciplineGrade: ReportGrade {
        if drillsMastered >= 12 { return .a }
        if drillsMastered >= 8 { return .bPlus }
        if drillsMastered >= 4 { return .b }
        return .c
    }

    /// Thresholds are monthly. They used to be applied to a lifetime pass
    /// total, so 50 was reachable once and then permanent.
    var accountabilityGrade: ReportGrade {
        if sessionsLogged >= 20 { return .a }
        if sessionsLogged >= 12 { return .bPlus }
        if sessionsLogged >= 6 { return .b }
        return .c
    }

    var growthGrade: ReportGrade {
        if newCertifications >= 3 { return .a }
        if newCertifications >= 2 { return .bPlus }
        if newCertifications >= 1 { return .b }
        return .c
    }

    // MARK: - Attendance grid (8 weeks × 7 days, Monday-first)

    var trainedToday: Bool {
        guard let last = lastTrainedDate else { return false }
        return calendar.isDateInToday(last)
    }

    var attendanceDays: [ActivityDay] {
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        let daysSinceMonday = (weekday - calendar.firstWeekday + 7) % 7
        guard let currentMonday = calendar.date(byAdding: .day, value: -daysSinceMonday, to: today),
              let firstMonday = calendar.date(byAdding: .day, value: -49, to: currentMonday) else {
            return []
        }

        return (0..<56).compactMap { index in
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
}
