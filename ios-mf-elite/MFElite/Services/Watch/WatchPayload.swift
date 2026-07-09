//
//  WatchPayload.swift
//  MFElite
//
//  Data shapes shared between the phone, the watch app, and the watch
//  complication. Not a shared framework — this file is intentionally
//  duplicated (identical) in the MFEliteWatch and MFEliteWatchComplication
//  targets so each compiles independently. Keep all three copies in sync if
//  the shape ever changes.
//

import Foundation

/// Snapshot of "what's happening today," pushed from the phone to the watch
/// via WatchConnectivity and mirrored into the shared App Group so the
/// watch-face complication can read it without the watch app running.
struct WatchGlanceData: Codable, Equatable {
    var sessionTitle: String
    var sessionEyebrow: String
    var sessionMinutes: Int
    var drills: [WatchDrillItem]
    var trainMinutes: Int
    var trainGoalMinutes: Int
    var drillCount: Int
    var drillGoal: Int
    var mindCount: Int
    var mindGoal: Int
    var streak: Int
    var xp: Int
    var steps: Int
    var stepGoal: Int
    var updatedAt: Date

    static let empty = WatchGlanceData(
        sessionTitle: "Open MF Elite",
        sessionEyebrow: "on your phone to sync",
        sessionMinutes: 0,
        drills: [],
        trainMinutes: 0, trainGoalMinutes: 20,
        drillCount: 0, drillGoal: 3,
        mindCount: 0, mindGoal: 1,
        streak: 0, xp: 0,
        steps: 0, stepGoal: 8000,
        updatedAt: .distantPast
    )

    /// All three daily rings closed.
    var allRingsClosed: Bool {
        trainMinutes >= trainGoalMinutes && drillCount >= drillGoal && mindCount >= mindGoal
    }
}

/// A single drill within today's session, simplified for the wrist (no full
/// curriculum navigation context — just enough to run set/rest timers).
struct WatchDrillItem: Codable, Equatable, Identifiable {
    var id: String
    var title: String
    var sets: Int
    var workSec: Int
    var restSec: Int
}

/// Sent from the watch back to the phone when a session is quick-logged from
/// the wrist. The phone applies it through the exact same `QuickLog` pipeline
/// used for a phone-side quick log, so XP/streak/history stay one source of truth.
struct WatchQuickLogRequest: Codable {
    var drillIDs: [String]
    var sourceName: String
}

/// The shared App Group suite name both the phone app, watch app, and watch
/// complication read/write the latest glance snapshot from.
enum WatchShared {
    static let appGroupID = "group.app.rork.pgx8pb996dmcvbhdfnx8x"
    static let glanceKey = "MF_WATCH_GLANCE_DATA"

    static var defaults: UserDefaults? { UserDefaults(suiteName: appGroupID) }

    static func save(_ data: WatchGlanceData) {
        guard let encoded = try? JSONEncoder().encode(data) else { return }
        defaults?.set(encoded, forKey: glanceKey)
    }

    static func load() -> WatchGlanceData {
        guard let data = defaults?.data(forKey: glanceKey),
              let decoded = try? JSONDecoder().decode(WatchGlanceData.self, from: data) else {
            return .empty
        }
        return decoded
    }
}
