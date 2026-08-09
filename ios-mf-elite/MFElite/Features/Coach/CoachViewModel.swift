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
    /// First names of the 3 most active players this week (by session count).
    var topActiveNames: [String] = []
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
    /// True when the player holds the coach-approved Ballon d'Or tier.
    var ballonDorApproved: Bool = false

    /// True when the player has trained 7+ days ago or never — needs attention.
    var needsAttention: Bool {
        guard let last = lastActive else { return true }
        return Date().timeIntervalSince(last) > 7 * 86400
    }
}

/// A named (player, minutes-this-week) pair for the team snapshot.
struct PlayerMinutes: Identifiable, Equatable {
    let id: String
    let name: String
    let minutes: Int
}

/// A one-glance weekly aggregate across the whole roster.
struct TeamSnapshot: Equatable {
    var totalPlayers: Int
    var activeThisWeek: Int
    var needsAttentionCount: Int
    var avgMinutesPerPlayer: Int
    var teamMinutesThisWeek: Int
    var mostActive: PlayerMinutes?
    var leastActive: PlayerMinutes?
}

/// One pending Ballon d'Or invitation request, with a stats summary for review.
struct PendingApproval: Identifiable, Equatable {
    let id: String            // player_profiles.id
    var displayName: String
    var kitNumber: String?
    var requestedAt: Date
    var xp: Int
    var streak: Int
    var mastered: Int
    var minutes30d: Int
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

/// One team announcement the coach can manage.
struct TeamAnnouncement: Identifiable, Equatable {
    let id: String
    var title: String
    var body: String
    var active: Bool
    var createdAt: Date
}

/// One workout the coach has published, for the WORKOUTS list.
struct CoachPublishedWorkout: Identifiable, Equatable {
    let id: String          // coach_workouts.id (uuid text)
    var title: String
    var note: String
    var drillIDs: [String]
    var active: Bool
    var createdAt: Date
}

/// Editable content for the coach drill editor. Mirrors the editable subset of
/// a `Drill`; arrays are kept as cleaned, non-empty lines.
struct DrillEditFields: Equatable {
    var title: String
    var focus: String
    var how: String
    var instructions: [String]
    var coachingPoints: [String]
    var durationSec: Int
    var sets: Int
    var equipment: [String]
    var space: String
    /// Public URL of an uploaded demo video, or nil when none is attached.
    var videoURL: String?
    /// Public URL of an uploaded reference image, or nil when none is attached.
    var imageURL: String?

    /// Build from an existing drill (for the edit screen).
    init(drill: Drill) {
        title = drill.title
        focus = drill.focus
        how = drill.how
        instructions = drill.instructions
        coachingPoints = drill.coachingPoints
        durationSec = drill.durationSec
        sets = drill.sets
        equipment = drill.equipment
        space = drill.space ?? ""
        videoURL = drill.videoURL
        imageURL = drill.imageURL
    }

    /// Empty fields for the "add a new drill" screen.
    init() {
        title = ""; focus = ""; how = ""
        instructions = []; coachingPoints = []
        durationSec = 300; sets = 1
        equipment = []; space = ""
        videoURL = nil
        imageURL = nil
    }

    private func clean(_ list: [String]) -> [String] {
        list.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    /// The full content payload for a new drill.
    func fullPayload() -> [String: Any] {
        var payload: [String: Any] = [
            "title": title.trimmingCharacters(in: .whitespacesAndNewlines),
            "focus": focus.trimmingCharacters(in: .whitespacesAndNewlines),
            "how": how.trimmingCharacters(in: .whitespacesAndNewlines),
            "instructions": clean(instructions),
            "coachingPoints": clean(coachingPoints),
            "durationSec": durationSec,
            "sets": sets,
            "equipment": clean(equipment)
        ]
        let trimmedSpace = space.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedSpace.isEmpty { payload["space"] = trimmedSpace }
        if let videoURL, !videoURL.isEmpty { payload["videoURL"] = videoURL }
        if let imageURL, !imageURL.isEmpty { payload["imageURL"] = imageURL }
        return payload
    }

    /// Only the fields that differ from `original`, for a minimal edit payload.
    func changedPayload(from original: Drill) -> [String: Any] {
        var payload: [String: Any] = [:]
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if t != original.title { payload["title"] = t }
        let f = focus.trimmingCharacters(in: .whitespacesAndNewlines)
        if f != original.focus { payload["focus"] = f }
        let h = how.trimmingCharacters(in: .whitespacesAndNewlines)
        if h != original.how { payload["how"] = h }
        let inst = clean(instructions)
        if inst != original.instructions { payload["instructions"] = inst }
        let cp = clean(coachingPoints)
        if cp != original.coachingPoints { payload["coachingPoints"] = cp }
        if durationSec != original.durationSec { payload["durationSec"] = durationSec }
        if sets != original.sets { payload["sets"] = sets }
        let eq = clean(equipment)
        if eq != original.equipment { payload["equipment"] = eq }
        let sp = space.trimmingCharacters(in: .whitespacesAndNewlines)
        if sp != (original.space ?? "") { payload["space"] = sp }
        if videoURL != original.videoURL { payload["videoURL"] = videoURL as Any }
        if imageURL != original.imageURL { payload["imageURL"] = imageURL as Any }
        return payload
    }
}

/// One (weekStart, minutes) point in a player's 8-week training trend.
/// A named struct (not a tuple) so `CoachPlayerDetail` keeps Equatable synthesis
/// and the value plots cleanly in Swift Charts.
struct WeeklyMinutesPoint: Identifiable, Equatable {
    var id: Date { weekStart }
    let weekStart: Date
    let minutes: Int
}

/// Baseline / latest / best for one combine test, for the coach's progress table.
struct CombineProgress: Identifiable, Equatable {
    var id: String { testID }
    let testID: String
    let label: String
    let baseline: Double
    let latest: Double
    let best: Double
    let unit: String
    let lowerIsBetter: Bool
}

/// One monthly coach note for a player (coach_notes table).
struct CoachNote: Identifiable, Equatable {
    let id: String
    let month: String   // "yyyy-MM"
    var body: String
    var updatedAt: Date
}

/// Full per-player detail assembled for the coach.
struct CoachPlayerDetail: Equatable {
    var xp: Int
    var streak: Int
    var streakPB: Int
    var lastTrained: Date?
    var masteryByDiscipline: [DisciplineMastery]
    var totalMastered: Int
    /// Distinct drills with at least one logged pass — the denominator that
    /// makes `totalMastered` mean something. Read `drillsStarted` to display it.
    var drillsCompleted: Int
    var minutesAllTime: Int
    var minutes30d: Int
    var minutes7d: Int
    var sessionCount: Int
    var combineLatest: [CombineLatest]
    var gameIQCompleted: Int
    var history: [SessionHistoryItem]
    /// Most-recent 8 weeks of training minutes (Monday weeks, oldest → newest).
    var weeklyMinutes: [WeeklyMinutesPoint]
    /// Baseline → latest · best per combine test.
    var combineProgress: [CombineProgress]
    /// The coach-authored focus for this player (player_profiles.coach_focus).
    var coachFocus: String

    /// Drills started, never fewer than the drills mastered.
    ///
    /// The two numbers come from different machines and only this one can
    /// regress. `totalMastered` is counted from server `player_progress` rows,
    /// which are upserted and never deleted. `drillsCompleted` is recounted
    /// from local `DrillProgress` and overwritten wholesale on every state
    /// sync — so a player who reinstalls, declines the restore prompt and logs
    /// one drill pushes `drills_completed: 1` over a server row backed by
    /// forty mastered drills. Displaying that verbatim reads "40 of 1".
    var drillsStarted: Int { max(drillsCompleted, totalMastered) }
}

@Observable
@MainActor
final class CoachViewModel {
    var overviewState: CoachLoadState = .idle
    var overview: CoachOverview?
    var roster: [RosterPlayer] = []
    var searchText: String = ""
    /// When the overview + roster last finished loading, for the "updated" label.
    var lastLoadedAt: Date?

    /// Per-player detail cache + load state, keyed by player id.
    var detailState: [String: CoachLoadState] = [:]
    var detailCache: [String: CoachPlayerDetail] = [:]

    /// Per-player monthly coach notes cache, keyed by player id.
    var notesCache: [String: [CoachNote]] = [:]

    /// Minutes trained this week per player id (powers the team snapshot).
    var weeklyMinutesByPlayer: [String: Int] = [:]

    /// Coach-published featured workouts (newest first).
    var publishedWorkouts: [CoachPublishedWorkout] = []
    var workoutsState: CoachLoadState = .idle

    /// Team announcements this coach can manage (newest first).
    var announcements: [TeamAnnouncement] = []
    var announcementsState: CoachLoadState = .idle

    /// Players who have met the Ballon d'Or bar and are awaiting coach review.
    var pendingApprovals: [PendingApproval] = []
    var approvalsState: CoachLoadState = .idle

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

    /// Players who need coach attention: inactive 7+ days, or never active.
    /// Uses each roster row's `lastActive` (the same source that powers the
    /// "Active this week" overview stat).
    var needsAttention: [RosterPlayer] {
        roster.filter(\.needsAttention)
    }

    /// A weekly one-glance aggregate across the whole roster.
    var teamSnapshot: TeamSnapshot {
        let total = roster.count
        let totalMinutes = weeklyMinutesByPlayer.values.reduce(0, +)
        let avg = total > 0 ? totalMinutes / total : 0
        let named = roster.map {
            PlayerMinutes(id: $0.id, name: ShareText.firstName($0.displayName),
                          minutes: weeklyMinutesByPlayer[$0.id] ?? 0)
        }
        let sorted = named.sorted { $0.minutes > $1.minutes }
        return TeamSnapshot(
            totalPlayers: total,
            activeThisWeek: overview?.activeThisWeek ?? named.filter { $0.minutes > 0 }.count,
            needsAttentionCount: needsAttention.count,
            avgMinutesPerPlayer: avg,
            teamMinutesThisWeek: overview?.teamMinutesThisWeek ?? (totalMinutes),
            mostActive: sorted.first(where: { $0.minutes > 0 }),
            leastActive: total > 0 ? sorted.last : nil
        )
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
                URLQueryItem(name: "select", value: "id,display_name,username,kit_number,position,account_id,ballon_dor_approved")
            ]
        ) else {
            overviewState = overview == nil ? .failed : .loaded
            return
        }

        // Emails: join client-side against profiles for each account_id.
        // Chunked, because a single `in.(...)` of a few hundred uuids builds a
        // URL long enough to be rejected.
        let accountIDs = Array(Set(profileRows.compactMap { $0["account_id"] as? String }))
        var emailByAccount: [String: String] = [:]
        for chunk in Self.chunked(accountIDs) {
            let emailRows = await SupabaseClient.shared.get(
                table: "profiles",
                query: [
                    URLQueryItem(name: "id", value: "in.(\(chunk.joined(separator: ",")))"),
                    URLQueryItem(name: "select", value: "id,email")
                ]
            ) ?? []
            for row in emailRows {
                if let id = row["id"] as? String, let email = row["email"] as? String {
                    emailByAccount[id] = email
                }
            }
        }

        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()

        // Session logs, scoped to this roster.
        //
        // This was "the 1,000 most recent session logs, table-wide". Once the
        // app passed ~1,000 sessions in the window, other players' logs filled
        // the slice and a coach's own active players started reporting as
        // "Never trained" in Needs Attention. Two scoped reads instead:
        //
        //   1. Everything in the last 7 days. Bounded by the window, so no
        //      limit is needed and the weekly totals are exact.
        //   2. For players with nothing in that window, their newest rows —
        //      only to fill in "last active".
        //
        // Step 2 still takes an ordered slice, so someone who last trained
        // further back than `lastActiveScan` rows shows no date rather than a
        // wrong one. A `last_active_per_player` RPC would close that gap.
        let sinceISO = ISO8601DateFormatter().string(from: weekAgo)
        var logRows: [[String: Any]] = []
        for chunk in Self.chunked(accountIDs) {
            logRows += await SupabaseClient.shared.get(
                table: "session_logs",
                query: [
                    URLQueryItem(name: "select", value: "user_id,completed_at,duration_sec"),
                    URLQueryItem(name: "user_id", value: "in.(\(chunk.joined(separator: ",")))"),
                    URLQueryItem(name: "completed_at", value: "gte.\(sinceISO)"),
                    URLQueryItem(name: "order", value: "completed_at.desc")
                ]
            ) ?? []
        }

        var lastActive: [String: Date] = [:]
        var activeUsers: Set<String> = []
        var minutesThisWeek = 0
        var sessionsThisWeek = 0
        var sessionsByUser: [String: Int] = [:]
        var secondsByUser: [String: Int] = [:]
        for row in logRows {
            guard let uid = row["user_id"] as? String,
                  let date = Self.parseDate(row["completed_at"]) else { continue }
            // Compared rather than assumed-first: rows now arrive as several
            // per-chunk responses, so "the first row wins" no longer holds
            // across the whole set.
            lastActive[uid] = max(lastActive[uid] ?? date, date)
            if date >= weekAgo {
                activeUsers.insert(uid)
                sessionsThisWeek += 1
                let secs = (row["duration_sec"] as? Int) ?? 0
                minutesThisWeek += secs
                sessionsByUser[uid, default: 0] += 1
                secondsByUser[uid, default: 0] += secs
            }
        }

        // Second pass: anyone with nothing in the last 7 days still needs a
        // "last active" date, so ask only for those players.
        let dormant = accountIDs.filter { lastActive[$0] == nil }
        for chunk in Self.chunked(dormant) {
            let rows = await SupabaseClient.shared.get(
                table: "session_logs",
                query: [
                    URLQueryItem(name: "select", value: "user_id,completed_at"),
                    URLQueryItem(name: "user_id", value: "in.(\(chunk.joined(separator: ",")))"),
                    URLQueryItem(name: "order", value: "completed_at.desc"),
                    URLQueryItem(name: "limit", value: "\(chunk.count * Self.lastActiveScan)")
                ]
            ) ?? []
            for row in rows {
                guard let uid = row["user_id"] as? String,
                      let date = Self.parseDate(row["completed_at"]) else { continue }
                lastActive[uid] = max(lastActive[uid] ?? date, date)
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
                lastActive: lastActive[id],
                ballonDorApproved: (row["ballon_dor_approved"] as? Bool) ?? false
            )
        }

        weeklyMinutesByPlayer = secondsByUser.mapValues { $0 / 60 }

        let nameByID = Dictionary(uniqueKeysWithValues: roster.map { ($0.id, $0.displayName) })
        let topActiveNames = sessionsByUser
            .sorted { $0.value > $1.value }
            .prefix(3)
            .compactMap { nameByID[$0.key] }
            .map { ShareText.firstName($0) }

        overview = CoachOverview(
            totalPlayers: profileRows.count,
            activeThisWeek: activeUsers.count,
            teamMinutesThisWeek: minutesThisWeek / 60,
            sessionsThisWeek: sessionsThisWeek,
            topActiveNames: topActiveNames
        )
        overviewState = .loaded
        lastLoadedAt = Date()
    }

    // MARK: - Published workouts (Coach's Workout of the Day)

    /// Load every workout this coach has published (active and inactive), newest first.
    func loadPublishedWorkouts() async {
        guard let createdBy = SupabaseAuth.shared.userID else {
            workoutsState = .failed
            return
        }
        if publishedWorkouts.isEmpty { workoutsState = .loading }
        guard let rows = await SupabaseClient.shared.get(
            table: "coach_workouts",
            query: [
                URLQueryItem(name: "created_by", value: "eq.\(createdBy)"),
                URLQueryItem(name: "order", value: "created_at.desc")
            ]
        ) else {
            workoutsState = publishedWorkouts.isEmpty ? .failed : .loaded
            return
        }
        publishedWorkouts = rows.compactMap { row in
            guard let id = row["id"] as? String else { return nil }
            return CoachPublishedWorkout(
                id: id,
                title: (row["title"] as? String) ?? "Workout",
                note: (row["note"] as? String) ?? "",
                drillIDs: (row["drill_ids"] as? [String]) ?? [],
                active: (row["active"] as? Bool) ?? true,
                createdAt: Self.parseDate(row["created_at"]) ?? Date()
            )
        }
        workoutsState = .loaded
    }

    /// Publish a new featured workout to a chosen audience. Fails soft.
    @discardableResult
    func publishWorkout(title: String, note: String, drillIDs: [String], audience: BroadcastAudience = BroadcastAudience()) async -> Bool {
        guard let createdBy = SupabaseAuth.shared.userID else { return false }
        let coachName = PlayerProfileStore.shared.displayName
        var row: [String: Any] = [
            "title": title,
            "note": note,
            "drill_ids": drillIDs,
            "coach_name": coachName,
            "active": true,
            "created_by": createdBy
        ]
        audience.apply(to: &row)
        // Report the real result. This was fire-and-forget, so a rejected
        // publish left players on yesterday's workout while the coach was told
        // nothing at all.
        guard await SupabaseClient.shared.insert(table: "coach_workouts", values: row) else { return false }
        await loadPublishedWorkouts()
        return true
    }

    /// Toggle a published workout active/inactive. Inactive workouts disappear
    /// from players' Today card; nothing else changes.
    @discardableResult
    func setWorkoutActive(_ workout: CoachPublishedWorkout, active: Bool) async -> Bool {
        // Optimistic local update so the toggle feels instant.
        if let index = publishedWorkouts.firstIndex(where: { $0.id == workout.id }) {
            publishedWorkouts[index].active = active
        }
        let ok = await SupabaseClient.shared.update(
            table: "coach_workouts",
            values: ["active": active],
            match: [URLQueryItem(name: "id", value: "eq.\(workout.id)")]
        )
        // Roll the optimistic change back on failure. Without this, clearing
        // the Workout of the Day showed "No workout set" to the coach while
        // every athlete still had yesterday's.
        if !ok, let index = publishedWorkouts.firstIndex(where: { $0.id == workout.id }) {
            publishedWorkouts[index].active = !active
        }
        return ok
    }

    // MARK: - Announcements

    /// Load recent announcements (active and inactive), newest first.
    func loadAnnouncements() async {
        if announcements.isEmpty { announcementsState = .loading }
        guard let rows = await SupabaseClient.shared.get(
            table: "announcements",
            query: [
                URLQueryItem(name: "order", value: "created_at.desc"),
                URLQueryItem(name: "limit", value: "30")
            ]
        ) else {
            announcementsState = announcements.isEmpty ? .failed : .loaded
            return
        }
        announcements = rows.compactMap { row in
            guard let id = row["id"] as? String else { return nil }
            return TeamAnnouncement(
                id: id,
                title: (row["title"] as? String) ?? "",
                body: (row["body"] as? String) ?? "",
                active: (row["active"] as? Bool) ?? true,
                createdAt: Self.parseDate(row["created_at"]) ?? Date()
            )
        }
        announcementsState = .loaded
    }

    /// Publish a new announcement, then return the "<title> — <body>" text the
    /// caller can share to a team chat.
    ///
    /// Returns nil when the insert failed. It used to ignore the result and
    /// always return the text, so the caller opened the share sheet and the
    /// coach sent "Practice moved to 6pm" to a couple of parents believing the
    /// whole team had been notified in-app. Nobody had.
    @discardableResult
    func sendAnnouncement(title: String, body: String, audience: BroadcastAudience = BroadcastAudience()) async -> String? {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return nil }
        var row: [String: Any] = [
            "title": trimmedTitle,
            "body": trimmedBody,
            "active": true
        ]
        audience.apply(to: &row)
        guard await SupabaseClient.shared.insert(table: "announcements", values: row) else { return nil }
        await loadAnnouncements()
        return trimmedBody.isEmpty ? trimmedTitle : "\(trimmedTitle) — \(trimmedBody)"
    }

    /// Deactivate an announcement (players stop seeing it). Optimistic local update.
    func setAnnouncementActive(_ announcement: TeamAnnouncement, active: Bool) async {
        if let index = announcements.firstIndex(where: { $0.id == announcement.id }) {
            announcements[index].active = active
        }
        await SupabaseClient.shared.update(
            table: "announcements",
            values: ["active": active],
            match: [URLQueryItem(name: "id", value: "eq.\(announcement.id)")]
        )
    }

    // MARK: - Drill editor (curriculum overlay)

    /// Publish an edit to an existing drill. Only the fields that actually changed
    /// from `original` are sent, as a `kind = "edit"` overlay row keyed by drill id.
    /// Returns true when at least one change was published.
    @discardableResult
    func publishDrillEdit(original: Drill, edited: DrillEditFields) async -> Bool {
        let payload = edited.changedPayload(from: original)
        // Nothing changed is a success, not a failure — the caller now shows an
        // error on false, and "you didn't edit anything" is not an error.
        guard !payload.isEmpty else { return true }
        let coachName = PlayerProfileStore.shared.displayName
        let row: [String: Any] = [
            "drill_id": original.id,
            "kind": "edit",
            "payload": payload,
            "updated_by": coachName,
            "active": true
        ]
        // Propagate the real result. This returned true unconditionally, so a
        // rejected edit still produced a success haptic and a dismissed sheet.
        return await SupabaseClient.shared.upsert(table: "curriculum_edits", values: row, onConflict: "drill_id")
    }

    /// Publish a brand-new coach-authored drill into a category/level. Generates a
    /// stable "COACH-…" id so it never collides with the bundled curriculum.
    @discardableResult
    func publishNewDrill(drillID: String, categoryID: String, levelNumber: Int, fields: DrillEditFields) async -> Bool {
        let coachName = PlayerProfileStore.shared.displayName
        let id = drillID
        let row: [String: Any] = [
            "drill_id": id,
            "kind": "new",
            "payload": fields.fullPayload(),
            "updated_by": coachName,
            "active": true,
            "category_id": categoryID,
            "level_number": levelNumber
        ]
        return await SupabaseClient.shared.upsert(table: "curriculum_edits", values: row, onConflict: "drill_id")
    }

    /// Hide a drill (rare). Players who haven't trained it stop seeing it in
    /// selection lists; their history and mastery are untouched.
    @discardableResult
    func hideDrill(_ drill: Drill) async -> Bool {
        let coachName = PlayerProfileStore.shared.displayName
        let row: [String: Any] = [
            "drill_id": drill.id,
            "kind": "hide",
            "payload": [String: Any](),
            "updated_by": coachName,
            "active": true
        ]
        return await SupabaseClient.shared.upsert(table: "curriculum_edits", values: row, onConflict: "drill_id")
    }

    /// Revert any active overlay on a drill back to the original (deactivates the row).
    @discardableResult
    func revertDrillEdit(drillID: String) async -> Bool {
        await SupabaseClient.shared.update(
            table: "curriculum_edits",
            values: ["active": false],
            match: [URLQueryItem(name: "drill_id", value: "eq.\(drillID)")]
        )
    }

    // MARK: - Ballon d'Or approvals

    /// Load every player awaiting Ballon d'Or review, with a stats summary each.
    func loadApprovals(context: ModelContext) async {
        if pendingApprovals.isEmpty { approvalsState = .loading }
        guard let rows = await SupabaseClient.shared.get(
            table: "player_profiles",
            query: [
                URLQueryItem(name: "is_example", value: "eq.false"),
                URLQueryItem(name: "ballon_dor_approved", value: "eq.false"),
                URLQueryItem(name: "ballon_dor_requested_at", value: "not.is.null"),
                URLQueryItem(name: "select", value: "id,display_name,kit_number,ballon_dor_requested_at"),
                URLQueryItem(name: "order", value: "ballon_dor_requested_at.asc")
            ]
        ) else {
            approvalsState = pendingApprovals.isEmpty ? .failed : .loaded
            return
        }

        let day30 = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        var result: [PendingApproval] = []
        for row in rows {
            guard let id = row["id"] as? String else { continue }
            let requestedAt = Self.parseDate(row["ballon_dor_requested_at"]) ?? Date()

            async let stateRowsAsync = SupabaseClient.shared.get(
                table: "player_state",
                query: [URLQueryItem(name: "player_id", value: "eq.\(id)"), URLQueryItem(name: "limit", value: "1")]
            )
            async let masteredAsync = SupabaseClient.shared.get(
                table: "player_progress",
                query: [
                    URLQueryItem(name: "player_id", value: "eq.\(id)"),
                    URLQueryItem(name: "is_mastered", value: "eq.true"),
                    URLQueryItem(name: "select", value: "drill_id")
                ]
            )
            async let logsAsync = SupabaseClient.shared.get(
                table: "session_logs",
                query: [
                    URLQueryItem(name: "user_id", value: "eq.\(id)"),
                    URLQueryItem(name: "select", value: "duration_sec,completed_at"),
                    URLQueryItem(name: "order", value: "completed_at.desc"),
                    URLQueryItem(name: "limit", value: "500")
                ]
            )

            let stateRow = (await stateRowsAsync)?.first
            let masteredRows = await masteredAsync
            let logRows = await logsAsync

            var minutes30 = 0
            for log in (logRows ?? []) {
                let date = Self.parseDate(log["completed_at"]) ?? Date()
                if date >= day30 { minutes30 += (log["duration_sec"] as? Int) ?? 0 }
            }

            result.append(PendingApproval(
                id: id,
                displayName: (row["display_name"] as? String) ?? "Player",
                kitNumber: row["kit_number"] as? String,
                requestedAt: requestedAt,
                xp: (stateRow?["xp"] as? Int) ?? 0,
                streak: (stateRow?["streak"] as? Int) ?? 0,
                mastered: (masteredRows ?? []).count,
                minutes30d: minutes30 / 60
            ))
        }
        pendingApprovals = result
        approvalsState = .loaded
    }

    /// Approve a player's Ballon d'Or invitation. Stamps the approval fields so
    /// the unlock syncs down to the player. Optimistic local removal.
    func approve(_ approval: PendingApproval) async {
        let coachName = PlayerProfileStore.shared.displayName
        let ok = await SupabaseClient.shared.update(
            table: "player_profiles",
            values: [
                "ballon_dor_approved": true,
                "ballon_dor_approved_at": SyncEngine.iso.string(from: Date()),
                "ballon_dor_approved_by": coachName
            ],
            match: [URLQueryItem(name: "id", value: "eq.\(approval.id)")]
        )
        guard ok else { return }
        pendingApprovals.removeAll { $0.id == approval.id }
        if let index = roster.firstIndex(where: { $0.id == approval.id }) {
            roster[index].ballonDorApproved = true
        }
    }

    /// Decline ("Not yet") — clears the request so the player resets to locked and
    /// can re-qualify later. Optimistic local removal.
    func decline(_ approval: PendingApproval) async {
        let ok = await SupabaseClient.shared.update(
            table: "player_profiles",
            values: ["ballon_dor_requested_at": NSNull()],
            match: [URLQueryItem(name: "id", value: "eq.\(approval.id)")]
        )
        guard ok else { return }
        pendingApprovals.removeAll { $0.id == approval.id }
    }

    // MARK: - Roster invites (join codes)

    /// Create a pending roster invite owned by this coach and return its share
    /// code. Optional pre-fill (name / kit / position) is stamped on the invite.
    /// Fails soft, returning nil when offline or not an active coach.
    func createRosterInvite(name: String, kit: String, position: String) async -> String? {
        guard let coachID = SupabaseAuth.shared.userID else { return nil }
        let code = Self.generateInviteCode()
        var row: [String: Any] = [
            "code": code,
            "coach_id": coachID,
            "status": "pending"
        ]
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !n.isEmpty { row["display_name"] = n }
        let k = kit.trimmingCharacters(in: .whitespacesAndNewlines)
        if !k.isEmpty { row["kit_number"] = k }
        let p = position.trimmingCharacters(in: .whitespacesAndNewlines)
        if !p.isEmpty { row["position"] = p }
        let ok = await SupabaseClient.shared.insert(table: "roster_invites", values: row)
        return ok ? code : nil
    }

    /// A 6-character invite code using unambiguous characters (no 0/O/1/I).
    private static func generateInviteCode() -> String {
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<6).compactMap { _ in alphabet.randomElement() })
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
        async let profileRowsAsync = SupabaseClient.shared.get(
            table: "player_profiles",
            query: [
                URLQueryItem(name: "id", value: "eq.\(pid)"),
                URLQueryItem(name: "select", value: "coach_focus"),
                URLQueryItem(name: "limit", value: "1")
            ]
        )

        let stateRows = await stateRowsAsync
        let progressRows = await progressRowsAsync
        let logRows = await logRowsAsync
        let combineRows = await combineRowsAsync
        let iqRows = await iqRowsAsync
        let profileRows = await profileRowsAsync

        // ANY failed fetch means this detail would be built from partial data.
        //
        // This used to only bail when all five came back nil, so a single
        // failure — say just the session logs timing out — produced
        // minutesAllTime 0, sessionCount 0, an empty history and a flat 8-week
        // chart, which was then cached and marked loaded. The coach saw "No
        // sessions logged yet" for an active child and re-entering the screen
        // couldn't fix it, because the cache short-circuits the reload. That
        // same zeroed record is what feeds the progress report PDF sent home to
        // parents, so a partial failure was being printed as fact.
        let anyFailed = stateRows == nil || progressRows == nil || logRows == nil
            || combineRows == nil || iqRows == nil || profileRows == nil
        if anyFailed {
            // Keep any good cached detail rather than replacing it with zeros.
            if detailCache[pid] == nil { detailState[pid] = .failed }
            else { detailState[pid] = .loaded }
            return
        }

        // player_state
        let state = stateRows?.first
        let xp = (state?["xp"] as? Int) ?? 0
        let streak = (state?["streak"] as? Int) ?? 0
        let streakPB = (state?["streak_pb"] as? Int) ?? 0
        let lastTrained = Self.parseDate(state?["last_trained_date"])
        let drillsCompleted = (state?["drills_completed"] as? Int) ?? 0

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

        // Baseline → latest · best per combine test (all recorded attempts).
        var valuesByTest: [String: [(value: Double, date: Date)]] = [:]
        for row in (combineRows ?? []) {
            guard let testID = row["test_id"] as? String else { continue }
            let value = (row["value"] as? Double) ?? Double((row["value"] as? String) ?? "") ?? 0
            let date = Self.parseDate(row["recorded_at"]) ?? now
            valuesByTest[testID, default: []].append((value, date))
        }
        var combineProgress: [CombineProgress] = []
        for (testID, entries) in valuesByTest {
            let sorted = entries.sorted { $0.date < $1.date }   // oldest → newest
            guard let baseline = sorted.first?.value, let latest = sorted.last?.value else { continue }
            let meta = testMeta[testID]
            let lower = meta?.lowerIsBetter ?? false
            let allValues = sorted.map(\.value)
            let best = lower ? (allValues.min() ?? latest) : (allValues.max() ?? latest)
            combineProgress.append(CombineProgress(
                testID: testID,
                label: meta?.name ?? testID,
                baseline: baseline,
                latest: latest,
                best: best,
                unit: meta?.unit ?? "",
                lowerIsBetter: lower
            ))
        }
        combineProgress.sort { $0.label < $1.label }

        // 8-week minutes series (Monday weeks, oldest → newest of the last 8).
        var weekCal = Calendar.current
        weekCal.firstWeekday = 2
        let startOfThisWeek = weekCal.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        var weekStarts: [Date] = []
        var weekBuckets: [Date: Int] = [:]
        for offset in stride(from: 7, through: 0, by: -1) {
            if let ws = weekCal.date(byAdding: .weekOfYear, value: -offset, to: startOfThisWeek) {
                weekStarts.append(ws)
                weekBuckets[ws] = 0
            }
        }
        let earliestWeek = weekStarts.first ?? startOfThisWeek
        for item in history where item.date >= earliestWeek {
            if let ws = weekCal.dateInterval(of: .weekOfYear, for: item.date)?.start {
                weekBuckets[ws, default: 0] += item.durationSec
            }
        }
        let weeklyMinutes = weekStarts.map {
            WeeklyMinutesPoint(weekStart: $0, minutes: (weekBuckets[$0] ?? 0) / 60)
        }

        let coachFocus = (profileRows?.first?["coach_focus"] as? String) ?? ""

        let detail = CoachPlayerDetail(
            xp: xp,
            streak: streak,
            streakPB: max(streakPB, streak),
            lastTrained: lastTrained,
            masteryByDiscipline: masteryByDiscipline,
            totalMastered: totalMastered,
            drillsCompleted: drillsCompleted,
            minutesAllTime: minutesAll / 60,
            minutes30d: minutes30 / 60,
            minutes7d: minutes7 / 60,
            sessionCount: (logRows ?? []).count,
            combineLatest: combineLatest,
            gameIQCompleted: (iqRows ?? []).count,
            history: history,
            weeklyMinutes: weeklyMinutes,
            combineProgress: combineProgress,
            coachFocus: coachFocus
        )
        detailCache[pid] = detail
        detailState[pid] = .loaded
    }

    // MARK: - Coach focus + notes

    /// Save the coach-authored training focus for a player. PATCHes
    /// player_profiles.coach_focus and updates the cached detail locally.
    /// Returns false when the write failed, so the caller doesn't show "Saved".
    @discardableResult
    func saveCoachFocus(_ text: String, for playerID: String) async -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let ok = await SupabaseClient.shared.update(
            table: "player_profiles",
            values: ["coach_focus": trimmed],
            match: [URLQueryItem(name: "id", value: "eq.\(playerID)")]
        )
        guard ok else { return false }
        if var detail = detailCache[playerID] {
            detail.coachFocus = trimmed
            detailCache[playerID] = detail
        }
        return true
    }

    /// Load all monthly coach notes for a player (newest month first).
    func loadNotes(for playerID: String) async {
        guard let rows = await SupabaseClient.shared.get(
            table: "coach_notes",
            query: [
                URLQueryItem(name: "player_user_id", value: "eq.\(playerID)"),
                URLQueryItem(name: "order", value: "month.desc")
            ]
        ) else { return }
        notesCache[playerID] = rows.compactMap { row in
            guard let id = row["id"] as? String,
                  let month = row["month"] as? String else { return nil }
            return CoachNote(
                id: id,
                month: month,
                body: (row["body"] as? String) ?? "",
                updatedAt: Self.parseDate(row["updated_at"]) ?? Date()
            )
        }
    }

    /// Upsert a month's coach note (one row per month per player). Updates an
    /// existing row when present, otherwise inserts, then reloads the cache.
    /// Returns false when the write failed. This ignored the result entirely,
    /// so a coach writing a month's evaluation on a bad connection saw "Saved",
    /// navigated away, and the note was gone.
    @discardableResult
    func saveNote(month: String, text: String, for playerID: String) async -> Bool {
        guard let coachID = SupabaseAuth.shared.userID else { return false }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let ok: Bool
        if let existing = notesCache[playerID]?.first(where: { $0.month == month }) {
            ok = await SupabaseClient.shared.update(
                table: "coach_notes",
                values: ["body": trimmed, "updated_at": SyncEngine.iso.string(from: Date())],
                match: [URLQueryItem(name: "id", value: "eq.\(existing.id)")]
            )
        } else {
            ok = await SupabaseClient.shared.insert(
                table: "coach_notes",
                values: [
                    "player_user_id": playerID,
                    "coach_user_id": coachID,
                    "month": month,
                    "body": trimmed
                ]
            )
        }
        guard ok else { return false }
        await loadNotes(for: playerID)
        return true
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

    /// How many rows per dormant player to scan when back-filling "last
    /// active". They have nothing in the last 7 days by definition, so their
    /// newest rows are all older and a handful each is plenty.
    private static let lastActiveScan = 5

    /// Split ids into batches small enough that `in.(...)` stays inside a
    /// sane URL length. 100 uuids is roughly 3.7 KB of query string.
    private static func chunked(_ ids: [String], size: Int = 100) -> [[String]] {
        guard !ids.isEmpty else { return [] }
        return stride(from: 0, to: ids.count, by: size).map {
            Array(ids[$0 ..< min($0 + size, ids.count)])
        }
    }

    /// Parse a Postgres date / timestamptz value into a Date.
    private static func parseDate(_ value: Any?) -> Date? {
        guard let string = value as? String else { return nil }
        if let date = ISO8601DateFormatter.withFractional.date(from: string) { return date }
        if let date = ISO8601DateFormatter().date(from: string) { return date }
        return SyncEngine.date(from: string)   // "yyyy-MM-dd" (last_trained_date)
    }
}
