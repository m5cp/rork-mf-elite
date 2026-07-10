//
//  SharePhotoPermission.swift
//  MFElite
//
//  Tracks whether a parent has unlocked photo backdrops for the share flow.
//  The unlock is a parent decision (verified through `ParentGate`) and is
//  remembered PER ATHLETE profile so enabling it for one child doesn't silently
//  enable it for a sibling on the same device. Only a small boolean flag per
//  athlete id is stored — no photos live here.
//

import Foundation
import Observation

@Observable
@MainActor
final class SharePhotoPermission {
    static let shared = SharePhotoPermission()

    private static let key = "MF_SHARE_PHOTO_GRANTS"

    private let defaults = UserDefaults.standard

    /// Athlete ids that have been granted photo-backdrop permission.
    private var grantedIDs: Set<String>

    private init() {
        let stored = defaults.array(forKey: Self.key) as? [String] ?? []
        grantedIDs = Set(stored)
    }

    /// The id of the athlete this device is currently acting as. Falls back to a
    /// stable key when no family roster exists so a solo player is still tracked.
    private var currentAthleteID: String {
        FamilyStore.shared.activeAthlete?.id ?? "primary"
    }

    /// Whether photo backdrops are unlocked for the active athlete.
    var isGranted: Bool {
        grantedIDs.contains(currentAthleteID)
    }

    /// Record that a parent unlocked photo backdrops for the active athlete.
    func grant() {
        grantedIDs.insert(currentAthleteID)
        persist()
    }

    /// Revoke the grant for the active athlete (used from Settings / testing).
    func revoke() {
        grantedIDs.remove(currentAthleteID)
        persist()
    }

    private func persist() {
        defaults.set(Array(grantedIDs), forKey: Self.key)
    }
}
