//
//  WorkoutRecord.swift
//  MFElite
//
//  A finished Apple Watch workout stored on the phone: mode, stats, and (for
//  outdoor modes) the GPS route plus a pre-rendered route-map image path. Feeds
//  the calendar day view and the Progress tab.
//

import Foundation
import SwiftData

@Model
final class WorkoutRecord {
    @Attribute(.unique) var id: String
    var modeRaw: String
    var startedAt: Date
    var durationSec: Int
    var distanceMeters: Double
    var activeCalories: Double
    var avgHeartRate: Int
    var maxHeartRate: Int
    /// JSON-encoded [WatchRoutePoint] for re-rendering a larger interactive map.
    var routeData: Data?
    /// Filename (in Documents) of the pre-rendered route-map thumbnail image.
    var routeImageName: String?

    init(
        id: String,
        modeRaw: String,
        startedAt: Date,
        durationSec: Int,
        distanceMeters: Double,
        activeCalories: Double,
        avgHeartRate: Int,
        maxHeartRate: Int,
        routeData: Data? = nil,
        routeImageName: String? = nil
    ) {
        self.id = id
        self.modeRaw = modeRaw
        self.startedAt = startedAt
        self.durationSec = durationSec
        self.distanceMeters = distanceMeters
        self.activeCalories = activeCalories
        self.avgHeartRate = avgHeartRate
        self.maxHeartRate = maxHeartRate
        self.routeData = routeData
        self.routeImageName = routeImageName
    }

    var mode: WorkoutModeID { WorkoutModeID(rawValue: modeRaw) ?? .outdoorRun }

    /// Decoded GPS route points, or empty for indoor workouts.
    var routePoints: [WatchRoutePoint] {
        guard let routeData else { return [] }
        return (try? JSONDecoder().decode([WatchRoutePoint].self, from: routeData)) ?? []
    }
}
