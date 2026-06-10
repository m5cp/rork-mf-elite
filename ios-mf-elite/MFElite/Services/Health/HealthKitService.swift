//
//  HealthKitService.swift
//  MFElite
//
//  Optional Apple Health sync. When the player turns on "Log to Apple Health"
//  in Settings, each completed training session is written as a soccer workout
//  (duration + estimated active energy). Everything is opt-in and gated behind
//  an explicit permission prompt; if HealthKit is unavailable or permission is
//  denied, the app behaves exactly as before.
//

import Foundation
import HealthKit

@MainActor
@Observable
final class HealthKitService {
    static let shared = HealthKitService()

    /// User-facing opt-in toggle, persisted in UserDefaults. Mirrors the
    /// Settings switch so the logging path can check it cheaply.
    static let syncEnabledKey = "MF_HEALTH_SYNC"

    private let store = HKHealthStore()

    /// Whether the device supports HealthKit at all (false on, e.g., iPad without Health).
    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// Mirror of the persisted opt-in flag.
    private(set) var isSyncEnabled: Bool

    private init() {
        isSyncEnabled = UserDefaults.standard.bool(forKey: Self.syncEnabledKey)
    }

    /// The HealthKit types we write: a workout plus its active-energy sample.
    private var typesToShare: Set<HKSampleType> {
        var set: Set<HKSampleType> = [HKObjectType.workoutType()]
        if let energy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
            set.insert(energy)
        }
        return set
    }

    /// Turn the toggle on: ask for permission, and only enable if granted.
    /// Completion returns whether sync is now active.
    func enableSync(completion: @escaping (Bool) -> Void) {
        guard isAvailable else {
            completion(false)
            return
        }
        store.requestAuthorization(toShare: typesToShare, read: []) { [weak self] success, _ in
            Task { @MainActor in
                guard let self else { return }
                // We can't read share-authorization status directly; trust the
                // prompt result. If the user declined, writes silently no-op.
                self.setSyncEnabled(success)
                completion(success)
            }
        }
    }

    /// Turn the toggle off. We can't revoke Health permission from the app, but
    /// we stop writing immediately.
    func disableSync() {
        setSyncEnabled(false)
    }

    private func setSyncEnabled(_ enabled: Bool) {
        isSyncEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.syncEnabledKey)
    }

    /// Write a completed training session as a soccer workout ending now.
    /// `durationSec` is the banked training time; energy is a light estimate
    /// (~7 kcal/min) so the ring reflects effort without overstating it.
    func logTraining(durationSec: Int) {
        guard isSyncEnabled, isAvailable, durationSec > 0 else { return }

        let duration = TimeInterval(durationSec)
        let end = Date()
        let start = end.addingTimeInterval(-duration)
        let minutes = duration / 60.0
        let kcal = max(1.0, minutes * 7.0)

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .soccer

        let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration, device: .local())

        builder.beginCollection(withStart: start) { [weak self] started, _ in
            guard started, let self else { return }

            let energyType = HKQuantityType(.activeEnergyBurned)
            let energyQuantity = HKQuantity(unit: .kilocalorie(), doubleValue: kcal)
            let energySample = HKCumulativeQuantitySample(
                type: energyType,
                quantity: energyQuantity,
                start: start,
                end: end
            )

            builder.add([energySample]) { _, _ in
                builder.endCollection(withEnd: end) { _, _ in
                    builder.finishWorkout { _, _ in }
                }
            }
        }
    }
}
