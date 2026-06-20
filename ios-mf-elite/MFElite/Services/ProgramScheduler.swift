//
//  ProgramScheduler.swift
//  MFElite
//
//  Lays a training program's days across the upcoming weeks and writes them to
//  the device calendar as events with reminders. Rest days are skipped. Pure
//  EventKit; asks for write access on first use.
//

import Foundation
import EventKit

/// One planned calendar entry previewed before anything is written.
struct ScheduledTrainingDay: Identifiable {
    let id = UUID()
    let date: Date
    let title: String
    let weekIndex: Int
    let dayIndex: Int
}

@MainActor
final class ProgramScheduler {
    static let shared = ProgramScheduler()

    private let store = EKEventStore()

    private init() {}

    /// Build the full list of training days for a program starting on `startDate`,
    /// only on the selected weekdays (1 = Sunday … 7 = Saturday). Rest days are
    /// skipped but still consume a slot in the program's day order.
    func plan(
        program: TrainingProgram,
        startDate: Date,
        weekdays: Set<Int>,
        atHour hour: Int
    ) -> [ScheduledTrainingDay] {
        guard !weekdays.isEmpty else { return [] }
        let calendar = Calendar.current
        var result: [ScheduledTrainingDay] = []
        var cursor = calendar.startOfDay(for: startDate)

        // Flatten non-rest days in order, remembering their week/day position.
        var sessions: [(week: Int, day: Int, title: String)] = []
        for (w, week) in program.weeks.enumerated() {
            for (d, day) in week.days.enumerated() where !day.isRest {
                sessions.append((w, d, day.title))
            }
        }

        var placed = 0
        var safety = 0
        while placed < sessions.count, safety < 400 {
            safety += 1
            let weekday = calendar.component(.weekday, from: cursor)
            if weekdays.contains(weekday) {
                let session = sessions[placed]
                if let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: cursor) {
                    result.append(ScheduledTrainingDay(
                        date: date,
                        title: session.title,
                        weekIndex: session.week,
                        dayIndex: session.day
                    ))
                }
                placed += 1
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return result
    }

    /// Request write access to the calendar (iOS 17+ full/ write-only API).
    func requestAccess() async -> Bool {
        do {
            return try await store.requestWriteOnlyAccessToEvents()
        } catch {
            return false
        }
    }

    /// Write the planned days to the default calendar as 45-minute events with a
    /// one-hour-before reminder. Returns the number of events added.
    func addToCalendar(
        _ days: [ScheduledTrainingDay],
        programTitle: String,
        reminderMinutesBefore: Int = 60
    ) -> Int {
        guard store.defaultCalendarForNewEvents != nil else { return 0 }
        var added = 0
        for day in days {
            let event = EKEvent(eventStore: store)
            event.title = "MF Elite — \(day.title)"
            event.notes = "Training day from your \(programTitle)."
            event.startDate = day.date
            event.endDate = day.date.addingTimeInterval(45 * 60)
            event.calendar = store.defaultCalendarForNewEvents
            event.addAlarm(EKAlarm(relativeOffset: TimeInterval(-reminderMinutesBefore * 60)))
            do {
                try store.save(event, span: .thisEvent, commit: false)
                added += 1
            } catch {
                continue
            }
        }
        try? store.commit()
        return added
    }
}
