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

    private(set) var phase: Phase = .idle
    private(set) var distanceMeters: Double = 0
    private(set) var elapsed: TimeInterval = 0
    private(set) var route: [CLLocationCoordinate2D] = []
    private(set) var authDenied = false

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
        startedAt = nil
    }

    // MARK: - Derived

    /// Current pace in seconds per kilometre (0 when not enough distance yet).
    var paceSecondsPerKm: Double {
        guard distanceMeters > 20, elapsed > 0 else { return 0 }
        return elapsed / (distanceMeters / 1000)
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
