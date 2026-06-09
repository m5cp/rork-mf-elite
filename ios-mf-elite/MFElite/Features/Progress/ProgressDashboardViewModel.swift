//
//  ProgressDashboardViewModel.swift
//  MFElite
//
//  Derives the Progress tab analytics — weekly/monthly training stats — from
//  the per-session training log (SessionLogEntry). Mastery counts still come
//  from DrillProgress, which drives certifications.
//

import Foundation
import Observation

/// One bar in the 7-day weekly chart.
struct DayBar: Identifiable {
    let id: Int
    let initial: String
    let count: Int
    let isToday: Bool
}

/// One row in the 4-week monthly trend chart.
struct WeekBar: Identifiable {
    let id: Int
    let label: String
    let sessions: Int
}

/// One discipline's monthly session count.
struct DisciplineStat: Identifiable {
    let id: String
    let name: String
    let mark: String
    let sessions: Int
}

/// One drill logged on a given day, with discipline context (for WeeklyView).
struct LoggedDrill: Identifiable {
    let id: String
    let title: String
    let mark: String
    let xp: Int
}

/// One day in the 7-day ring strip.
struct RingStripDay: Identifiable {
    let id: Int
    let date: Date
    let initial: String
    let rings: DailyRings
    let isToday: Bool
    let isFuture: Bool
}

/// One day in the weekly breakdown.
struct WeekDay: Identifiable {
    let id: Int
    let date: Date
    let name: String
    let shortDate: String
    let drills: [LoggedDrill]
    let isFuture: Bool

    var totalXP: Int { drills.reduce(0) { $0 + $1.xp } }
}

@MainActor
@Observable
final class ProgressDashboardViewModel {
    private let disciplines: [Discipline]
    private let sessions: [SessionLogEntry]
    private let progress: [DrillProgress]
    private let calendar: Calendar

    /// disciplineID → mark, resolved once.
    private let markByDiscipline: [String: String]

    init(disciplines: [Discipline], sessions: [SessionLogEntry], progress: [DrillProgress]) {
        self.disciplines = disciplines.sorted { $0.sortIndex < $1.sortIndex }
        self.sessions = sessions
        self.progress = progress

        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday
        self.calendar = cal

        var map: [String: String] = [:]
        for discipline in self.disciplines {
            map[discipline.id] = discipline.mark
        }
        self.markByDiscipline = map
    }

    // MARK: - Week anchors

    /// Monday (start of day) for the current week.
    private var currentMonday: Date {
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        let daysSinceMonday = (weekday - calendar.firstWeekday + 7) % 7
        return calendar.date(byAdding: .day, value: -daysSinceMonday, to: today) ?? today
    }

    private func monday(weeksAgo: Int) -> Date {
        calendar.date(byAdding: .day, value: -7 * weeksAgo, to: currentMonday) ?? currentMonday
    }

    /// Sessions whose completion falls within [start, start+7days).
    private func sessions(weekStarting start: Date) -> [SessionLogEntry] {
        guard let end = calendar.date(byAdding: .day, value: 7, to: start) else { return [] }
        return sessions.filter { $0.completedAt >= start && $0.completedAt < end }
    }

    // MARK: - This week summary

    private var thisWeekSessions: [SessionLogEntry] {
        sessions(weekStarting: currentMonday)
    }

    var sessionsThisWeek: Int { thisWeekSessions.count }

    var xpThisWeek: Int { thisWeekSessions.reduce(0) { $0 + $1.xpEarned } }

    /// Distinct drills that reached mastery and were last logged this week.
    var masteredThisWeek: Int {
        progress.filter { entry in
            guard entry.isMastered, let date = entry.lastLoggedAt else { return false }
            let day = calendar.startOfDay(for: date)
            return day >= currentMonday
        }.count
    }

    // MARK: - 7-day bar chart

    var dayBars: [DayBar] {
        let initials = ["M", "T", "W", "T", "F", "S", "S"]
        let today = calendar.startOfDay(for: Date())
        var counts = Array(repeating: 0, count: 7)

        for entry in thisWeekSessions {
            let day = calendar.startOfDay(for: entry.completedAt)
            let offset = calendar.dateComponents([.day], from: currentMonday, to: day).day ?? 0
            if offset >= 0 && offset < 7 { counts[offset] += 1 }
        }

        let todayOffset = calendar.dateComponents([.day], from: currentMonday, to: today).day ?? -1

        return (0..<7).map { index in
            DayBar(id: index, initial: initials[index], count: counts[index], isToday: index == todayOffset)
        }
    }

    var maxDayCount: Int { max(1, dayBars.map { $0.count }.max() ?? 1) }

    // MARK: - Monthly trend (last 4 weeks)

    var weekBars: [WeekBar] {
        (0..<4).map { index in
            // index 0 = oldest (3 weeks ago), index 3 = this week
            let weeksAgo = 3 - index
            let count = sessions(weekStarting: monday(weeksAgo: weeksAgo)).count
            return WeekBar(id: index, label: "WK \(index + 1)", sessions: count)
        }
    }

    var maxWeekSessions: Int { max(1, weekBars.map { $0.sessions }.max() ?? 1) }

    // MARK: - Intensity

    /// Distinct days trained this week.
    private var trainedDaysThisWeek: Int {
        let days = Set(thisWeekSessions.map { calendar.startOfDay(for: $0.completedAt) })
        return days.count
    }

    var averageDrillsPerSession: Int {
        guard trainedDaysThisWeek > 0 else { return 0 }
        return Int((Double(sessionsThisWeek) / Double(trainedDaysThisWeek)).rounded())
    }

    /// 1...5 intensity level based on average drills per active day.
    var intensityLevel: Int {
        let avg = trainedDaysThisWeek > 0 ? Double(sessionsThisWeek) / Double(trainedDaysThisWeek) : 0
        switch avg {
        case ..<0.5:  return 0
        case ..<2:    return 1
        case ..<4:    return 2
        case ..<6:    return 3
        case ..<8:    return 4
        default:      return 5
        }
    }

    var intensityLabel: String {
        switch intensityLevel {
        case 0:  return "RESTING"
        case 1:  return "LIGHT"
        case 2:  return "MODERATE"
        case 3:  return "STRONG"
        case 4:  return "INTENSE"
        default: return "ELITE"
        }
    }

    // MARK: - Discipline breakdown (this month)

    var disciplineStats: [DisciplineStat] {
        let start = calendar.startOfDay(for: monthStart)
        var counts: [String: Int] = [:]
        for entry in sessions where entry.completedAt >= start {
            counts[entry.disciplineID, default: 0] += 1
        }
        return disciplines.map { discipline in
            DisciplineStat(
                id: discipline.id,
                name: discipline.name,
                mark: discipline.mark,
                sessions: counts[discipline.id] ?? 0
            )
        }
    }

    private var monthStart: Date {
        let comps = calendar.dateComponents([.year, .month], from: Date())
        return calendar.date(from: comps) ?? Date()
    }

    // MARK: - Weekly breakdown (Monday → today)

    var weekRangeLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let today = calendar.startOfDay(for: Date())
        let endLabel = formatter.string(from: today)
        let startLabel = formatter.string(from: currentMonday)
        return "\(startLabel) – \(endLabel)"
    }

    var weekDays: [WeekDay] {
        let today = calendar.startOfDay(for: Date())
        let dayNameFmt = DateFormatter(); dayNameFmt.dateFormat = "EEEE"
        let shortFmt = DateFormatter(); shortFmt.dateFormat = "MMM d"

        // Map each day to the drills logged that day.
        var drillsByDay: [Date: [LoggedDrill]] = [:]
        for entry in sessions {
            let day = calendar.startOfDay(for: entry.completedAt)
            guard day >= currentMonday && day <= today else { continue }
            let logged = LoggedDrill(
                id: entry.id.uuidString,
                title: entry.drillTitle,
                mark: markByDiscipline[entry.disciplineID] ?? "square",
                xp: entry.xpEarned
            )
            drillsByDay[day, default: []].append(logged)
        }

        // Number of days from Monday through today, inclusive.
        let span = (calendar.dateComponents([.day], from: currentMonday, to: today).day ?? 0) + 1
        return (0..<max(1, span)).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: currentMonday) else { return nil }
            let day = calendar.startOfDay(for: date)
            return WeekDay(
                id: offset,
                date: day,
                name: dayNameFmt.string(from: day),
                shortDate: shortFmt.string(from: day),
                drills: drillsByDay[day] ?? [],
                isFuture: day > today
            )
        }
    }

    var weeklyTotalSessions: Int { weekDays.reduce(0) { $0 + $1.drills.count } }
    var weeklyTotalXP: Int { weekDays.reduce(0) { $0 + $1.totalXP } }
    var weeklyTotalMastered: Int { masteredThisWeek }
    var weeklyTrainedDays: Int { weekDays.filter { !$0.drills.isEmpty }.count }

    // MARK: - Daily rings

    /// Today's three training rings (Train / Drills / Mind).
    var todayRings: DailyRings {
        DailyRings.make(from: sessions, on: Date(), calendar: calendar)
    }

    /// The current week as a Mon–Sun strip of ring clusters.
    var ringStripDays: [RingStripDay] {
        let initials = ["M", "T", "W", "T", "F", "S", "S"]
        let today = calendar.startOfDay(for: Date())
        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: currentMonday) else { return nil }
            let day = calendar.startOfDay(for: date)
            return RingStripDay(
                id: offset,
                date: day,
                initial: initials[offset],
                rings: DailyRings.make(from: sessions, on: day, calendar: calendar),
                isToday: calendar.isDate(day, inSameDayAs: today),
                isFuture: day > today
            )
        }
    }
}
