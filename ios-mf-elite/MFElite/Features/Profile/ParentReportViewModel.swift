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

    /// Drill IDs the player has mastered.
    private let masteredDrillIDs: Set<String>
    /// Total honest sessions logged across the curriculum.
    let sessionsLogged: Int

    private let calendar: Calendar
    private let trainedDates: Set<Date>

    init(
        disciplines: [Discipline],
        xp: Int,
        streak: Int,
        lastTrainedDate: Date?,
        masteredDrillIDs: Set<String>,
        sessionsLogged: Int
    ) {
        self.disciplines = disciplines.sorted { $0.sortIndex < $1.sortIndex }
        self.xp = xp
        self.streak = streak
        self.lastTrainedDate = lastTrainedDate
        self.masteredDrillIDs = masteredDrillIDs
        self.sessionsLogged = sessionsLogged

        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday
        self.calendar = cal

        let anchor = cal.startOfDay(for: lastTrainedDate ?? Date())
        var dates: Set<Date> = []
        for offset in 0..<max(0, streak) {
            if let day = cal.date(byAdding: .day, value: -offset, to: anchor) {
                dates.insert(day)
            }
        }
        self.trainedDates = dates
    }

    var currentRank: AcademyRank { AcademyRank.rank(for: xp) }

    // MARK: - Pillar stats

    /// Percentage of scheduled training days completed this month.
    /// TODO: derive from a real attendance log once the coach back-end is wired.
    var consistencyPercent: Int { 86 }

    /// Drills mastered this month.
    var drillsMastered: Int { masteredDrillIDs.count }

    /// New certifications earned this month.
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

    var accountabilityGrade: ReportGrade {
        if sessionsLogged >= 50 { return .a }
        if sessionsLogged >= 30 { return .bPlus }
        if sessionsLogged >= 15 { return .b }
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
