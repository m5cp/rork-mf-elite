//
//  RunTracker.swift
//  MFElite
//
//  A lightweight foreground GPS tracker for athlete runs / on-field sessions.
//  Uses Core Location only while the screen is active (when-in-use), measures
//  distance, duration and pace, and records the route for a map. Fails soft when
//  permission is denied.
//

import Foundation
import CoreLocation
import Observation

@MainActor
@Observable
final class RunTracker: NSObject, CLLocationManagerDelegate {
    enum Phase: Equatable {
        case idle
        case running
        case paused
        case finished
    }

    private let manager = CLLocationManager()
    private var ticker: Task<Void, Never>?
    private var startedAt: Date?
    private var accumulated: TimeInterval = 0
    private var lastLocation: CLLocation?
    /// BPM readings taken while actually running, for the finished run's
    /// average and peak. Empty when no strap was ever connected.
    private var heartSamples: [Int] = []

    private(set) var phase: Phase = .idle
    private(set) var distanceMeters: Double = 0
    private(set) var elapsed: TimeInterval = 0
    private(set) var route: [CLLocationCoordinate2D] = []
    private(set) var authDenied = false

    /// Identity of the run in flight, minted once at `start()`. The screen can be
    /// left several ways (Finish, close, a back swipe) and each of them tries to
    /// save; a stable id is what lets the store recognise those as one run.
    private(set) var runID = UUID().uuidString
    /// Wall-clock start of the whole run, as opposed to `startedAt` which is the
    /// start of the current un-paused segment.
    private(set) var runStartedAt: Date?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = 3
        manager.activityType = .fitness
    }

    // MARK: - Controls

    func start() {
        let status = manager.authorizationStatus
        if status == .denied || status == .restricted {
            authDenied = true
            return
        }
        if status == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        authDenied = false
        distanceMeters = 0
        elapsed = 0
        accumulated = 0
        route = []
        lastLocation = nil
        heartSamples = []
        runID = UUID().uuidString
        runStartedAt = Date()
        startedAt = Date()
        phase = .running
        manager.startUpdatingLocation()
        startTicker()
    }

    func pause() {
        guard phase == .running else { return }
        accumulated += Date().timeIntervalSince(startedAt ?? Date())
        startedAt = nil
        phase = .paused
        manager.stopUpdatingLocation()
        ticker?.cancel()
        lastLocation = nil
    }

    func resume() {
        guard phase == .paused else { return }
        startedAt = Date()
        phase = .running
        manager.startUpdatingLocation()
        startTicker()
    }

    func stop() {
        if phase == .running { accumulated += Date().timeIntervalSince(startedAt ?? Date()) }
        elapsed = accumulated
        startedAt = nil
        phase = .finished
        manager.stopUpdatingLocation()
        ticker?.cancel()
    }

    func reset() {
        ticker?.cancel()
        phase = .idle
        distanceMeters = 0
        elapsed = 0
        accumulated = 0
        route = []
        lastLocation = nil
        heartSamples = []
        startedAt = nil
        runStartedAt = nil
    }

    // MARK: - Heart rate

    /// Feed the run a live reading from the optional chest strap. Only sampled
    /// while running, so a long pause at a water fountain can't drag the
    /// average down with resting beats.
    func recordHeartRate(_ bpm: Int) {
        guard phase == .running, bpm > 0 else { return }
        heartSamples.append(bpm)
    }

    // MARK: - Derived

    /// Current pace in seconds per kilometre (0 when not enough distance yet).
    var paceSecondsPerKm: Double {
        guard distanceMeters > 20, elapsed > 0 else { return 0 }
        return elapsed / (distanceMeters / 1000)
    }

    var averageHeartRate: Int {
        guard !heartSamples.isEmpty else { return 0 }
        return Int((Double(heartSamples.reduce(0, +)) / Double(heartSamples.count)).rounded())
    }

    var peakHeartRate: Int { heartSamples.max() ?? 0 }

    /// The finished run expressed in the same shape a watch workout arrives in,
    /// so both devices persist through the one `WorkoutStore` path. Nil while a
    /// run is still in flight, and nil for anything too small to be a run.
    ///
    /// The floors matter more than they look: `WorkoutRecord.xpEarned` is
    /// `max(1, minutes / 10) * xpPerDrill`, so it pays a full drill's XP at the
    /// bottom end. Without these, start → walk a few metres → close is 25 XP
    /// and a junk calendar entry, repeatable forever.
    private static let minimumDuration: TimeInterval = 60
    private static let minimumDistance: Double = 100

    func finishedResult() -> WatchWorkoutResult? {
        guard phase == .finished, let runStartedAt,
              elapsed >= Self.minimumDuration,
              distanceMeters >= Self.minimumDistance else { return nil }
        return WatchWorkoutResult(
            id: runID,
            modeRaw: WorkoutModeID.outdoorRun.rawValue,
            startedAt: runStartedAt,
            durationSec: Int(elapsed.rounded()),
            distanceMeters: distanceMeters,
            // The phone has no HealthKit workout session behind it, so there is
            // no measured burn here. Zero is honest; an estimate would render
            // next to the watch's real numbers as if it were one of them.
            activeCalories: 0,
            avgHeartRate: averageHeartRate,
            maxHeartRate: peakHeartRate,
            route: route.map { WatchRoutePoint(lat: $0.latitude, lng: $0.longitude) }
        )
    }

    private func startTicker() {
        ticker?.cancel()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                await MainActor.run {
                    guard let self, self.phase == .running, let started = self.startedAt else { return }
                    self.elapsed = self.accumulated + Date().timeIntervalSince(started)
                }
            }
        }
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let fresh = locations.filter { $0.horizontalAccuracy >= 0 && $0.horizontalAccuracy < 30 }
        guard !fresh.isEmpty else { return }
        Task { @MainActor in
            for location in fresh {
                if let last = self.lastLocation {
                    let step = location.distance(from: last)
                    if step > 1 { self.distanceMeters += step }
                }
                self.lastLocation = location
                self.route.append(location.coordinate)
            }
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authDenied = (status == .denied || status == .restricted)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}
