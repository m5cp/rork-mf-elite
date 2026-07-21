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

/// One captured reflection note, surfaced on the Progress screen.
struct ReflectionNote: Identifiable {
    let id: String
    let date: Date
    let drillTitle: String
    let rating: Int
    let note: String
}

/// A summary of the most recently completed week, for the Monday recap.
struct WeeklyRecap: Equatable {
    /// Monday (start of day) of the week being summarized.
    let weekStart: Date
    /// e.g. "Jun 2 – Jun 8".
    let rangeLabel: String
    let drills: Int
    let xp: Int
    let trainedDays: Int
    let mastered: Int
    /// Weekday name of the most productive day, e.g. "Saturday"; nil if none.
    let bestDayName: String?
    let bestDayDrills: Int
    /// The rank held at the end of the week.
    let rank: AcademyRank
    /// True if the player crossed into a new rank during the week.
    let rankedUp: Bool
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
    private let workouts: [WorkoutRecord]
    private let calendar: Calendar

    /// disciplineID → mark, resolved once.
    private let markByDiscipline: [String: String]

    init(disciplines: [Discipline], sessions: [SessionLogEntry], progress: [DrillProgress], workouts: [WorkoutRecord] = []) {
        self.disciplines = disciplines.sorted { $0.sortIndex < $1.sortIndex }
        self.sessions = sessions
        self.progress = progress
        self.workouts = workouts

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

    /// Watch workouts started within the current week.
    private var thisWeekWorkouts: [WorkoutRecord] {
        guard let end = calendar.date(byAdding: .day, value: 7, to: currentMonday) else { return [] }
        return workouts.filter { $0.startedAt >= currentMonday && $0.startedAt < end }
    }

    var xpThisWeek: Int {
        thisWeekSessions.reduce(0) { $0 + $1.xpEarned }
            + thisWeekWorkouts.reduce(0) { $0 + $1.xpEarned }
    }

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

    // MARK: - Reflections

    /// All log entries that carry a felt rating, newest first.
    private var ratedSessions: [SessionLogEntry] {
        sessions.filter { $0.feltRating != nil }
            .sorted { $0.completedAt > $1.completedAt }
    }

    /// True once the player has rated at least one session.
    var hasReflections: Bool { !ratedSessions.isEmpty }

    /// Average felt rating (1–5) across the last 14 days, rounded to one decimal.
    var averageFeltRating: Double? {
        guard let cutoff = calendar.date(byAdding: .day, value: -14, to: Date()) else { return nil }
        let recent = ratedSessions.filter { $0.completedAt >= cutoff }.compactMap { $0.feltRating }
        guard !recent.isEmpty else { return nil }
        let avg = Double(recent.reduce(0, +)) / Double(recent.count)
        return (avg * 10).rounded() / 10
    }

    /// Plain-language descriptor for the average felt rating.
    var feltTrendLabel: String {
        guard let avg = averageFeltRating else { return "—" }
        switch avg {
        case ..<1.8: return "Brutal stretch"
        case ..<2.6: return "Tough stretch"
        case ..<3.5: return "Solid groove"
        case ..<4.3: return "Smooth lately"
        default:     return "Cruising — time to push"
        }
    }

    /// The most recent written reflections (up to `limit`).
    func recentReflections(limit: Int = 3) -> [ReflectionNote] {
        ratedSessions.compactMap { entry -> ReflectionNote? in
            guard let rating = entry.feltRating,
                  let note = entry.reflection,
                  !note.isEmpty else { return nil }
            return ReflectionNote(
                id: entry.id.uuidString,
                date: entry.completedAt,
                drillTitle: entry.drillTitle,
                rating: rating,
                note: note
            )
        }
        .prefix(limit)
        .map { $0 }
    }

    // MARK: - Weekly recap (most recently completed week)

    /// A summary of last week (Mon–Sun) once that week is fully in the past.
    /// Returns nil if the player logged nothing last week. `currentXP` is the
    /// player's present total XP, used to derive rank movement across the week.
    func lastWeekRecap(currentXP: Int, hasFullAccess: Bool) -> WeeklyRecap? {
        let start = monday(weeksAgo: 1)
        let weekSessions = sessions(weekStarting: start)
        guard !weekSessions.isEmpty else { return nil }

        let xp = weekSessions.reduce(0) { $0 + $1.xpEarned }
        let trainedDays = Set(weekSessions.map { calendar.startOfDay(for: $0.completedAt) }).count

        // Best day of the week by drills logged.
        var perDay: [Date: Int] = [:]
        for entry in weekSessions {
            perDay[calendar.startOfDay(for: entry.completedAt), default: 0] += 1
        }
        let best = perDay.max { $0.value < $1.value }
        let dayNameFmt = DateFormatter(); dayNameFmt.dateFormat = "EEEE"
        let bestDayName = best.map { dayNameFmt.string(from: $0.key) }

        // Mastered drills last logged during that week.
        let mastered = progress.filter { entry in
            guard entry.isMastered, let date = entry.lastLoggedAt else { return false }
            let day = calendar.startOfDay(for: date)
            guard let end = calendar.date(byAdding: .day, value: 7, to: start) else { return false }
            return day >= start && day < end
        }.count

        // Rank movement: rank now vs. rank before last week's XP was earned.
        let rankNow = AcademyRank.unlockedRank(for: currentXP, hasFullAccess: hasFullAccess)
        let rankBefore = AcademyRank.unlockedRank(for: max(0, currentXP - xp), hasFullAccess: hasFullAccess)
        let rankedUp = rankNow.rawValue > rankBefore.rawValue

        let rangeFmt = DateFormatter(); rangeFmt.dateFormat = "MMM d"
        let endDate = calendar.date(byAdding: .day, value: 6, to: start) ?? start
        let rangeLabel = "\(rangeFmt.string(from: start)) – \(rangeFmt.string(from: endDate))"

        return WeeklyRecap(
            weekStart: start,
            rangeLabel: rangeLabel,
            drills: weekSessions.count,
            xp: xp,
            trainedDays: trainedDays,
            mastered: mastered,
            bestDayName: bestDayName,
            bestDayDrills: best?.value ?? 0,
            rank: rankNow,
            rankedUp: rankedUp
        )
    }

    // MARK: - Daily rings

    /// Today's three training rings (Train / Drills / Mind).
    var todayRings: DailyRings {
        DailyRings.make(from: sessions, workouts: workouts, on: Date(), calendar: calendar)
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
                rings: DailyRings.make(from: sessions, workouts: workouts, on: day, calendar: calendar),
                isToday: calendar.isDate(day, inSameDayAs: today),
                isFuture: day > today
            )
        }
    }
}
