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
//  Also provides read-only access to the player's daily step count (from
//  iPhone and/or a paired Apple Watch — HealthKit merges both sources) for
//  the "Today's Steps" card on the Progress tab. Steps are never written.
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

    /// Persisted daily step goal shown against the Progress tab steps card.
    static let stepGoalKey = "MF_STEP_GOAL"
    static let defaultStepGoal = 8000

    /// Whether the player has ever been asked for step-read access, so we only
    /// prompt once (declining doesn't re-prompt every time the card appears).
    static let stepsAccessRequestedKey = "MF_STEPS_ACCESS_REQUESTED"

    private let store = HKHealthStore()

    /// Whether the device supports HealthKit at all (false on, e.g., iPad without Health).
    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// Mirror of the persisted opt-in flag.
    private(set) var isSyncEnabled: Bool

    /// Whether step-read access has already been requested once.
    private(set) var hasRequestedStepsAccess: Bool

    /// The player's daily step goal, editable from the Progress tab.
    var stepGoal: Int {
        get {
            let saved = UserDefaults.standard.integer(forKey: Self.stepGoalKey)
            return saved > 0 ? saved : Self.defaultStepGoal
        }
        set { UserDefaults.standard.set(max(1000, newValue), forKey: Self.stepGoalKey) }
    }

    private init() {
        isSyncEnabled = UserDefaults.standard.bool(forKey: Self.syncEnabledKey)
        hasRequestedStepsAccess = UserDefaults.standard.bool(forKey: Self.stepsAccessRequestedKey)
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

    // MARK: - Steps (read-only)

    /// Ask for read access to step count. Covers steps logged by the iPhone or
    /// a paired Apple Watch — HealthKit merges both sources automatically.
    func requestStepsAccess() async -> Bool {
        guard isAvailable, let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            return false
        }
        hasRequestedStepsAccess = true
        UserDefaults.standard.set(true, forKey: Self.stepsAccessRequestedKey)
        do {
            try await store.requestAuthorization(toShare: [], read: [stepType])
            return true
        } catch {
            return false
        }
    }

    /// Today's cumulative step count from midnight to now, summed across all
    /// sources (iPhone + Apple Watch). Returns 0 if unavailable or denied —
    /// HealthKit read-authorization status can't be inspected directly, so a
    /// zero result silently means either "no steps yet" or "no access".
    func fetchTodaySteps() async -> Int {
        guard isAvailable, let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            return 0
        }
        let start = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, _ in
                let count = statistics?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                continuation.resume(returning: Int(count.rounded()))
            }
            store.execute(query)
        }
    }

    /// This week's total steps (Monday-start, to now). 0 when unavailable/denied.
    func fetchWeekSteps() async -> Int {
        guard isAvailable, let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) else { return 0 }
        let predicate = HKQuery.predicateForSamples(withStart: Self.startOfWeek(), end: Date(), options: .strictStartDate)
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, _ in
                let count = statistics?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                continuation.resume(returning: Int(count.rounded()))
            }
            store.execute(query)
        }
    }

    /// This week's walking+running distance in miles (Monday-start, to now).
    /// Returns 0 when unavailable/denied. Requires distance read access.
    func fetchWeekMiles() async -> Double {
        guard isAvailable,
              let distanceType = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning) else { return 0 }
        // Request read access alongside steps; safe to call repeatedly.
        try? await store.requestAuthorization(toShare: [], read: [distanceType])
        let predicate = HKQuery.predicateForSamples(withStart: Self.startOfWeek(), end: Date(), options: .strictStartDate)
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: distanceType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, _ in
                let meters = statistics?.sumQuantity()?.doubleValue(for: .meter()) ?? 0
                continuation.resume(returning: meters / 1609.344)
            }
            store.execute(query)
        }
    }

    /// Monday 00:00 of the current week (matches WeekRecap's week definition).
    private static func startOfWeek() -> Date {
        var cal = Calendar.current
        cal.firstWeekday = 2
        let today = cal.startOfDay(for: Date())
        let weekday = cal.component(.weekday, from: today)
        let daysSinceMonday = (weekday - cal.firstWeekday + 7) % 7
        return cal.date(byAdding: .day, value: -daysSinceMonday, to: today) ?? today
    }
}
