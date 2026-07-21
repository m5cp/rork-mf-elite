//
//  WatchSyncBridge.swift
//  MFElite
//
//  Phone-side half of the Apple Watch companion. Pushes a lightweight
//  "what's happening today" snapshot to the watch (and the shared App Group,
//  for the complication) whenever anything relevant changes, and applies
//  quick-logs the player makes on the wrist through the exact same
//  `QuickLog` pipeline used for a phone-side quick log — so XP, streak, and
//  history stay one source of truth regardless of which device logged them.
//

import Foundation
import SwiftData
import WatchConnectivity
import UIKit

@MainActor
@Observable
final class WatchSyncBridge: NSObject {
    static let shared = WatchSyncBridge()

    private var context: ModelContext?
    private var session: WCSession?

    private override init() {
        super.init()
    }

    /// Called once from the app entry point so the bridge can read/write
    /// SwiftData when the watch asks for a refresh or sends a quick-log.
    func configure(context: ModelContext) {
        self.context = context
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        self.session = session
    }

    /// Rebuild today's snapshot and push it to the watch (application context —
    /// delivered even if the watch app isn't foregrounded) and to the shared
    /// App Group so the complication can render without the watch app running.
    func refreshAndPush() {
        guard let context else { return }
        let payload = Self.buildGlanceData(context: context)
        WatchShared.save(payload)
        guard let session, session.activationState == .activated, session.isPaired else { return }
        guard let encoded = try? JSONEncoder().encode(payload) else { return }
        try? session.updateApplicationContext(["glance": encoded])
    }

    // MARK: - Building today's snapshot

    /// Mirrors the same fallback chain as the phone's Today hero card
    /// (active plan → latest coach workout → day-of-week default), simplified
    /// for the wrist. Kept intentionally standalone so it never risks touching
    /// the phone UI's own resolution logic.
    private static func buildGlanceData(context: ModelContext) -> WatchGlanceData {
        let disciplines = (try? context.fetch(FetchDescriptor<Discipline>())) ?? []
        var index: [String: DrillContext] = [:]
        for discipline in disciplines {
            for category in discipline.categories {
                for level in category.levels {
                    for drill in level.drills {
                        index[drill.id] = DrillContext(drill: drill, level: level, category: category, discipline: discipline)
                    }
                }
            }
        }

        var title = "Workout of the Day"
        var eyebrow = "MF Elite"
        var drillIDs: [String] = []

        if let plan = try? context.fetch(FetchDescriptor<ActivePlan>()).first, !plan.isFinished {
            let idx = min(max(plan.currentSessionIndex, 0), plan.sessions.count - 1)
            if plan.sessions.indices.contains(idx) { drillIDs = plan.sessions[idx] }
            if !drillIDs.isEmpty {
                title = plan.title
                eyebrow = "Your Plan"
            }
        }
        if drillIDs.isEmpty {
            var wodDescriptor = FetchDescriptor<CoachWorkout>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
            wodDescriptor.fetchLimit = 1
            if let wod = try? context.fetch(wodDescriptor).first {
                drillIDs = wod.drillIDs
                if !drillIDs.isEmpty {
                    title = wod.title
                    eyebrow = "From Coach \(wod.coachName)"
                }
            }
        }
        if drillIDs.isEmpty {
            let all = RoutineCatalog.all
            let dayIndex = Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
            let spec = all[dayIndex % all.count]
            drillIDs = spec.drillIDs
            title = spec.title
            eyebrow = "Workout of the Day"
        }

        let resolved = drillIDs.compactMap { index[$0] }
        let watchDrills = resolved.map {
            WatchDrillItem(
                id: $0.drill.id,
                title: $0.drill.title,
                sets: max(1, $0.drill.sets),
                workSec: max(10, $0.drill.durationSec / max(1, $0.drill.sets)),
                restSec: 20
            )
        }

        let sessions = (try? context.fetch(FetchDescriptor<SessionLogEntry>())) ?? []
        let players = (try? context.fetch(FetchDescriptor<PlayerState>())) ?? []
        let rings = DailyRings.make(from: sessions, on: Date())
        let health = HealthKitService.shared

        return WatchGlanceData(
            sessionTitle: title,
            sessionEyebrow: eyebrow,
            sessionMinutes: estimatedSessionMinutes(forDrills: resolved.map(\.drill)),
            drills: watchDrills,
            trainMinutes: rings.trainMinutes,
            trainGoalMinutes: DailyRings.trainGoalMinutes,
            drillCount: rings.drillCount,
            drillGoal: DailyRings.drillGoal,
            mindCount: rings.mindCount,
            mindGoal: DailyRings.mindGoal,
            streak: players.first?.streak ?? 0,
            xp: players.first?.xp ?? 0,
            steps: 0,
            stepGoal: health.stepGoal,
            updatedAt: Date()
        )
    }

    // MARK: - Applying a wrist quick-log

    /// A drill session logged entirely on the watch, mirrored to the phone's
    /// data store through the standard `QuickLog` pipeline.
    fileprivate func applyQuickLog(_ request: WatchQuickLogRequest) {
        guard let context else { return }
        let disciplines = (try? context.fetch(FetchDescriptor<Discipline>())) ?? []
        var index: [String: DrillContext] = [:]
        for discipline in disciplines {
            for category in discipline.categories {
                for level in category.levels {
                    for drill in level.drills {
                        index[drill.id] = DrillContext(drill: drill, level: level, category: category, discipline: discipline)
                    }
                }
            }
        }
        let items = request.drillIDs.compactMap { index[$0] }
        guard !items.isEmpty else { return }
        QuickLog.logDrills(items, source: .workout, sourceName: request.sourceName, context: context)
        refreshAndPush()
    }

    // MARK: - Applying a wrist workout

    /// Store a finished Apple Watch workout: render its GPS route into a map image
    /// and persist a `WorkoutRecord` for the calendar and Progress tab. Idempotent
    /// on the workout id so a re-delivered transfer never duplicates.
    func applyWorkout(_ result: WatchWorkoutResult) async {
        guard let context else { return }
        let id = result.id
        let existing = try? context.fetch(FetchDescriptor<WorkoutRecord>(
            predicate: #Predicate { $0.id == id }
        ))
        guard (existing?.isEmpty ?? true) else { return }

        let routeData = try? JSONEncoder().encode(result.route)
        var imageName: String? = nil
        if result.mode.isOutdoor, result.route.count > 1 {
            imageName = await WorkoutRouteRenderer.renderAndSave(
                points: result.route, accentHex: result.mode.accentHex, id: id
            )
        }

        let record = WorkoutRecord(
            id: id,
            modeRaw: result.modeRaw,
            startedAt: result.startedAt,
            durationSec: result.durationSec,
            distanceMeters: result.distanceMeters,
            activeCalories: result.activeCalories,
            avgHeartRate: result.avgHeartRate,
            maxHeartRate: result.maxHeartRate,
            routeData: routeData,
            routeImageName: imageName
        )
        context.insert(record)

        // Fold the workout's XP into the player's running total. Safe to do here
        // because this path is guarded against duplicate ids above.
        if let player = try? context.fetch(FetchDescriptor<PlayerState>()).first {
            player.xp += record.xpEarned
            // Push the XP change AND the workout summary to the cloud — without
            // these, Watch-earned XP and workouts never left the device.
            SyncEngine.shared.enqueuePlayerState(player)
        }
        SyncEngine.shared.enqueueWorkoutRecord(record)

        try? context.save()
        refreshAndPush()
    }
}

extension WatchSyncBridge: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in self.refreshAndPush() }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) { session.activate() }

    /// The watch asking for a fresh snapshot (e.g. on its own launch).
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        Task { @MainActor in
            self.refreshAndPush()
            let payload = WatchShared.load()
            if let encoded = try? JSONEncoder().encode(payload) {
                replyHandler(["glance": encoded])
            } else {
                replyHandler([:])
            }
        }
    }

    /// A quick-log OR a finished workout completed on the watch, delivered in the
    /// background.
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        if let data = userInfo["quickLog"] as? Data,
           let request = try? JSONDecoder().decode(WatchQuickLogRequest.self, from: data) {
            Task { @MainActor in self.applyQuickLog(request) }
        }
        if let data = userInfo["workout"] as? Data,
           let result = try? JSONDecoder().decode(WatchWorkoutResult.self, from: data) {
            Task { @MainActor in await self.applyWorkout(result) }
        }
    }
}
