//
//  WorkoutStore.swift
//  MFElite
//
//  The one place a finished workout becomes a stored `WorkoutRecord`, whichever
//  device recorded it: an Apple Watch session arriving over WatchConnectivity,
//  or a GPS run tracked on the phone. Both go through here so the route map, the
//  XP award and the cloud mirror can never drift apart between the two, and so a
//  workout that somehow reaches us twice is only ever written once.
//

import Foundation
import SwiftData

@MainActor
enum WorkoutStore {
    /// Persist a finished workout: insert the record, fold its XP into the
    /// player, queue both for the cloud, and render the GPS route into a map
    /// image. Returns nil when nothing was written — either the workout is
    /// degenerate, or a record with this id already exists.
    @discardableResult
    static func save(_ result: WatchWorkoutResult, context: ModelContext) async -> WorkoutRecord? {
        // A zero-length workout is a start/stop misfire, not a session, and
        // `xpEarned` floors at one drill's worth — so storing it would quietly
        // hand out XP for nothing.
        guard result.durationSec > 0 else { return nil }

        let id = result.id
        let existing = try? context.fetch(FetchDescriptor<WorkoutRecord>(
            predicate: #Predicate { $0.id == id }
        ))
        guard (existing?.isEmpty ?? true) else { return nil }

        // Indoor modes never record a route; store nil rather than an empty blob.
        var routeData: Data? = nil
        if !result.route.isEmpty {
            routeData = try? JSONEncoder().encode(result.route)
        }

        // Insert and award BEFORE the map render. The renderer suspends for the
        // best part of a second waiting on MKMapSnapshotter, and two calls with
        // the same id (a re-delivered watch transfer, or the run screen's Finish
        // and close buttons both firing) would otherwise both clear the
        // duplicate check while the first one is parked on that await.
        let record = WorkoutRecord(
            id: id,
            modeRaw: result.modeRaw,
            startedAt: result.startedAt,
            durationSec: result.durationSec,
            distanceMeters: result.distanceMeters,
            activeCalories: result.activeCalories,
            avgHeartRate: result.avgHeartRate,
            maxHeartRate: result.maxHeartRate,
            routeData: routeData
        )
        context.insert(record)

        // Fold the workout's XP into the player's running total. Safe to do here
        // because this path is guarded against duplicate ids above.
        if let player = try? context.fetch(FetchDescriptor<PlayerState>()).first {
            player.xp += record.xpEarned
            // Push the XP change AND the workout summary to the cloud — without
            // these, workout-earned XP and workouts never leave the device.
            SyncEngine.shared.enqueuePlayerState(player)
        }
        SyncEngine.shared.enqueueWorkoutRecord(record)

        try? context.save()

        // The route map is a PNG on disk, not synced state, so it can land after
        // the record is already visible in the calendar and Progress tab.
        if result.mode.isOutdoor, result.route.count > 1 {
            record.routeImageName = await WorkoutRouteRenderer.renderAndSave(
                points: result.route, accentHex: result.mode.accentHex, id: id
            )
            try? context.save()
        }

        // Minutes just moved the Train ring and XP just moved the player — the
        // wrist glance and complication read both.
        WatchSyncBridge.shared.refreshAndPush()

        return record
    }
}
