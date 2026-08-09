//
//  WatchConnectivityReceiver.swift
//  MFEliteWatch
//
//  Watch-side half of the phone/watch bridge. Receives the latest "today"
//  snapshot from the phone (delivered even if the phone app isn't
//  foregrounded), and sends quick-logged sessions back so XP/streak/history
//  update on the phone through its normal pipeline.
//

import Foundation
import WatchConnectivity
import Observation

@MainActor
@Observable
final class WatchConnectivityReceiver: NSObject {
    static let shared = WatchConnectivityReceiver()

    private(set) var glance: WatchGlanceData = WatchShared.load()
    private(set) var isReachable = false

    private var session: WCSession?

    private override init() {
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        self.session = session
    }

    /// Ask the phone for a fresh snapshot (e.g. when the app opens on the wrist).
    func requestRefresh() {
        guard let session, session.isReachable else { return }
        session.sendMessage([:], replyHandler: { [weak self] reply in
            guard let data = reply["glance"] as? Data,
                  let decoded = try? JSONDecoder().decode(WatchGlanceData.self, from: data) else { return }
            Task { @MainActor in self?.apply(decoded) }
        }, errorHandler: nil)
    }

    /// Send a session completed on the watch back to the phone so it logs
    /// through the same `QuickLog` pipeline as a phone-side quick log.
    func sendQuickLog(drillIDs: [String], sourceName: String) {
        guard !drillIDs.isEmpty else { return }
        let request = WatchQuickLogRequest(drillIDs: drillIDs, sourceName: sourceName)
        guard let encoded = try? JSONEncoder().encode(request) else { return }
        session?.transferUserInfo(["quickLog": encoded])

        // Optimistically reflect the log locally so the wrist UI feels instant
        // even before the phone round-trips a fresh snapshot.
        var updated = glance
        updated.drillCount += drillIDs.count
        updated.trainMinutes += drillIDs.count * 3
        apply(updated)
    }

    /// Send a finished watch workout (stats + GPS route) to the phone, where it's
    /// stored, rendered into a route map, and added to Progress + the calendar.
    /// Cap on route points sent to the phone.
    ///
    /// `transferUserInfo` rejects payloads over roughly 65 KB, and a JSON
    /// route point is about 44 bytes. Since the workout now records an
    /// unfiltered GPS fix roughly every second — deliberately, so a session on
    /// a pitch draws the ground actually covered — a long session would sail
    /// past that and the transfer would fail. There is no completion handler
    /// on `transferUserInfo`, so the failure is silent and takes the WHOLE
    /// workout with it, not just the route.
    private static let maxRoutePoints = 1200

    func sendWorkout(_ result: WatchWorkoutResult) {
        var payload = result
        if payload.route.count > Self.maxRoutePoints {
            // Even stride rather than truncation: the shape of the session is
            // the point, and dropping the tail would lop off the end of it.
            let step = Int(ceil(Double(payload.route.count) / Double(Self.maxRoutePoints)))
            payload.route = payload.route.enumerated()
                .compactMap { $0.offset % step == 0 ? $0.element : nil }
        }
        guard let encoded = try? JSONEncoder().encode(payload) else { return }
        session?.transferUserInfo(["workout": encoded])
    }

    private func apply(_ data: WatchGlanceData) {
        glance = data
        WatchShared.save(data)
    }
}

extension WatchConnectivityReceiver: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            self.isReachable = session.isReachable
            self.requestRefresh()
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isReachable = session.isReachable
            if session.isReachable { self.requestRefresh() }
        }
    }

    /// The phone pushed a new snapshot via `updateApplicationContext`.
    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let data = applicationContext["glance"] as? Data,
              let decoded = try? JSONDecoder().decode(WatchGlanceData.self, from: data) else { return }
        Task { @MainActor in self.apply(decoded) }
    }
}
