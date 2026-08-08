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

    /// Forget every favorite. Account deletion only.
    func reset() {
        drillIDs = []
        routineIDs = []
        workoutIDs = []
        defaults.removeObject(forKey: Keys.drills)
        defaults.removeObject(forKey: Keys.routines)
        defaults.removeObject(forKey: Keys.workouts)
    }

    // MARK: - Drills

    func isFavoriteDrill(_ id: String) -> Bool { drillIDs.contains(id) }

    func toggleDrill(_ id: String) {
        if drillIDs.contains(id) {
            drillIDs.remove(id)
            SyncEngine.shared.enqueueFavoriteDeletion(kind: "drill", itemID: id)
        } else {
            drillIDs.insert(id)
            SyncEngine.shared.enqueueFavorite(kind: "drill", itemID: id)
        }
        defaults.set(Array(drillIDs), forKey: Keys.drills)
    }

    // MARK: - Routines

    func isFavoriteRoutine(_ id: String) -> Bool { routineIDs.contains(id) }

    func toggleRoutine(_ id: String) {
        if routineIDs.contains(id) {
            routineIDs.remove(id)
            SyncEngine.shared.enqueueFavoriteDeletion(kind: "routine", itemID: id)
        } else {
            routineIDs.insert(id)
            SyncEngine.shared.enqueueFavorite(kind: "routine", itemID: id)
        }
        defaults.set(Array(routineIDs), forKey: Keys.routines)
    }

    // MARK: - Workouts

    func isFavoriteWorkout(_ id: UUID) -> Bool { workoutIDs.contains(id.uuidString) }

    func toggleWorkout(_ id: UUID) {
        let key = id.uuidString
        if workoutIDs.contains(key) {
            workoutIDs.remove(key)
            SyncEngine.shared.enqueueFavoriteDeletion(kind: "workout", itemID: key)
        } else {
            workoutIDs.insert(key)
            SyncEngine.shared.enqueueFavorite(kind: "workout", itemID: key)
        }
        defaults.set(Array(workoutIDs), forKey: Keys.workouts)
    }

    /// Drop a workout's favorite flag when it's deleted, so it doesn't linger.
    func removeWorkout(_ id: UUID) {
        guard workoutIDs.contains(id.uuidString) else { return }
        workoutIDs.remove(id.uuidString)
        defaults.set(Array(workoutIDs), forKey: Keys.workouts)
        SyncEngine.shared.enqueueFavoriteDeletion(kind: "workout", itemID: id.uuidString)
    }

    /// Apply a favorite pulled from the cloud during restore (no re-enqueue).
    func applyRemote(kind: String, itemID: String) {
        switch kind {
        case "drill":
            guard !drillIDs.contains(itemID) else { return }
            drillIDs.insert(itemID)
            defaults.set(Array(drillIDs), forKey: Keys.drills)
        case "routine":
            guard !routineIDs.contains(itemID) else { return }
            routineIDs.insert(itemID)
            defaults.set(Array(routineIDs), forKey: Keys.routines)
        case "workout":
            guard !workoutIDs.contains(itemID) else { return }
            workoutIDs.insert(itemID)
            defaults.set(Array(workoutIDs), forKey: Keys.workouts)
        default:
            break
        }
    }

    // MARK: - Aggregate

    var totalCount: Int { drillIDs.count + routineIDs.count + workoutIDs.count }
    var isEmpty: Bool { totalCount == 0 }
}
