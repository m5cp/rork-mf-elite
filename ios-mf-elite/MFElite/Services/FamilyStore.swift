//
//  FamilyStore.swift
//  MFElite
//
//  Local, offline-first source of truth for the household roster. One account
//  (the parent/primary login) can manage several athletes, but each athlete
//  trains an INDIVIDUALIZED program — only the athlete marked `active` is the
//  one whose tailored sessions, drills, and progress are shown on this device.
//  Switching the active athlete mirrors their identity into PlayerProfileStore
//  so the rest of the app reflects the right person.
//
//  Supabase `player_profiles` (sharing one `account_id`) is the remote mirror;
//  FamilyService syncs this store up best-effort. The app works fully offline.
//

import SwiftUI
import Observation

/// A single athlete in the household. Identity only — progress/XP live per
/// athlete in their own player records, keyed by `id`.
nonisolated struct Athlete: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var username: String
    var displayName: String
    var kitNumber: String
    var position: String
    /// True when this athlete has no own login and is managed by the parent.
    var managed: Bool

    var initials: String { ProfileValidation.initials(from: displayName) }
}

@Observable
@MainActor
final class FamilyStore {
    static let shared = FamilyStore()

    private enum Keys {
        static let athletes = "MF_FAMILY_ATHLETES"
        static let active = "MF_FAMILY_ACTIVE_ID"
        static let household = "MF_FAMILY_NAME"
    }

    private let defaults = UserDefaults.standard

    /// Every athlete the account manages, in display order.
    private(set) var athletes: [Athlete] = []
    /// The athlete whose individualized program is currently shown.
    private(set) var activeAthleteID: String?
    /// Optional household label ("The Okafor Family").
    var householdName: String {
        didSet { defaults.set(householdName, forKey: Keys.household) }
    }

    private init() {
        householdName = defaults.string(forKey: Keys.household) ?? ""
        athletes = Self.loadAthletes(defaults)
        activeAthleteID = defaults.string(forKey: Keys.active)
        seedPrimaryIfNeeded()
        normalizeActive()
    }

    // MARK: - Derived

    /// The athlete currently driving the app's tailored program.
    var activeAthlete: Athlete? {
        athletes.first { $0.id == activeAthleteID } ?? athletes.first
    }

    var hasMultipleAthletes: Bool { athletes.count > 1 }

    func isActive(_ athlete: Athlete) -> Bool {
        activeAthlete?.id == athlete.id
    }

    // MARK: - Mutations

    /// Add a parent-managed athlete and return its new local id.
    @discardableResult
    func addAthlete(username: String, name: String, kit: String, position: String) -> Athlete {
        let athlete = Athlete(
            id: UUID().uuidString,
            username: ProfileValidation.normalizedUsername(username),
            displayName: ProfileValidation.normalizedName(name),
            kitNumber: ProfileValidation.normalizedKitNumber(kit),
            position: ProfileValidation.isPositionValid(position) ? position : "No preference",
            managed: true
        )
        athletes.append(athlete)
        persist()
        // First athlete added becomes active automatically.
        if athletes.count == 1 { setActive(athlete.id) }
        return athlete
    }

    func updateAthlete(id: String, name: String, kit: String, position: String) {
        guard let index = athletes.firstIndex(where: { $0.id == id }) else { return }
        athletes[index].displayName = ProfileValidation.normalizedName(name)
        athletes[index].kitNumber = ProfileValidation.normalizedKitNumber(kit)
        athletes[index].position = ProfileValidation.isPositionValid(position) ? position : "No preference"
        persist()
        if isActiveID(id) { mirrorToProfileStore(athletes[index]) }
    }

    func removeAthlete(id: String) {
        athletes.removeAll { $0.id == id }
        if activeAthleteID == id { activeAthleteID = athletes.first?.id }
        persist()
        normalizeActive()
    }

    /// Make `id` the active athlete — this is what switches the whole app over
    /// to that athlete's individualized program.
    func setActive(_ id: String) {
        guard athletes.contains(where: { $0.id == id }) else { return }
        activeAthleteID = id
        defaults.set(id, forKey: Keys.active)
        if let athlete = athletes.first(where: { $0.id == id }) {
            mirrorToProfileStore(athlete)
        }
    }

    func reset() {
        athletes = []
        activeAthleteID = nil
        householdName = ""
        defaults.removeObject(forKey: Keys.athletes)
        defaults.removeObject(forKey: Keys.active)
        seedPrimaryIfNeeded()
        normalizeActive()
    }

    // MARK: - Internals

    private func isActiveID(_ id: String) -> Bool { (activeAthleteID ?? athletes.first?.id) == id }

    /// Ensure the existing single-player profile shows up as the first athlete so
    /// upgrading to family management never loses the current player.
    private func seedPrimaryIfNeeded() {
        guard athletes.isEmpty else { return }
        let profile = PlayerProfileStore.shared
        let primary = Athlete(
            id: AuthService.shared.user?.id ?? UUID().uuidString,
            username: "",
            displayName: profile.displayName,
            kitNumber: profile.kitNumber,
            position: profile.position.isEmpty ? "No preference" : profile.position,
            managed: false
        )
        athletes = [primary]
        activeAthleteID = primary.id
        persist()
        defaults.set(primary.id, forKey: Keys.active)
    }

    private func normalizeActive() {
        if activeAthleteID == nil || !athletes.contains(where: { $0.id == activeAthleteID }) {
            activeAthleteID = athletes.first?.id
            if let id = activeAthleteID { defaults.set(id, forKey: Keys.active) }
        }
    }

    /// Reflect the active athlete into the display-facing profile store so Today,
    /// the player card, and reports all show the active athlete.
    private func mirrorToProfileStore(_ athlete: Athlete) {
        let profile = PlayerProfileStore.shared
        profile.displayName = athlete.displayName.isEmpty ? "Player" : athlete.displayName
        profile.kitNumber = athlete.kitNumber
        profile.position = athlete.position
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(athletes) {
            defaults.set(data, forKey: Keys.athletes)
        }
    }

    private static func loadAthletes(_ defaults: UserDefaults) -> [Athlete] {
        guard let data = defaults.data(forKey: Keys.athletes),
              let decoded = try? JSONDecoder().decode([Athlete].self, from: data) else {
            return []
        }
        return decoded
    }
}
