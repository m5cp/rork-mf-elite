//
//  FamilyService.swift
//  MFElite
//
//  Best-effort remote mirror for the household roster. Athletes managed by a
//  parent share one `account_id` and are linked to a `families` row. Everything
//  here is guarded on `isConfigured` + auth so the family UI works fully offline
//  and only pushes to Supabase when a session exists.
//
//  Privacy: this writes ONLY the shareable `player_profiles` layer (name, kit,
//  position, username). The private `profiles` layer (email, billing) is never
//  touched here.
//

import Foundation
import Observation
import Supabase

@MainActor
@Observable
final class FamilyService {
    static let shared = FamilyService()

    var lastError: String?

    private init() {}

    private var client: SupabaseClient { SupabaseService.shared.client }
    private var isConfigured: Bool { SupabaseService.shared.isConfigured }

    // MARK: - Household

    /// Fetch the account's family row, creating one if it doesn't exist yet.
    @discardableResult
    func ensureFamily(ownerID: String, name: String?) async throws -> FamilyRow? {
        guard isConfigured else { return nil }
        let existing: [FamilyRow] = try await client
            .from("families")
            .select()
            .eq("owner_id", value: ownerID)
            .limit(1)
            .execute()
            .value
        if let row = existing.first { return row }

        let inserted: FamilyRow = try await client
            .from("families")
            .insert(FamilyInsert(ownerId: ownerID, name: name))
            .select()
            .single()
            .execute()
            .value
        return inserted
    }

    // MARK: - Athletes

    /// All athletes the signed-in account manages (real rows, no examples).
    func fetchAthletes(accountID: String) async throws -> [PlayerProfileRow] {
        guard isConfigured else { return [] }
        let rows: [PlayerProfileRow] = try await client
            .from("player_profiles")
            .select()
            .eq("account_id", value: accountID)
            .eq("is_example", value: false)
            .order("display_name")
            .execute()
            .value
        return rows
    }

    /// Create a parent-managed athlete under the account + family.
    func addManagedAthlete(
        accountID: String,
        familyID: String?,
        athlete: Athlete
    ) async throws {
        guard isConfigured else { return }
        let upsert = ManagedAthleteUpsert(
            id: athlete.id,
            accountId: accountID,
            familyId: familyID,
            username: ProfileValidation.normalizedUsername(athlete.username),
            displayName: ProfileValidation.normalizedName(athlete.displayName),
            initials: ProfileValidation.initials(from: athlete.displayName),
            kitNumber: ProfileValidation.normalizedKitNumber(athlete.kitNumber),
            position: ProfileValidation.isPositionValid(athlete.position) ? athlete.position : "No preference",
            managed: true
        )
        try await client.from("player_profiles").upsert(upsert).execute()

        // Seed a zeroed player_state so the athlete's individualized program
        // starts clean.
        try await client
            .from("player_state")
            .upsert(PlayerStateUpsert(
                playerId: athlete.id,
                xp: 0, streak: 0, freezesRemaining: 0,
                lastTrainedDate: nil, streakPb: 0
            ), onConflict: "player_id")
            .execute()
    }

    /// Update a managed athlete's shareable roster fields.
    func updateAthlete(id: String, name: String, kit: String, position: String) async throws {
        guard isConfigured else { return }
        let update = PlayerRosterUpdate(
            displayName: ProfileValidation.normalizedName(name),
            initials: ProfileValidation.initials(from: name),
            kitNumber: ProfileValidation.normalizedKitNumber(kit),
            position: ProfileValidation.isPositionValid(position) ? position : "No preference"
        )
        try await client
            .from("player_profiles")
            .update(update)
            .eq("id", value: id)
            .execute()
    }

    /// Remove a managed athlete from the household (account-owner only).
    func removeAthlete(id: String) async throws {
        guard isConfigured else { return }
        try await client
            .from("player_profiles")
            .delete()
            .eq("id", value: id)
            .execute()
    }
}
