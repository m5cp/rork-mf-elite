//
//  TeamsStore.swift
//  MFElite
//
//  Coach-side teams (rosters) data layer. A coach can build multiple teams,
//  add any app user to a team, and reuse those teams to target what they
//  publish. Head Coaches see and manage every coach's teams; regular coaches
//  manage only the teams they created (enforced server-side by RLS).
//
//  All reads/writes fail soft: they log and return a neutral result, and
//  local state is only mutated after the server confirms the change.
//

import Foundation
import Observation

/// One coach-owned team (roster). `memberIDs` are player_profiles ids
/// (== the athlete's account user id).
struct CoachTeam: Identifiable, Equatable, Hashable {
    let id: String
    var name: String
    var label: String
    let createdBy: String
    var memberIDs: [String] = []

    var memberCount: Int { memberIDs.count }
}

/// A lightweight athlete entry used by the team roster + audience pickers.
struct TeamAthlete: Identifiable, Equatable, Hashable {
    let id: String            // player_profiles.id (== account user id)
    var displayName: String
    var username: String?
    var kitNumber: String?
    var position: String?

    /// One-line subtitle for list rows.
    var subtitle: String {
        var parts: [String] = []
        if let username, !username.isEmpty { parts.append("@\(username)") }
        if let kitNumber, !kitNumber.isEmpty { parts.append("#\(kitNumber)") }
        if let position, !position.isEmpty { parts.append(position) }
        return parts.isEmpty ? "Player" : parts.joined(separator: " · ")
    }
}

@Observable
@MainActor
final class TeamsStore {
    static let shared = TeamsStore()
    private init() {}

    /// Teams the signed-in coach can manage (own teams, or all when head coach).
    private(set) var teams: [CoachTeam] = []
    /// Every non-example app user, for adding to teams and targeting.
    private(set) var athletes: [TeamAthlete] = []

    var teamsState: CoachLoadState = .idle
    var athletesState: CoachLoadState = .idle

    /// Fast lookup for rendering athlete rows by id.
    var athleteByID: [String: TeamAthlete] {
        Dictionary(uniqueKeysWithValues: athletes.map { ($0.id, $0) })
    }

    // MARK: - Load

    /// Load every team this coach can manage plus their memberships.
    func loadTeams() async {
        guard SupabaseAuth.shared.isSignedIn else { teamsState = .failed; return }
        if teams.isEmpty { teamsState = .loading }

        guard let teamRows = await SupabaseClient.shared.get(
            table: "teams",
            query: [URLQueryItem(name: "order", value: "created_at.asc")]
        ) else {
            teamsState = teams.isEmpty ? .failed : .loaded
            return
        }

        var loaded: [CoachTeam] = teamRows.compactMap { row in
            guard let id = row["id"] as? String else { return nil }
            return CoachTeam(
                id: id,
                name: (row["name"] as? String) ?? "Team",
                label: (row["label"] as? String) ?? "",
                createdBy: (row["created_by"] as? String) ?? ""
            )
        }

        // Memberships for the visible teams, grouped by team id.
        if !loaded.isEmpty {
            let ids = loaded.map(\.id).joined(separator: ",")
            let memberRows = await SupabaseClient.shared.get(
                table: "team_members",
                query: [
                    URLQueryItem(name: "team_id", value: "in.(\(ids))"),
                    URLQueryItem(name: "select", value: "team_id,player_id")
                ]
            ) ?? []
            var byTeam: [String: [String]] = [:]
            for row in memberRows {
                guard let teamID = row["team_id"] as? String,
                      let playerID = row["player_id"] as? String else { continue }
                byTeam[teamID, default: []].append(playerID)
            }
            for index in loaded.indices {
                loaded[index].memberIDs = byTeam[loaded[index].id] ?? []
            }
        }

        teams = loaded
        teamsState = .loaded
    }

    /// Load every non-example app user for the roster + audience pickers.
    func loadAthletes() async {
        guard SupabaseAuth.shared.isSignedIn else { athletesState = .failed; return }
        if athletes.isEmpty { athletesState = .loading }

        guard let rows = await SupabaseClient.shared.get(
            table: "player_profiles",
            query: [
                URLQueryItem(name: "is_example", value: "eq.false"),
                URLQueryItem(name: "select", value: "id,display_name,username,kit_number,position"),
                URLQueryItem(name: "order", value: "display_name.asc")
            ]
        ) else {
            athletesState = athletes.isEmpty ? .failed : .loaded
            return
        }

        athletes = rows.compactMap { row in
            guard let id = row["id"] as? String else { return nil }
            return TeamAthlete(
                id: id,
                displayName: (row["display_name"] as? String) ?? "Player",
                username: row["username"] as? String,
                kitNumber: row["kit_number"] as? String,
                position: row["position"] as? String
            )
        }
        athletesState = .loaded
    }

    // MARK: - Mutations

    /// Create a new team owned by the signed-in coach. Reloads on success.
    @discardableResult
    func createTeam(name: String, label: String) async -> Bool {
        guard let uid = SupabaseAuth.shared.userID else { return false }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return false }
        let row: [String: Any] = [
            "name": trimmedName,
            "label": label.trimmingCharacters(in: .whitespacesAndNewlines),
            "created_by": uid
        ]
        let ok = await SupabaseClient.shared.insert(table: "teams", values: row)
        if ok { await loadTeams() }
        return ok
    }

    /// Rename / relabel a team. Optimistic local update.
    @discardableResult
    func updateTeam(_ team: CoachTeam, name: String, label: String) async -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return false }
        let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        if let index = teams.firstIndex(where: { $0.id == team.id }) {
            teams[index].name = trimmedName
            teams[index].label = trimmedLabel
        }
        return await SupabaseClient.shared.update(
            table: "teams",
            values: ["name": trimmedName, "label": trimmedLabel],
            match: [URLQueryItem(name: "id", value: "eq.\(team.id)")]
        )
    }

    /// Delete a team. Memberships cascade server-side. Optimistic local removal.
    @discardableResult
    func deleteTeam(_ team: CoachTeam) async -> Bool {
        teams.removeAll { $0.id == team.id }
        await SupabaseClient.shared.delete(table: "team_members", match: ["team_id": team.id])
        return await SupabaseClient.shared.delete(table: "teams", match: ["id": team.id])
    }

    /// Add an athlete to a team (idempotent). Optimistic local update.
    @discardableResult
    func addAthlete(_ athleteID: String, to teamID: String) async -> Bool {
        guard let uid = SupabaseAuth.shared.userID else { return false }
        if let index = teams.firstIndex(where: { $0.id == teamID }),
           !teams[index].memberIDs.contains(athleteID) {
            teams[index].memberIDs.append(athleteID)
        }
        let row: [String: Any] = [
            "team_id": teamID,
            "player_id": athleteID,
            "added_by": uid
        ]
        return await SupabaseClient.shared.upsert(
            table: "team_members", values: row, onConflict: "team_id,player_id"
        )
    }

    /// Remove an athlete from a team. Optimistic local update.
    @discardableResult
    func removeAthlete(_ athleteID: String, from teamID: String) async -> Bool {
        if let index = teams.firstIndex(where: { $0.id == teamID }) {
            teams[index].memberIDs.removeAll { $0 == athleteID }
        }
        return await SupabaseClient.shared.delete(
            table: "team_members",
            match: ["team_id": teamID, "player_id": athleteID]
        )
    }
}

// MARK: - Broadcast audience

/// Who a published schedule event / announcement / workout is sent to. Serialized
/// onto every broadcast row as `audience`, `target_team_ids`, `target_player_ids`;
/// row-level security uses these to scope what each athlete can read.
struct BroadcastAudience: Equatable {
    enum Scope: String, CaseIterable, Identifiable {
        case everyone, teams, athletes
        var id: String { rawValue }

        var label: String {
            switch self {
            case .everyone: return "Everyone"
            case .teams: return "Teams"
            case .athletes: return "Athletes"
            }
        }
    }

    var scope: Scope = .everyone
    var teamIDs: Set<String> = []
    var athleteIDs: Set<String> = []

    /// Whether the current selection can be published.
    var isValid: Bool {
        switch scope {
        case .everyone: return true
        case .teams: return !teamIDs.isEmpty
        case .athletes: return !athleteIDs.isEmpty
        }
    }

    /// Merge the targeting columns into a row payload before insert.
    func apply(to row: inout [String: Any]) {
        row["audience"] = scope.rawValue
        row["target_team_ids"] = scope == .teams ? Array(teamIDs) : [String]()
        row["target_player_ids"] = scope == .athletes ? Array(athleteIDs) : [String]()
    }

    /// A short human summary for confirmation UI.
    func summary(teams: [CoachTeam], athletes: [TeamAthlete]) -> String {
        switch scope {
        case .everyone:
            return "Everyone"
        case .teams:
            let names = teams.filter { teamIDs.contains($0.id) }.map(\.name)
            return names.isEmpty ? "Select teams" : names.joined(separator: ", ")
        case .athletes:
            let count = athleteIDs.count
            return count == 0 ? "Select athletes" : "\(count) athlete\(count == 1 ? "" : "s")"
        }
    }
}
