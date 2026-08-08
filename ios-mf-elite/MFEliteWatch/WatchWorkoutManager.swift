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
    private var didFinalize = false

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
        // One live session per manager. Without this a second tap while a workout is
        // already up would build a second HKWorkoutSession and a second route
        // builder, and the first pair would become unreachable — nothing left to
        // hold them would ever be able to stop them.
        guard status == .idle else { return }

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
                // Accuracy is re-armed here, not just in `init`, because teardown
                // deliberately drops it. A second workout in the same launch has to
                // put the receiver back into navigation mode itself.
                locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
                locationManager.startUpdatingLocation()
            }

            let start = Date()
            startedAt = start
            session.startActivity(with: start)
            builder.beginCollection(withStart: start) { _, _ in }
            status = .running
            startTicker()
        } catch {
            // The throw comes from the session initialiser, so nothing is running
            // yet — but routing the failure through the same teardown as every
            // other end path is what keeps "did we clean up?" a question with one
            // answer instead of one per call site.
            stopTracking()
            self.session = nil
            self.builder = nil
            self.routeBuilder = nil
            status = .idle
        }
    }

    func pause() { session?.pause() }
    func resume() { session?.resume() }

    func end() {
        // Stop the hardware before asking HealthKit to end. `session.end()` is
        // asynchronous and the `.ended` callback can be a second or more away; there
        // is no reason to burn navigation-grade GPS through it.
        stopTracking()
        session?.end()
    }

    /// Teardown for the workout UI going away — dismissing the cover, swiping back
    /// out of a live workout, or tapping Done on the summary. The manager is owned
    /// by that view and dies with it, so anything still live here loses its last
    /// reference and could never be stopped again.
    func endIfActive() {
        guard status == .running || status == .paused else {
            // Already finished or never started: the session needs nothing, but make
            // one last pass over the battery-expensive parts anyway. This is the
            // cheap belt to `stopTracking`'s braces.
            stopTracking()
            return
        }
        end()
    }

    func reset() {
        stopTracking()
        session = nil
        builder = nil
        routeBuilder = nil
        didFinalize = false
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
        // Cancel-then-replace, never append. `ticker` is the one and only handle to
        // the loop, so a second one created without going through here would be
        // invisible and unstoppable.
        stopTicker()
        ticker = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                // Leaving the loop when the owner is gone is not belt-and-braces, it
                // is the exit condition that was missing. The task holds `self`
                // weakly and the concurrency runtime keeps it alive on its own, so
                // once the manager deallocates the handle that could cancel it dies
                // with it — a loop that only tested `Task.isCancelled` would wake the
                // watch every second for the rest of the process's life.
                guard let self else { return }
                guard self.status == .running else { continue }
                self.elapsed = self.builder?.elapsedTime ?? self.elapsed
            }
        }
    }

    /// The single teardown point for everything a workout leaves powered on: the GPS
    /// fix and the 1 Hz ticker. Every way a workout can end funnels through here —
    /// the End button, HealthKit ending or stopping the session on its own, a session
    /// error, a failed start, and the UI being dismissed — because a cleanup that was
    /// spelled out at each call site was a cleanup that half the call sites forgot.
    /// Idempotent and safe to call when nothing ever started.
    ///
    /// Backgrounding is deliberately *not* one of those paths. The watch target runs
    /// under `workout-processing`, so a live workout is meant to keep collecting when
    /// the athlete drops their wrist or switches apps; stopping GPS there would punch
    /// holes in the route. Process termination needs no path of its own — the ticker
    /// and the location fix die with the process.
    private func stopTracking() {
        stopTicker()
        locationManager.stopUpdatingLocation()
        // Stopping updates is not the same as powering the receiver down. Drop back
        // to the cheapest accuracy so that if anything re-arms location later —
        // an authorization callback, a future caller — it starts coarse instead of
        // silently resuming a navigation-grade fix. `start` puts it back.
        locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        // The watch target ships `workout-processing`, not the location background
        // mode, so this should never have been on; assert that rather than trust it.
        locationManager.allowsBackgroundLocationUpdates = false
    }

    /// Kills the 1 Hz loop and forgets it. Separate from `stopTracking` only because
    /// `startTicker` needs the "there can be at most one" half without tearing down
    /// the GPS fix the workout is still using.
    private func stopTicker() {
        ticker?.cancel()
        // Clearing the handle matters as much as cancelling it: a stale reference is
        // how you end up cancelling last workout's task and leaking this one's.
        ticker = nil
    }

    private func finalizeWorkout() {
        // HealthKit can hand us more than one terminal signal for the same workout
        // (a `.stopped` followed by an `.ended`, an error alongside an end). Ending
        // collection twice fails the second call and would overwrite a good result
        // with an empty one.
        guard !didFinalize, let builder else { return }
        didFinalize = true
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

    /// Called the moment a result exists, with the result.
    ///
    /// Sending it used to be the Done button's job, which meant a workout ended
    /// any other way — the cover swiped away, the system dismissing it, the
    /// watch-side end gesture — was written to Health and then silently lost to
    /// MF Elite, because the manager is `@State` on a view that is already
    /// gone. The phone de-dupes on the result's id, so Done sending it again is
    /// harmless.
    var onResult: ((WatchWorkoutResult) -> Void)?

    private func buildResult() {
        let built = WatchWorkoutResult(
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
        result = built
        status = .ended
        onResult?(built)
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
            case .running:
                self.status = .running
                // HealthKit can put a session back into `running` without anyone
                // touching `resume()` — Siri, the system workout controls, a
                // mirrored phone session. Re-arm the ticker from the state change
                // rather than from the button so every route to "running" ends up
                // with exactly one loop.
                self.startTicker()
            case .paused:
                self.status = .paused
                // A paused workout has nothing to count. Leaving the loop alive just
                // to have it fall through a status check wakes the watch once a
                // second for as long as the athlete stays paused, which can be the
                // rest of the afternoon if they forget about it. `.running` above
                // brings it back.
                self.stopTicker()
            case .stopped:
                // watchOS can stop a session without ending it (`stopActivity`, a
                // mirrored session handing over). No more samples are coming, and an
                // `.ended` may never follow — and when it doesn't, leaving
                // `status` at .running stranded the athlete on the live screen
                // with a frozen timer and no result to send. Finalize here too;
                // `didFinalize` makes the later `.ended` a no-op.
                self.stopTracking()
                self.finalizeWorkout()
            case .ended:
                // Every end that isn't the in-app button lands here: the system
                // workout-end gesture, Siri, HealthKit ending the session itself,
                // another workout app taking over. This case used to go straight to
                // finalize, which is how a finished workout left GPS at navigation
                // accuracy and the ticker running.
                self.stopTracking()
                self.finalizeWorkout()
            default:
                break
            }
        }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        Task { @MainActor in
            // A failed session never transitions to `.ended`, so this is the only
            // place the GPS fix and the ticker can be released on this path.
            self.stopTracking()
            guard self.status == .running || self.status == .paused else { return }
            // Salvage whatever was collected and move to the summary. The builder may
            // never call back after a failure, and stranding the athlete on a live
            // screen whose timer has stopped is worse than a partial summary.
            self.finalizeWorkout()
            self.buildResult()
        }
    }
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
