//
//  ProfileService.swift
//  MFElite
//
//  Central gateway for player-profile reads/writes against Supabase. Both the
//  player onboarding flow and the coach admin go through here, so every write
//  passes the same validation and lands in one consistent shape.
//
//  Privacy: coaches read/write the shareable `player_profiles` layer only. The
//  private `profiles` layer (email, identity, billing) is owner-locked by RLS
//  and never touched here on a coach's behalf.
//

import Foundation
import Observation
import Supabase

@MainActor
@Observable
final class ProfileService {
    static let shared = ProfileService()

    var lastError: String?

    private init() {}

    private var client: SupabaseClient { SupabaseService.shared.client }
    private var isConfigured: Bool { SupabaseService.shared.isConfigured }

    // MARK: - Username availability

    /// Remote, case-insensitive uniqueness check via the `username_available`
    /// SECURITY DEFINER function. Returns true when the handle is free.
    /// When Supabase isn't configured we optimistically allow (offline-first).
    func isUsernameAvailable(_ username: String) async -> Bool {
        guard isConfigured else { return true }
        let candidate = ProfileValidation.normalizedUsername(username)
        guard ProfileValidation.isUsernameFormatValid(candidate) else { return false }
        do {
            let available: Bool = try await client
                .rpc("username_available", params: UsernameAvailableParams(candidate: candidate))
                .execute()
                .value
            return available
        } catch {
            // Don't hard-block onboarding on a network blip; DB unique index is
            // the final guard on insert anyway.
            print("[ProfileService] username check failed: \(error)")
            return true
        }
    }

    // MARK: - Player self-create (onboarding)

    /// Upsert the signed-in player's own shareable profile. `id == account_id`
    /// for a self-managed player.
    func upsertOwnProfile(
        userID: String,
        username: String,
        name: String,
        kit: String,
        position: String
    ) async throws {
        guard isConfigured else { return }
        let profile = PlayerProfileUpsert(
            id: userID,
            accountId: userID,
            username: ProfileValidation.normalizedUsername(username),
            displayName: ProfileValidation.normalizedName(name),
            initials: ProfileValidation.initials(from: name),
            kitNumber: ProfileValidation.normalizedKitNumber(kit),
            position: ProfileValidation.isPositionValid(position) ? position : "No preference"
        )
        try await client.from("player_profiles").upsert(profile).execute()
    }

    // MARK: - Invite claim (player redeems coach code)

    enum ClaimError: LocalizedError {
        case usernameTaken, invalidCode, notConfigured, unknown(String)

        var errorDescription: String? {
            switch self {
            case .usernameTaken: return "That username is already taken — choose another."
            case .invalidCode: return "That invite code is invalid or already used."
            case .notConfigured: return "Can't reach the academy right now. Try again later."
            case .unknown(let m): return m
            }
        }
    }

    /// Redeem a coach invite code for the signed-in player, claiming the chosen
    /// unique username. The coach's pre-filled name/kit/position merge in.
    func claimInvite(code: String, username: String) async throws -> PlayerProfileRow {
        guard isConfigured else { throw ClaimError.notConfigured }
        let params = ClaimInviteParams(
            inviteCode: ProfileValidation.normalizedInviteCode(code),
            pUsername: ProfileValidation.normalizedUsername(username)
        )
        do {
            let row: PlayerProfileRow = try await client
                .rpc("claim_roster_invite", params: params)
                .execute()
                .value
            return row
        } catch {
            let message = "\(error)"
            if message.contains("username_taken") { throw ClaimError.usernameTaken }
            if message.contains("invalid_or_used_code") { throw ClaimError.invalidCode }
            throw ClaimError.unknown(error.localizedDescription)
        }
    }

    /// Redeem a coach invite code AFTER onboarding. Merges the coach's pre-filled
    /// name/kit/position into the player's existing profile and keeps their own
    /// username. Returns the merged row.
    func redeemInvite(code: String) async throws -> PlayerProfileRow {
        guard isConfigured else { throw ClaimError.notConfigured }
        let params = RedeemInviteParams(
            inviteCode: ProfileValidation.normalizedInviteCode(code)
        )
        do {
            let row: PlayerProfileRow = try await client
                .rpc("redeem_roster_invite", params: params)
                .execute()
                .value
            return row
        } catch {
            let message = "\(error)"
            if message.contains("invalid_or_used_code") { throw ClaimError.invalidCode }
            if message.contains("not_authenticated") { throw ClaimError.notConfigured }
            throw ClaimError.unknown(error.localizedDescription)
        }
    }

    // MARK: - Coach roster

    /// All real players visible to the coach (example placeholders excluded).
    func fetchRoster(includeExamples: Bool = false) async throws -> [PlayerProfileRow] {
        guard isConfigured else { return [] }
        var query = client.from("player_profiles").select()
        if !includeExamples {
            query = query.eq("is_example", value: false)
        }
        let rows: [PlayerProfileRow] = try await query
            .order("display_name")
            .execute()
            .value
        return rows
    }

    /// Coach edits a player's shareable roster fields (never the username — the
    /// DB trigger keeps the owner's handle).
    func coachUpdateRoster(
        playerID: String,
        name: String,
        kit: String,
        position: String
    ) async throws {
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
            .eq("id", value: playerID)
            .execute()
    }

    /// Coach reset: blank the roster fields so the player re-enters details on
    /// next launch. The record (and any progress) is retained.
    func coachResetProfile(playerID: String) async throws {
        guard isConfigured else { return }
        let update = PlayerRosterUpdate(
            displayName: "",
            initials: "",
            kitNumber: "",
            position: ""
        )
        try await client
            .from("player_profiles")
            .update(update)
            .eq("id", value: playerID)
            .execute()
    }

    // MARK: - Coach invites

    /// Create a coach invite code that pre-fills a player profile on claim.
    /// `isExample` flags the single hidden placeholder shown only to the coach.
    @discardableResult
    func createInvite(
        coachID: String,
        name: String?,
        kit: String?,
        position: String?,
        isExample: Bool = false
    ) async throws -> String {
        let code = ProfileValidation.generateInviteCode()
        guard isConfigured else { return code }
        let insert = RosterInviteInsert(
            code: code,
            coachId: coachID,
            displayName: name.map(ProfileValidation.normalizedName),
            kitNumber: kit.map(ProfileValidation.normalizedKitNumber),
            position: position,
            isExample: isExample
        )
        try await client.from("roster_invites").insert(insert).execute()
        return code
    }

    /// Pending invites the coach has issued (so they can share / track codes).
    func fetchPendingInvites(coachID: String) async throws -> [RosterInviteRow] {
        guard isConfigured else { return [] }
        let rows: [RosterInviteRow] = try await client
            .from("roster_invites")
            .select()
            .eq("coach_id", value: coachID)
            .eq("status", value: "pending")
            .order("created_at", ascending: false)
            .execute()
            .value
        return rows
    }
}
