//
//  MyTeamsStore.swift
//  MFElite
//
//  The signed-in PLAYER's own team memberships, used to filter targeted
//  broadcasts (announcements, coach workouts, team events) down to what this
//  player should actually see. Cached in UserDefaults so filtering still
//  works offline. Coaches bypass filtering entirely (they see everything).
//

import Foundation

@MainActor
final class MyTeamsStore {
    static let shared = MyTeamsStore()
    private init() {
        cachedTeamIDs = Set(UserDefaults.standard.stringArray(forKey: Self.cacheKey) ?? [])
    }

    private static let cacheKey = "MF_MY_TEAM_IDS"
    private var cachedTeamIDs: Set<String>
    private var lastFetched: Date?

    /// This player's team ids. Refreshes from the server at most every 10
    /// minutes; always returns the last known set (offline-safe).
    func currentTeamIDs() async -> Set<String> {
        let stale = lastFetched.map { Date().timeIntervalSince($0) > 600 } ?? true
        if stale, SupabaseAuth.shared.isSignedIn, let uid = SupabaseAuth.shared.userID {
            if let rows = await SupabaseClient.shared.get(
                table: "team_members",
                query: [
                    URLQueryItem(name: "player_id", value: "eq.\(uid)"),
                    URLQueryItem(name: "select", value: "team_id")
                ]
            ) {
                cachedTeamIDs = Set(rows.compactMap { $0["team_id"] as? String })
                UserDefaults.standard.set(Array(cachedTeamIDs), forKey: Self.cacheKey)
                lastFetched = Date()
            }
        }
        return cachedTeamIDs
    }

    /// Forget this account's memberships. Must be called on sign-out.
    ///
    /// Without this the set survives in UserDefaults and `lastFetched` keeps
    /// suppressing the refetch, so a second account signing in within ten
    /// minutes inherits the first account's team ids — and with them, the
    /// coach announcements, workouts and events targeted at those teams.
    func reset() {
        cachedTeamIDs = []
        lastFetched = nil
        UserDefaults.standard.removeObject(forKey: Self.cacheKey)
    }

    /// Whether a broadcast row (with audience/target_team_ids/target_player_ids
    /// columns) is visible to the signed-in user. Coaches see everything.
    static func isVisibleToMe(row: [String: Any], myTeamIDs: Set<String>) -> Bool {
        if SubscriptionService.shared.isCoach { return true }
        let audience = (row["audience"] as? String) ?? "everyone"
        switch audience {
        case "teams":
            let targets = Set((row["target_team_ids"] as? [String]) ?? [])
            return !targets.isDisjoint(with: myTeamIDs)
        case "athletes":
            let targets = (row["target_player_ids"] as? [String]) ?? []
            guard let uid = SupabaseAuth.shared.userID else { return false }
            return targets.contains(uid)
        default:
            return true
        }
    }
}
