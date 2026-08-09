//
//  TeamStatsStore.swift
//  MFElite
//
//  Coach-side data layer for the season stat sheet: the filed game reports, the
//  roster they're filed against, and the scheduled games that make a missing
//  report visible.
//
//  Scoped to one team at a time. Everything fails soft the way the rest of the
//  sync layer does — a failed read leaves whatever is already loaded alone, and
//  a failed write returns false so the caller can say so rather than showing a
//  coach a saved report that never left the phone.
//

import Foundation
import Observation

@Observable
@MainActor
final class TeamStatsStore {
    static let shared = TeamStatsStore()
    private init() {}

    /// Reports for `loadedTeamID`, newest game first.
    private(set) var reports: [TeamStatReport] = []
    /// The team's current squad, in shirt-number order.
    private(set) var roster: [TeamStatsPlayer] = []
    /// The team's game events that have already kicked off.
    private(set) var scheduledGames: [TeamStatsScheduledGame] = []
    private(set) var loadedTeamID: String?

    var state: CoachLoadState = .idle

    // MARK: - Scope

    /// The teams this coach may actually file stats for.
    ///
    /// Head coaches file for anyone; every other coach only for the teams they
    /// created, which is exactly what the server's write policy allows. Listing
    /// a team here that the database will refuse would give the coach a Save
    /// button that appears to work and reaches nobody.
    var manageableTeams: [CoachTeam] {
        let all = TeamsStore.shared.teams
        if SubscriptionService.shared.coachRole == "head_coach" { return all }
        guard let uid = SupabaseAuth.shared.userID else { return [] }
        return all.filter { $0.createdBy == uid }
    }

    /// Seasons worth offering in the picker: everything filed or scheduled,
    /// plus the current one so a coach can always start this year's sheet.
    var seasons: [String] {
        var found = Set(reports.map { $0.season }.filter { !$0.isEmpty })
        found.formUnion(scheduledGames.map { $0.season })
        found.insert(TeamStatsFormat.season(for: Date()))
        return found.sorted(by: >)
    }

    // MARK: - Load

    /// Load everything the sheet needs for one team.
    func load(teamID: String) async {
        guard SupabaseAuth.shared.isSignedIn, !teamID.isEmpty else {
            state = .failed
            return
        }

        // Switching teams must not leave the previous team's numbers on screen
        // while the new ones arrive — a stat sheet attributed to the wrong team
        // is worse than an empty one.
        if loadedTeamID != teamID {
            reports = []
            roster = []
            scheduledGames = []
        }
        loadedTeamID = teamID
        if reports.isEmpty { state = .loading }

        await loadRoster(teamID: teamID)
        await loadScheduledGames(teamID: teamID)

        guard let rows = await SupabaseClient.shared.get(
            table: "team_stat_reports",
            query: [
                URLQueryItem(name: "team_id", value: "eq.\(teamID)"),
                URLQueryItem(name: "order", value: "game_date.desc")
            ]
        ) else {
            state = reports.isEmpty ? .failed : .loaded
            return
        }

        reports = rows.compactMap(Self.report(from:))
        state = .loaded
    }

    /// The squad, read straight from `player_profiles` rather than from
    /// `TeamsStore.athletes` — the sheet needs `class_year` for the Grade
    /// column, and that store's projection doesn't carry it.
    private func loadRoster(teamID: String) async {
        if TeamsStore.shared.teams.isEmpty { await TeamsStore.shared.loadTeams() }
        let memberIDs = TeamsStore.shared.teams.first { $0.id == teamID }?.memberIDs ?? []
        guard !memberIDs.isEmpty else {
            roster = []
            return
        }

        let ids = memberIDs.joined(separator: ",")
        guard let rows = await SupabaseClient.shared.get(
            table: "player_profiles",
            query: [
                URLQueryItem(name: "id", value: "in.(\(ids))"),
                URLQueryItem(name: "select", value: "id,display_name,kit_number,class_year")
            ]
        ) else { return }

        let loaded: [TeamStatsPlayer] = rows.compactMap { row in
            guard let id = row["id"] as? String else { return nil }
            return TeamStatsPlayer(
                id: id,
                displayName: (row["display_name"] as? String) ?? "Player",
                kitNumber: (row["kit_number"] as? String) ?? "",
                classYear: (row["class_year"] as? Int) ?? 0
            )
        }
        roster = TeamStatsFormat.sortRoster(loaded)
    }

    /// The team's games that have already kicked off.
    ///
    /// `TeamEventsFeed.publish` never writes `team_events.team_id` — it targets
    /// through the broadcast columns instead — so a game belongs to this team
    /// when either the column or `target_team_ids` names it. A game published
    /// to "everyone" is deliberately not counted: it isn't attributable to one
    /// team, and guessing would inflate every team's missing-report count.
    private func loadScheduledGames(teamID: String) async {
        let cutoff = ISO8601DateFormatter.withFractional.string(from: Date())
        guard let rows = await SupabaseClient.shared.get(
            table: "team_events",
            query: [
                URLQueryItem(name: "kind", value: "eq.game"),
                URLQueryItem(name: "active", value: "eq.true"),
                URLQueryItem(name: "starts_at", value: "lt.\(cutoff)"),
                URLQueryItem(name: "order", value: "starts_at.desc")
            ]
        ) else { return }

        scheduledGames = rows.compactMap { row in
            guard let id = row["id"] as? String,
                  let starts = Self.parseTimestamp(row["starts_at"]) else { return nil }
            let targets = (row["target_team_ids"] as? [String]) ?? []
            let column = row["team_id"] as? String
            guard column == teamID || targets.contains(teamID) else { return nil }
            return TeamStatsScheduledGame(
                id: id,
                title: (row["title"] as? String) ?? "Game",
                startsAt: starts,
                season: TeamStatsFormat.season(for: starts)
            )
        }
    }

    // MARK: - Derived

    /// Past scheduled games for a season — the denominator behind "missing".
    func scheduledGameIDs(season: String) -> Set<String> {
        Set(scheduledGames.filter { $0.season == season }.map { $0.id })
    }

    /// The cumulative sheet for one season of the loaded team.
    func sheet(teamName: String, season: String) -> TeamStatsSheet {
        TeamStatsSheet.build(
            teamName: teamName,
            season: season,
            roster: roster,
            reports: reports.filter { $0.season == season },
            scheduledGameIDs: scheduledGameIDs(season: season)
        )
    }

    /// Reports for one season, newest first.
    func filedReports(season: String) -> [TeamStatReport] {
        reports.filter { $0.season == season }
    }

    /// Scheduled games a report can still be attached to: the ones nobody has
    /// filed against yet, plus whichever this report is already linked to so
    /// editing doesn't drop the link.
    func linkableGames(season: String, currentEventID: String?) -> [TeamStatsScheduledGame] {
        let linked = Set(reports.compactMap { $0.eventID })
        return scheduledGames.filter { game in
            guard game.season == season else { return false }
            if game.id == currentEventID { return true }
            return !linked.contains(game.id)
        }
    }

    // MARK: - Mutations

    /// File or update one game report. Reloads on success so the sheet and the
    /// report list can never disagree with the server.
    @discardableResult
    func save(_ report: TeamStatReport) async -> Bool {
        guard let uid = SupabaseAuth.shared.userID else { return false }

        // Only the players who were actually involved are stored; a squad of
        // untouched zero rows would triple the size of every report for no
        // information at all.
        let lines = report.lines.filter { !$0.isEmpty }.map { $0.jsonObject }

        var row: [String: Any] = [
            "id": report.id,
            "team_id": report.teamID,
            "season": report.season,
            "game_date": Self.gameDay.string(from: report.gameDate),
            "opponent": report.opponent.trimmingCharacters(in: .whitespacesAndNewlines),
            "result": report.result.rawValue,
            "goals_for": report.goalsFor,
            "goals_against": report.goalsAgainst,
            "lines": lines,
            "updated_by": uid,
            "updated_at": SyncEngine.iso.string(from: Date())
        ]
        // Left out entirely rather than sent as null: `event_id` is nullable and
        // an upsert that names the column would clear an existing link.
        if let eventID = report.eventID { row["event_id"] = eventID }

        let ok = await SupabaseClient.shared.upsert(
            table: "team_stat_reports", values: row, onConflict: "id"
        )
        if ok { await load(teamID: report.teamID) }
        return ok
    }

    /// Remove a filed report.
    ///
    /// Counted, not fire-and-forget: PostgREST answers a DELETE that a policy
    /// filtered down to nothing with 204, so a coach without write access to
    /// this team would otherwise watch the row disappear locally and come back
    /// on the next refresh.
    @discardableResult
    func delete(_ report: TeamStatReport) async -> Bool {
        guard let deleted = await SupabaseClient.shared.deleteCounting(
            table: "team_stat_reports", match: ["id": report.id]
        ), deleted > 0 else { return false }
        reports.removeAll { $0.id == report.id }
        return true
    }

    /// Post the season summary to this one team.
    ///
    /// Targeted at the team, never `everyone` — the owner was explicit that a
    /// stat sheet belongs to the coach's own players and not to the app. The
    /// audience columns are the same ones every other coach broadcast uses, so
    /// the existing player-side filtering already enforces it.
    func postToTeam(teamID: String, teamName: String, summary: String) async -> Bool {
        let audience = BroadcastAudience(scope: .teams, teamIDs: [teamID])
        guard audience.isValid else { return false }
        var row: [String: Any] = [
            "title": "\(teamName) \u{00B7} Season stats",
            "body": summary,
            "active": true
        ]
        audience.apply(to: &row)
        return await SupabaseClient.shared.insert(table: "announcements", values: row)
    }

    // MARK: - Row mapping

    private static func report(from row: [String: Any]) -> TeamStatReport? {
        guard let id = row["id"] as? String,
              let teamID = row["team_id"] as? String else { return nil }
        let rawLines = (row["lines"] as? [[String: Any]]) ?? []
        let gameDate = parseDay(row["game_date"]) ?? Date()
        return TeamStatReport(
            id: id,
            teamID: teamID,
            eventID: row["event_id"] as? String,
            season: (row["season"] as? String) ?? TeamStatsFormat.season(for: gameDate),
            gameDate: gameDate,
            opponent: (row["opponent"] as? String) ?? "",
            result: TeamStatResult(rawValue: (row["result"] as? String) ?? "") ?? .draw,
            goalsFor: (row["goals_for"] as? Int) ?? 0,
            goalsAgainst: (row["goals_against"] as? Int) ?? 0,
            lines: rawLines.compactMap { TeamStatLine(json: $0) }
        )
    }

    /// A game date is a calendar date, not an instant.
    ///
    /// `SyncEngine.dateString` formats in UTC, which is right for the timestamp
    /// columns it was written for and wrong here: a 7pm kick-off in Kentucky is
    /// already tomorrow in UTC, so every evening game would be filed — and
    /// displayed back — a day late. This one stays in the coach's own timezone
    /// on the way out and on the way back in.
    private static let gameDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    /// `game_date` is a Postgres `date`, so it arrives as "2026-08-09".
    private static func parseDay(_ value: Any?) -> Date? {
        guard let string = value as? String else { return nil }
        return gameDay.date(from: string)
            ?? ISO8601DateFormatter.withFractional.date(from: string)
            ?? ISO8601DateFormatter().date(from: string)
    }

    private static func parseTimestamp(_ value: Any?) -> Date? {
        guard let string = value as? String else { return nil }
        return ISO8601DateFormatter.withFractional.date(from: string)
            ?? ISO8601DateFormatter().date(from: string)
            ?? SyncEngine.date(from: string)
    }
}
