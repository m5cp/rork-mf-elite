//
//  CoachViewModel.swift
//  MFElite
//
//  Read-only Coach Mode data layer. Loads team overview, roster, and per-player
//  detail from Supabase. All fetches are async, fail soft to a retry state, and
//  cache in memory. Coaches read player data via the database's owner/coach
//  policies; nothing here mutates a player's data.
//

import Foundation
import SwiftData
import Observation

/// Simple async load state for a section.
enum CoachLoadState: Equatable {
    case idle
    case loading
    case loaded
    case failed
}

/// Team-wide summary numbers for the Coach overview header.
struct CoachOverview: Equatable {
    var totalPlayers: Int
    var activeThisWeek: Int
    var teamMinutesThisWeek: Int
    var sessionsThisWeek: Int
}

/// One roster entry, joined client-side from player_profiles + profiles.
struct RosterPlayer: Identifiable, Equatable, Hashable {
    let id: String            // player_profiles.id (== player_id / user_id)
    let accountID: String
    var displayName: String
    var username: String?
    var kitNumber: String?
    var position: String?
    var email: String?
    var lastActive: Date?
}

/// A discipline's mastered-drill count for a player.
struct DisciplineMastery: Identifiable, Equatable {
    let id: String
    let name: String
    let count: Int
}

/// The latest recorded value for a combine test.
struct CombineLatest: Identifiable, Equatable {
    let id: String            // test id
    let name: String
    let value: Double
    let unit: String
    let lowerIsBetter: Bool
    let date: Date
}

/// One session in a player's history list.
struct SessionHistoryItem: Identifiable, Equatable {
    let id: UUID
    let drillTitle: String
    let date: Date
    let durationSec: Int
    let feltRating: Int?
}

/// Full per-player detail assembled for the coach.
struct CoachPlayerDetail: Equatable {
    var xp: Int
    var streak: Int
    var streakPB: Int
    var lastTrained: Date?
    var masteryByDiscipline: [DisciplineMastery]
    var totalMastered: Int
    var minutesAllTime: Int
    var minutes30d: Int
    var minutes7d: Int
    var sessionCount: Int
    var combineLatest: [CombineLatest]
    var gameIQCompleted: Int
    var history: [SessionHistoryItem]
}

@Observable
@MainActor
final class CoachViewModel {
    var overviewState: CoachLoadState = .idle
    var overview: CoachOverview?
    var roster: [RosterPlayer] = []
    var searchText: String = ""

    /// Per-player detail cache + load state, keyed by player id.
    var detailState: [String: CoachLoadState] = [:]
    var detailCache: [String: CoachPlayerDetail] = [:]

    /// Roster filtered + sorted (most recently active first).
    var filteredRoster: [RosterPlayer] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let base = query.isEmpty ? roster : roster.filter {
            $0.displayName.lowercased().contains(query)
                || ($0.username?.lowercased().contains(query) ?? false)
                || ($0.email?.lowercased().contains(query) ?? false)
        }
        return base.sorted { ($0.lastActive ?? .distantPast) > ($1.lastActive ?? .distantPast) }
    }

    // MARK: - Overview + roster

    /// Load (or refresh) the overview + roster. Keeps existing data on failure
    /// when we already have some, so pull-to-retry never blanks the screen.
    func loadOverviewAndRoster(context: ModelContext) async {
        if overview == nil { overviewState = .loading }

        guard let profileRows = await SupabaseClient.shared.get(
            table: "player_profiles",
            query: [
                URLQueryItem(name: "is_example", value: "eq.false"),
                URLQueryItem(name: "select", value: "id,display_name,username,kit_number,position,account_id")
            ]
        ) else {
            overviewState = overview == nil ? .failed : .loaded
            return
        }

        // Emails: join client-side against profiles for each account_id.
        let accountIDs = Array(Set(profileRows.compactMap { $0["account_id"] as? String }))
        var emailByAccount: [String: String] = [:]
        if !accountIDs.isEmpty {
            let inList = "(\(accountIDs.joined(separator: ",")))"
            let emailRows = await SupabaseClient.shared.get(
                table: "profiles",
                query: [
                    URLQueryItem(name: "id", value: "in.\(inList)"),
                    URLQueryItem(name: "select", value: "id,email")
                ]
            ) ?? []
            for row in emailRows {
                if let id = row["id"] as? String, let email = row["email"] as? String {
                    emailByAccount[id] = email
                }
            }
        }

        // Recent session logs power both "last active" and the weekly overview.
        let logRows = await SupabaseClient.shared.get(
            table: "session_logs",
            query: [
                URLQueryItem(name: "select", value: "user_id,completed_at,duration_sec"),
                URLQueryItem(name: "order", value: "completed_at.desc"),
                URLQueryItem(name: "limit", value: "1000")
            ]
        ) ?? []

        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        var lastActive: [String: Date] = [:]
        var activeUsers: Set<String> = []
        var minutesThisWeek = 0
        var sessionsThisWeek = 0
        for row in logRows {
            guard let uid = row["user_id"] as? String,
                  let date = Self.parseDate(row["completed_at"]) else { continue }
            if lastActive[uid] == nil { lastActive[uid] = date }   // desc order → first is newest
            if date >= weekAgo {
                activeUsers.insert(uid)
                sessionsThisWeek += 1
                minutesThisWeek += (row["duration_sec"] as? Int) ?? 0
            }
        }

        roster = profileRows.map { row in
            let id = (row["id"] as? String) ?? ""
            let accountID = (row["account_id"] as? String) ?? id
            return RosterPlayer(
                id: id,
                accountID: accountID,
                displayName: (row["display_name"] as? String) ?? "Player",
                username: row["username"] as? String,
                kitNumber: row["kit_number"] as? String,
                position: row["position"] as? String,
                email: emailByAccount[accountID],
                lastActive: lastActive[id]
            )
        }

        overview = CoachOverview(
            totalPlayers: profileRows.count,
            activeThisWeek: activeUsers.count,
            teamMinutesThisWeek: minutesThisWeek / 60,
            sessionsThisWeek: sessionsThisWeek
        )
        overviewState = .loaded
    }

    // MARK: - Player detail

    /// Load one player's detail. Uses cached data immediately when present, then
    /// refreshes. `force` re-fetches even when cached (pull-to-refresh).
    func loadDetail(for player: RosterPlayer, context: ModelContext, force: Bool = false) async {
        let pid = player.id
        if !force, detailCache[pid] != nil {
            detailState[pid] = .loaded
            return
        }
        if detailCache[pid] == nil { detailState[pid] = .loading }

        async let stateRowsAsync = SupabaseClient.shared.get(
            table: "player_state",
            query: [
                URLQueryItem(name: "player_id", value: "eq.\(pid)"),
                URLQueryItem(name: "limit", value: "1")
            ]
        )
        async let progressRowsAsync = SupabaseClient.shared.get(
            table: "player_progress",
            query: [
                URLQueryItem(name: "player_id", value: "eq.\(pid)"),
                URLQueryItem(name: "is_mastered", value: "eq.true"),
                URLQueryItem(name: "select", value: "drill_id,is_mastered")
            ]
        )
        async let logRowsAsync = SupabaseClient.shared.get(
            table: "session_logs",
            query: [
                URLQueryItem(name: "user_id", value: "eq.\(pid)"),
                URLQueryItem(name: "select", value: "id,drill_title,completed_at,duration_sec,felt_rating"),
                URLQueryItem(name: "order", value: "completed_at.desc"),
                URLQueryItem(name: "limit", value: "500")
            ]
        )
        async let combineRowsAsync = SupabaseClient.shared.get(
            table: "combine_results",
            query: [
                URLQueryItem(name: "user_id", value: "eq.\(pid)"),
                URLQueryItem(name: "select", value: "test_id,value,recorded_at"),
                URLQueryItem(name: "order", value: "recorded_at.desc")
            ]
        )
        async let iqRowsAsync = SupabaseClient.shared.get(
            table: "gameiq_completions",
            query: [
                URLQueryItem(name: "user_id", value: "eq.\(pid)"),
                URLQueryItem(name: "select", value: "lesson_id")
            ]
        )

        let stateRows = await stateRowsAsync
        let progressRows = await progressRowsAsync
        let logRows = await logRowsAsync
        let combineRows = await combineRowsAsync
        let iqRows = await iqRowsAsync

        // Any total failure (all nil) with no cache → failed.
        if stateRows == nil && progressRows == nil && logRows == nil
            && combineRows == nil && iqRows == nil && detailCache[pid] == nil {
            detailState[pid] = .failed
            return
        }

        // player_state
        let state = stateRows?.first
        let xp = (state?["xp"] as? Int) ?? 0
        let streak = (state?["streak"] as? Int) ?? 0
        let streakPB = (state?["streak_pb"] as? Int) ?? 0
        let lastTrained = Self.parseDate(state?["last_trained_date"])

        // Mastery grouped by discipline (map remote drill uuid → local discipline).
        let uuidToDiscipline = Self.drillUUIDToDiscipline(context: context)
        var masteryCounts: [String: (name: String, count: Int)] = [:]
        var totalMastered = 0
        for row in (progressRows ?? []) {
            guard let uuid = row["drill_id"] as? String,
                  let disc = uuidToDiscipline[uuid] else { continue }
            totalMastered += 1
            let current = masteryCounts[disc.id]
            masteryCounts[disc.id] = (disc.name, (current?.count ?? 0) + 1)
        }
        let masteryByDiscipline = masteryCounts
            .map { DisciplineMastery(id: $0.key, name: $0.value.name, count: $0.value.count) }
            .sorted { $0.count > $1.count }

        // Session logs → time totals + history.
        let now = Date()
        let day30 = Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now
        let day7 = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
        var minutesAll = 0, minutes30 = 0, minutes7 = 0
        var history: [SessionHistoryItem] = []
        for row in (logRows ?? []) {
            let secs = (row["duration_sec"] as? Int) ?? 0
            let date = Self.parseDate(row["completed_at"]) ?? now
            minutesAll += secs
            if date >= day30 { minutes30 += secs }
            if date >= day7 { minutes7 += secs }
            let id = (row["id"] as? String).flatMap(UUID.init) ?? UUID()
            history.append(SessionHistoryItem(
                id: id,
                drillTitle: (row["drill_title"] as? String) ?? "Session",
                date: date,
                durationSec: secs,
                feltRating: row["felt_rating"] as? Int
            ))
        }

        // Latest combine value per test.
        let testMeta = Self.combineTestMeta(context: context)
        var latestByTest: [String: CombineLatest] = [:]
        for row in (combineRows ?? []) {
            guard let testID = row["test_id"] as? String else { continue }
            let value = (row["value"] as? Double) ?? Double((row["value"] as? String) ?? "") ?? 0
            let date = Self.parseDate(row["recorded_at"]) ?? now
            if let existing = latestByTest[testID], existing.date >= date { continue }
            let meta = testMeta[testID]
            latestByTest[testID] = CombineLatest(
                id: testID,
                name: meta?.name ?? testID,
                value: value,
                unit: meta?.unit ?? "",
                lowerIsBetter: meta?.lowerIsBetter ?? false,
                date: date
            )
        }
        let combineLatest = latestByTest.values.sorted { $0.name < $1.name }

        let detail = CoachPlayerDetail(
            xp: xp,
            streak: streak,
            streakPB: max(streakPB, streak),
            lastTrained: lastTrained,
            masteryByDiscipline: masteryByDiscipline,
            totalMastered: totalMastered,
            minutesAllTime: minutesAll / 60,
            minutes30d: minutes30 / 60,
            minutes7d: minutes7 / 60,
            sessionCount: (logRows ?? []).count,
            combineLatest: combineLatest,
            gameIQCompleted: (iqRows ?? []).count,
            history: history
        )
        detailCache[pid] = detail
        detailState[pid] = .loaded
    }

    // MARK: - Local mapping helpers

    /// Map each local drill's deterministic remote UUID → its discipline.
    private static func drillUUIDToDiscipline(context: ModelContext) -> [String: (id: String, name: String)] {
        let disciplines = (try? context.fetch(FetchDescriptor<Discipline>())) ?? []
        var map: [String: (id: String, name: String)] = [:]
        for discipline in disciplines {
            for category in discipline.categories {
                for level in category.levels {
                    for drill in level.drills {
                        let uuid = SyncEngine.drillUUID(from: drill.id)
                        map[uuid] = (discipline.id, discipline.name)
                    }
                }
            }
        }
        return map
    }

    /// Combine test metadata keyed by id, for labeling latest results.
    private static func combineTestMeta(context: ModelContext) -> [String: (name: String, unit: String, lowerIsBetter: Bool)] {
        let tests = (try? context.fetch(FetchDescriptor<CombineTest>())) ?? []
        var map: [String: (name: String, unit: String, lowerIsBetter: Bool)] = [:]
        for test in tests {
            map[test.id] = (test.name, test.unit, test.lowerIsBetter)
        }
        return map
    }

    /// Parse a Postgres date / timestamptz value into a Date.
    private static func parseDate(_ value: Any?) -> Date? {
        guard let string = value as? String else { return nil }
        if let date = ISO8601DateFormatter.withFractional.date(from: string) { return date }
        if let date = ISO8601DateFormatter().date(from: string) { return date }
        return SyncEngine.date(from: string)   // "yyyy-MM-dd" (last_trained_date)
    }
}
