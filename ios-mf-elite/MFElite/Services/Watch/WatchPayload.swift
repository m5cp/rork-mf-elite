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

// MARK: - Watch workouts (Apple Fitness-style)

/// Identifies a watch workout mode. rawValue is stable for sync + storage.
enum WorkoutModeID: String, Codable, CaseIterable, Identifiable {
    case outdoorRun, walk, cycle, outdoorWorkout
    case treadmill, elliptical, interval, strength, functional
    case soccerSkills
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .outdoorRun: return "Outdoor Run"
        case .walk: return "Walk"
        case .cycle: return "Cycle"
        case .outdoorWorkout: return "Outdoor Workout"
        case .treadmill: return "Treadmill"
        case .elliptical: return "Elliptical"
        case .interval: return "Interval"
        case .strength: return "Strength Training"
        case .functional: return "Functional Fitness"
        case .soccerSkills: return "Soccer Skills Field"
        }
    }

    var symbol: String {
        switch self {
        case .outdoorRun: return "figure.run"
        case .walk: return "figure.walk"
        case .cycle: return "figure.outdoor.cycle"
        case .outdoorWorkout: return "figure.mixed.cardio"
        case .treadmill: return "figure.run"
        case .elliptical: return "figure.elliptical"
        case .interval: return "figure.highintensity.intervaltraining"
        case .strength: return "figure.strengthtraining.traditional"
        case .functional: return "figure.strengthtraining.functional"
        case .soccerSkills: return "soccerball"
        }
    }

    var accentHex: String {
        switch self {
        case .outdoorRun: return "#30D158"
        case .walk: return "#64D2FF"
        case .cycle: return "#FFD60A"
        case .outdoorWorkout: return "#BF5AF2"
        case .treadmill: return "#FF9F0A"
        case .elliptical: return "#FF375F"
        case .interval: return "#FF453A"
        case .strength: return "#5E5CE6"
        case .functional: return "#0A84FF"
        case .soccerSkills: return "#E8B84B"
        }
    }

    /// Outdoor modes record a GPS route; indoor modes skip location.
    var isOutdoor: Bool {
        switch self {
        case .outdoorRun, .walk, .cycle, .outdoorWorkout, .soccerSkills: return true
        case .treadmill, .elliptical, .interval, .strength, .functional: return false
        }
    }
}

/// One GPS point in a recorded workout route.
struct WatchRoutePoint: Codable, Equatable {
    var lat: Double
    var lng: Double
}

/// A finished watch workout, sent from the watch to the phone and stored.
struct WatchWorkoutResult: Codable, Equatable, Identifiable {
    var id: String
    var modeRaw: String
    var startedAt: Date
    var durationSec: Int
    var distanceMeters: Double
    var activeCalories: Double
    var avgHeartRate: Int
    var maxHeartRate: Int
    var route: [WatchRoutePoint]

    var mode: WorkoutModeID { WorkoutModeID(rawValue: modeRaw) ?? .outdoorRun }
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
