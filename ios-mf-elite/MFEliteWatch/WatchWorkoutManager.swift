//
//  WatchWorkoutManager.swift
//  MFEliteWatch
//
//  Apple Fitness-style workout engine for the wrist. Drives an HKWorkoutSession
//  with a live workout builder for metrics (time, distance, pace, heart rate,
//  calories), records a GPS route for outdoor modes, writes the workout to Apple
//  Health, and produces a WatchWorkoutResult to sync back to the phone.
//

import Foundation
import HealthKit
import CoreLocation
import Observation

@MainActor
@Observable
final class WatchWorkoutManager: NSObject {
    enum Status: Equatable { case idle, running, paused, ended }

    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var routeBuilder: HKWorkoutRouteBuilder?
    private let locationManager = CLLocationManager()
    private var ticker: Task<Void, Never>?

    private var hrSum = 0
    private var hrCount = 0

    private(set) var status: Status = .idle
    private(set) var mode: WorkoutModeID = .outdoorRun
    private(set) var elapsed: TimeInterval = 0
    private(set) var distanceMeters: Double = 0
    private(set) var activeCalories: Double = 0
    private(set) var heartRate: Int = 0
    private(set) var maxHeartRate: Int = 0
    private(set) var route: [CLLocationCoordinate2D] = []
    private(set) var result: WatchWorkoutResult?
    private var startedAt = Date()

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter = 4
    }

    var avgHeartRate: Int { hrCount > 0 ? hrSum / hrCount : 0 }

    /// Current pace in seconds per km (0 until enough distance).
    var paceSecondsPerKm: Double {
        guard distanceMeters > 20, elapsed > 0 else { return 0 }
        return elapsed / (distanceMeters / 1000)
    }

    // MARK: - Authorization

    func requestAuthorization() async {
        let share: Set<HKSampleType> = [
            HKQuantityType.workoutType(),
            HKSeriesType.workoutRoute(),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.distanceCycling),
            HKQuantityType(.heartRate)
        ]
        let read: Set<HKObjectType> = [
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.distanceCycling),
            HKQuantityType(.heartRate)
        ]
        try? await healthStore.requestAuthorization(toShare: share, read: read)
    }

    // MARK: - Controls

    func start(_ mode: WorkoutModeID) async {
        self.mode = mode
        await requestAuthorization()

        let config = HKWorkoutConfiguration()
        config.activityType = Self.activityType(for: mode)
        config.locationType = mode.isOutdoor ? .outdoor : .indoor

        do {
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: config)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: config)
            session.delegate = self
            builder.delegate = self
            self.session = session
            self.builder = builder

            if mode.isOutdoor {
                routeBuilder = HKWorkoutRouteBuilder(healthStore: healthStore, device: nil)
                if locationManager.authorizationStatus == .notDetermined {
                    locationManager.requestWhenInUseAuthorization()
                }
                locationManager.startUpdatingLocation()
            }

            let start = Date()
            startedAt = start
            session.startActivity(with: start)
            builder.beginCollection(withStart: start) { _, _ in }
            status = .running
            startTicker()
        } catch {
            status = .idle
        }
    }

    func pause() { session?.pause() }
    func resume() { session?.resume() }

    func end() {
        locationManager.stopUpdatingLocation()
        ticker?.cancel()
        session?.end()
    }

    func reset() {
        ticker?.cancel()
        session = nil
        builder = nil
        routeBuilder = nil
        status = .idle
        elapsed = 0
        distanceMeters = 0
        activeCalories = 0
        heartRate = 0
        maxHeartRate = 0
        hrSum = 0
        hrCount = 0
        route = []
        result = nil
    }

    private func startTicker() {
        ticker?.cancel()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                await MainActor.run {
                    guard let self, self.status == .running else { return }
                    self.elapsed = self.builder?.elapsedTime ?? self.elapsed
                }
            }
        }
    }

    private func finalizeWorkout() {
        guard let builder else { return }
        let end = Date()
        builder.endCollection(withEnd: end) { [weak self] _, _ in
            builder.finishWorkout { [weak self] workout, _ in
                Task { @MainActor in
                    guard let self else { return }
                    if let workout, let routeBuilder = self.routeBuilder, !self.route.isEmpty {
                        routeBuilder.finishRoute(with: workout, metadata: nil) { _, _ in }
                    }
                    self.buildResult()
                }
            }
        }
    }

    private func buildResult() {
        result = WatchWorkoutResult(
            id: UUID().uuidString,
            modeRaw: mode.rawValue,
            startedAt: startedAt,
            durationSec: Int(elapsed),
            distanceMeters: distanceMeters,
            activeCalories: activeCalories,
            avgHeartRate: avgHeartRate,
            maxHeartRate: maxHeartRate,
            route: route.map { WatchRoutePoint(lat: $0.latitude, lng: $0.longitude) }
        )
        status = .ended
    }

    private static func activityType(for mode: WorkoutModeID) -> HKWorkoutActivityType {
        switch mode {
        case .outdoorRun, .treadmill: return .running
        case .walk: return .walking
        case .cycle: return .cycling
        case .outdoorWorkout: return .mixedCardio
        case .elliptical: return .elliptical
        case .interval: return .highIntensityIntervalTraining
        case .strength: return .traditionalStrengthTraining
        case .functional: return .functionalStrengthTraining
        case .soccerSkills: return .soccer
        }
    }
}

// MARK: - HKWorkoutSessionDelegate

extension WatchWorkoutManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        Task { @MainActor in
            switch toState {
            case .running: self.status = .running
            case .paused: self.status = .paused
            case .ended: self.finalizeWorkout()
            default: break
            }
        }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {}
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension WatchWorkoutManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType,
                  let statistics = workoutBuilder.statistics(for: quantityType) else { continue }

            if quantityType == HKQuantityType(.heartRate) {
                let unit = HKUnit.count().unitDivided(by: .minute())
                let bpm = Int(statistics.mostRecentQuantity()?.doubleValue(for: unit) ?? 0)
                Task { @MainActor in
                    if bpm > 0 {
                        self.heartRate = bpm
                        self.hrSum += bpm
                        self.hrCount += 1
                        self.maxHeartRate = max(self.maxHeartRate, bpm)
                    }
                }
            } else if quantityType == HKQuantityType(.activeEnergyBurned) {
                let kcal = statistics.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                Task { @MainActor in self.activeCalories = kcal }
            } else if quantityType == HKQuantityType(.distanceWalkingRunning) || quantityType == HKQuantityType(.distanceCycling) {
                let meters = statistics.sumQuantity()?.doubleValue(for: .meter()) ?? 0
                Task { @MainActor in self.distanceMeters = max(self.distanceMeters, meters) }
            }
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension WatchWorkoutManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let fresh = locations.filter { $0.horizontalAccuracy >= 0 && $0.horizontalAccuracy < 50 }
        guard !fresh.isEmpty else { return }
        let coords = fresh.map(\.coordinate)
        Task { @MainActor in
            self.route.append(contentsOf: coords)
            self.routeBuilder?.insertRouteData(fresh) { _, _ in }
        }
    }
}
