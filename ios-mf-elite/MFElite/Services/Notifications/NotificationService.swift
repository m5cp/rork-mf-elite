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
    case coachAnnouncement = "COACH_ANNOUNCEMENT"
}

/// Stable identifiers so we can update or cancel individual notifications.
private enum NotificationID {
    static let dailyReminder = "mf.daily.reminder"
    static let streakRisk = "mf.streak.risk"
    static func milestone(_ days: Int) -> String { "mf.milestone.\(days)" }
}

/// Schedules and cancels the app's local notifications.
final class NotificationService {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()

    private init() {}

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
        guard streak > 0 else { return }

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

    /// Cancels the evening warning — call this whenever a drill is logged.
    func cancelStreakRisk() {
        center.removePendingNotificationRequests(withIdentifiers: [NotificationID.streakRisk])
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

    // MARK: - Cleanup

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }
}
