//
//  CoachRosterViewModel.swift
//  MFElite
//
//  Loads the real squad roster from Supabase (shareable layer only — no PII)
//  and surfaces a single clearly-marked example entry that is coach-only and
//  never shown in the player app.
//

import SwiftUI
import Observation

@MainActor
@Observable
final class CoachRosterViewModel {
    var players: [PlayerProfileRow] = []
    var pendingInvites: [RosterInviteRow] = []
    var isLoading = false
    var errorMessage: String?

    private var coachID: String? { AuthService.shared.user?.id }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            players = try await ProfileService.shared.fetchRoster(includeExamples: false)
            if let coachID {
                pendingInvites = try await ProfileService.shared.fetchPendingInvites(coachID: coachID)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Create an invite (and a pending roster slot) for a new player.
    @discardableResult
    func addPlayer(name: String, kit: String, position: String) async -> String? {
        guard let coachID else { return nil }
        do {
            let code = try await ProfileService.shared.createInvite(
                coachID: coachID, name: name, kit: kit, position: position
            )
            await load()
            return code
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func updatePlayer(_ player: PlayerProfileRow, name: String, kit: String, position: String) async {
        do {
            try await ProfileService.shared.coachUpdateRoster(
                playerID: player.id, name: name, kit: kit, position: position
            )
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func resetPlayer(_ player: PlayerProfileRow) async {
        do {
            try await ProfileService.shared.coachResetProfile(playerID: player.id)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
