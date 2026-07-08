//
//  PostSessionNotifications.swift
//  MFElite
//
//  Re-arms the app's "defensive" local notifications after any logged training:
//  cancels tonight's streak-risk warning (they trained), queues one for tomorrow
//  evening so an active streak is always defended, and keeps the Sunday parent
//  summary carrying this week's real numbers. Read-only against SwiftData —
//  never touches XP, streak computation, or history writing.
//

import Foundation
import SwiftData

@MainActor
enum PostSessionNotifications {
    /// Call at the same layer where a session log is saved (timer session,
    /// quick log, Game IQ lesson). Safe to call repeatedly.
    static func refresh(streak: Int, context: ModelContext) {
        let service = NotificationService.shared
        service.cancelStreakRisk()
        service.scheduleStreakRiskNextEvening(streak: streak)
        rescheduleParentWeekly(streak: streak, context: context)
    }

    /// True when this device has a family/parent setup — the same context that
    /// exposes the parent report (managed athletes, multiple athletes, or an
    /// enabled parent gate). Solo players get no parent notification.
    private static var hasFamilyContext: Bool {
        let family = FamilyStore.shared
        return family.hasMultipleAthletes
            || family.athletes.contains(where: { $0.managed })
            || ParentGate.shared.isEnabled
    }

    /// Composes this week's numbers (same data the Progress tab reads) and
    /// re-queues the Sunday 6 PM parent summary so it's current when it fires.
    private static func rescheduleParentWeekly(streak: Int, context: ModelContext) {
        guard hasFamilyContext else {
            NotificationService.shared.cancelParentWeeklySummary()
            return
        }

        let calendar = Calendar.current
        guard let week = calendar.dateInterval(of: .weekOfYear, for: Date()) else { return }
        let start = week.start
        let end = week.end
        let descriptor = FetchDescriptor<SessionLogEntry>(
            predicate: #Predicate { $0.completedAt >= start && $0.completedAt < end }
        )
        let entries = (try? context.fetch(descriptor)) ?? []
        let daysTrained = Set(entries.map { calendar.startOfDay(for: $0.completedAt) }).count

        let playerName = FamilyStore.shared.activeAthlete?.displayName
            ?? PlayerProfileStore.shared.displayName

        NotificationService.shared.scheduleParentWeeklySummary(
            playerName: playerName.isEmpty ? "Your player" : playerName,
            daysTrained: daysTrained,
            drillsDone: entries.count,
            streak: streak
        )
    }
}
