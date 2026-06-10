//
//  FavoritesStore.swift
//  MFElite
//
//  UserDefaults-backed store for the player's favorited drills, routines, and
//  custom workouts. Fully local, on-device. Observed so any favorite toggle
//  instantly updates every screen — the drill detail heart, the routine/workout
//  cards, and the Favorites collection.
//

import SwiftUI
import Observation

@Observable
@MainActor
final class FavoritesStore {
    static let shared = FavoritesStore()

    private enum Keys {
        static let drills = "MF_FAV_DRILLS"
        static let routines = "MF_FAV_ROUTINES"
        static let workouts = "MF_FAV_WORKOUTS"
    }

    private let defaults = UserDefaults.standard

    private(set) var drillIDs: Set<String>
    private(set) var routineIDs: Set<String>
    private(set) var workoutIDs: Set<String>

    private init() {
        drillIDs = Set(defaults.stringArray(forKey: Keys.drills) ?? [])
        routineIDs = Set(defaults.stringArray(forKey: Keys.routines) ?? [])
        workoutIDs = Set(defaults.stringArray(forKey: Keys.workouts) ?? [])
    }

    // MARK: - Drills

    func isFavoriteDrill(_ id: String) -> Bool { drillIDs.contains(id) }

    func toggleDrill(_ id: String) {
        if drillIDs.contains(id) { drillIDs.remove(id) } else { drillIDs.insert(id) }
        defaults.set(Array(drillIDs), forKey: Keys.drills)
    }

    // MARK: - Routines

    func isFavoriteRoutine(_ id: String) -> Bool { routineIDs.contains(id) }

    func toggleRoutine(_ id: String) {
        if routineIDs.contains(id) { routineIDs.remove(id) } else { routineIDs.insert(id) }
        defaults.set(Array(routineIDs), forKey: Keys.routines)
    }

    // MARK: - Workouts

    func isFavoriteWorkout(_ id: UUID) -> Bool { workoutIDs.contains(id.uuidString) }

    func toggleWorkout(_ id: UUID) {
        let key = id.uuidString
        if workoutIDs.contains(key) { workoutIDs.remove(key) } else { workoutIDs.insert(key) }
        defaults.set(Array(workoutIDs), forKey: Keys.workouts)
    }

    /// Drop a workout's favorite flag when it's deleted, so it doesn't linger.
    func removeWorkout(_ id: UUID) {
        guard workoutIDs.contains(id.uuidString) else { return }
        workoutIDs.remove(id.uuidString)
        defaults.set(Array(workoutIDs), forKey: Keys.workouts)
    }

    // MARK: - Aggregate

    var totalCount: Int { drillIDs.count + routineIDs.count + workoutIDs.count }
    var isEmpty: Bool { totalCount == 0 }
}
