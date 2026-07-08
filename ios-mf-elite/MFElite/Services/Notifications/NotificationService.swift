//
//  NotificationService.swift
//  MFElite
//
//  Local notifications for streak re-engagement and daily training reminders.
//

import Foundation
import UserNotifications

/// Categories used to identify and group MF Elite notifications.
enum NotificationCategory: String {
    case dailyReminder = "DAILY_REMINDER"
    case streakRisk = "STREAK_RISK"
    case milestone = "MILESTONE"
}

/// Stable identifiers so we can update or cancel individual notifications.
private enum NotificationID {
    static let dailyReminder = "mf.daily.reminder"
    static let streakRisk = "mf.streak.risk"
    static let coachWorkout = "mf.coach.workout"
    static let parentWeekly = "mf.parent.weekly"
    static func milestone(_ days: Int) -> String { "mf.milestone.\(days)" }
    static func gamePrep(_ gameID: UUID) -> String { "mf.game.prep.\(gameID.uuidString)" }
}

/// Schedules and cancels the app's local notifications.
final class NotificationService {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()

    private init() {}

    /// Honors the "Streak alerts" switch in Settings (`MF_NOTIF_STREAK`,
    /// default on). Streak-risk notifications are never queued when it's off.
    private var streakAlertsEnabled: Bool {
        let defaults = UserDefaults.standard
        return defaults.object(forKey: "MF_NOTIF_STREAK") == nil
            ? true
            : defaults.bool(forKey: "MF_NOTIF_STREAK")
    }

    // MARK: - Permission

    /// Requests alert/badge/sound authorization. Calls back with the granted flag.
    func requestPermission(completion: ((Bool) -> Void)? = nil) {
        center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            DispatchQueue.main.async {
                if granted { self.scheduleDailyReminder() }
                completion?(granted)
            }
        }
    }

    /// Returns the current authorization status (off the main actor).
    func authorizationStatus(completion: @escaping (UNAuthorizationStatus) -> Void) {
        center.getNotificationSettings { settings in
            DispatchQueue.main.async { completion(settings.authorizationStatus) }
        }
    }

    /// Schedules the daily reminder only if the user has already authorized
    /// notifications — never triggers the system permission prompt.
    func scheduleDailyReminderIfAuthorized() {
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }
            DispatchQueue.main.async { self.scheduleDailyReminder() }
        }
    }

    // MARK: - Daily reminder (7:00 AM, repeating)

    func scheduleDailyReminder() {
        let content = UNMutableNotificationContent()
        content.title = "MF Elite"
        content.body = "Your daily training is waiting. Keep the streak alive."
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.dailyReminder.rawValue

        var components = DateComponents()
        components.hour = 7
        components.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        let request = UNNotificationRequest(
            identifier: NotificationID.dailyReminder,
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    // MARK: - Streak at risk (8:00 PM today, one-shot)

    /// Schedules an evening warning if the player hasn't trained today.
    /// Skips scheduling if 8 PM has already passed.
    func scheduleStreakRisk(streak: Int) {
        cancelStreakRisk()
        guard streak > 0, streakAlertsEnabled else { return }

        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 20
        components.minute = 0
        guard let fireDate = calendar.date(from: components), fireDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Your \(streak)-day streak ends at midnight"
        content.body = "One drill is all it takes. Don't let it slip."
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.streakRisk.rawValue

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate),
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: NotificationID.streakRisk,
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    /// Re-arms the streak defense for TOMORROW evening (7:00 PM local). Called
    /// after a logged session so an active streak is always defended — today is
    /// already safe, so the warning moves to the next evening.
    func scheduleStreakRiskNextEvening(streak: Int) {
        cancelStreakRisk()
        guard streak > 0, streakAlertsEnabled else { return }

        let calendar = Calendar.current
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date())) else { return }
        var components = calendar.dateComponents([.year, .month, .day], from: tomorrow)
        components.hour = 19
        components.minute = 0

        let content = UNMutableNotificationContent()
        content.title = "Your \(streak)-day streak ends at midnight"
        content.body = "One drill is all it takes. Don't let it slip."
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.streakRisk.rawValue

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: NotificationID.streakRisk,
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    /// Cancels the evening warning — call this whenever a drill is logged.
    func cancelStreakRisk() {
        center.removePendingNotificationRequests(withIdentifiers: [NotificationID.streakRisk])
    }

    // MARK: - Coach workout (immediate, fire-once per new WOD)

    /// Fire-once alert when a new coach Workout of the Day lands during sync.
    func notifyCoachWorkout(coachName: String, title: String) {
        let content = UNMutableNotificationContent()
        content.title = "New workout from Coach \(coachName)"
        content.body = title
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.milestone.rawValue
        let request = UNNotificationRequest(
            identifier: NotificationID.coachWorkout,
            content: content,
            trigger: nil // deliver immediately
        )
        center.add(request)
    }

    // MARK: - Weekly parent summary (Sunday 6:00 PM, one-shot)

    /// Sunday 6:00 PM summary for the parent. Content is composed from this
    /// week's data at scheduling time; reschedule after every logged session so
    /// the numbers are current when it fires.
    func scheduleParentWeeklySummary(playerName: String, daysTrained: Int, drillsDone: Int, streak: Int) {
        center.removePendingNotificationRequests(withIdentifiers: [NotificationID.parentWeekly])

        let content = UNMutableNotificationContent()
        content.title = "\(playerName)'s training week"
        content.body = "Trained \(daysTrained) of 7 days · \(drillsDone) drills · \(streak)-day streak. Open the parent report for details."
        content.sound = .default

        var comps = DateComponents()
        comps.weekday = 1 // Sunday
        comps.hour = 18
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        center.add(UNNotificationRequest(identifier: NotificationID.parentWeekly, content: content, trigger: trigger))
    }

    /// Removes any pending parent summary — used when no family context exists.
    func cancelParentWeeklySummary() {
        center.removePendingNotificationRequests(withIdentifiers: [NotificationID.parentWeekly])
    }

    // MARK: - Milestone (one-shot, fires shortly after reaching it)

    func scheduleMilestone(days: Int, name: String) {
        let content = UNMutableNotificationContent()
        content.title = "Streak milestone: \(name)"
        content.body = "\(days) days of discipline. Keep building."
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.milestone.rawValue

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(
            identifier: NotificationID.milestone(days),
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    // MARK: - Game prep (7:00 PM the evening before a scheduled game)

    /// Schedules a one-shot reminder at 7:00 PM the evening before a scheduled
    /// game. Skipped when that evening has already passed. Adds nothing when
    /// notifications aren't authorized — never triggers the permission prompt.
    func scheduleGamePrepReminder(gameID: UUID, gameDate: Date, opponent: String) {
        let cal = Calendar.current
        guard let evening = cal.date(
            bySettingHour: 19, minute: 0, second: 0,
            of: cal.date(byAdding: .day, value: -1, to: gameDate) ?? gameDate
        ), evening > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = opponent.isEmpty ? "Game tomorrow" : "Game tomorrow vs \(opponent)"
        content.body = "Do your Match Day prep tonight — activate, visualize, lock in."
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.milestone.rawValue
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: cal.dateComponents([.year, .month, .day, .hour, .minute], from: evening),
            repeats: false
        )
        center.add(UNNotificationRequest(
            identifier: NotificationID.gamePrep(gameID), content: content, trigger: trigger))
    }

    /// Cancels the night-before reminder for a deleted game.
    func cancelGamePrepReminder(gameID: UUID) {
        center.removePendingNotificationRequests(
            withIdentifiers: [NotificationID.gamePrep(gameID)])
    }

    // MARK: - Cleanup

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }
}
