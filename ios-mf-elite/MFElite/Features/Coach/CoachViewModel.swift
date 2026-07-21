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
    /// When the overview + roster last finished loading, for the "updated" label.
    var lastLoadedAt: Date?

    /// Per-player detail cache + load state, keyed by player id.
    var detailState: [String: CoachLoadState] = [:]
    var detailCache: [String: CoachPlayerDetail] = [:]

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
        var sessionsByUser: [String: Int] = [:]
        for row in logRows {
            guard let uid = row["user_id"] as? String,
                  let date = Self.parseDate(row["completed_at"]) else { continue }
            if lastActive[uid] == nil { lastActive[uid] = date }   // desc order → first is newest
            if date >= weekAgo {
                activeUsers.insert(uid)
                sessionsThisWeek += 1
                minutesThisWeek += (row["duration_sec"] as? Int) ?? 0
                sessionsByUser[uid, default: 0] += 1
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

    /// Publish a new featured workout to the team. Fails soft.
    func publishWorkout(title: String, note: String, drillIDs: [String]) async {
        guard let createdBy = SupabaseAuth.shared.userID else { return }
        let coachName = PlayerProfileStore.shared.displayName
        let row: [String: Any] = [
            "title": title,
            "note": note,
            "drill_ids": drillIDs,
            "coach_name": coachName,
            "active": true,
            "created_by": createdBy
        ]
        await SupabaseClient.shared.insert(table: "coach_workouts", values: row)
        await loadPublishedWorkouts()
    }

    /// Toggle a published workout active/inactive. Inactive workouts disappear
    /// from players' Today card; nothing else changes.
    func setWorkoutActive(_ workout: CoachPublishedWorkout, active: Bool) async {
        // Optimistic local update so the toggle feels instant.
        if let index = publishedWorkouts.firstIndex(where: { $0.id == workout.id }) {
            publishedWorkouts[index].active = active
        }
        await SupabaseClient.shared.update(
            table: "coach_workouts",
            values: ["active": active],
            match: [URLQueryItem(name: "id", value: "eq.\(workout.id)")]
        )
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
    /// caller can share to a team chat. Fails soft.
    @discardableResult
    func sendAnnouncement(title: String, body: String) async -> String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return "" }
        let row: [String: Any] = [
            "title": trimmedTitle,
            "body": trimmedBody,
            "active": true
        ]
        await SupabaseClient.shared.insert(table: "announcements", values: row)
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
        guard !payload.isEmpty else { return false }
        let coachName = PlayerProfileStore.shared.displayName
        let row: [String: Any] = [
            "drill_id": original.id,
            "kind": "edit",
            "payload": payload,
            "updated_by": coachName,
            "active": true
        ]
        await SupabaseClient.shared.upsert(table: "curriculum_edits", values: row, onConflict: "drill_id")
        return true
    }

    /// Publish a brand-new coach-authored drill into a category/level. Generates a
    /// stable "COACH-…" id so it never collides with the bundled curriculum.
    func publishNewDrill(drillID: String, categoryID: String, levelNumber: Int, fields: DrillEditFields) async {
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
        await SupabaseClient.shared.upsert(table: "curriculum_edits", values: row, onConflict: "drill_id")
    }

    /// Hide a drill (rare). Players who haven't trained it stop seeing it in
    /// selection lists; their history and mastery are untouched.
    func hideDrill(_ drill: Drill) async {
        let coachName = PlayerProfileStore.shared.displayName
        let row: [String: Any] = [
            "drill_id": drill.id,
            "kind": "hide",
            "payload": [String: Any](),
            "updated_by": coachName,
            "active": true
        ]
        await SupabaseClient.shared.upsert(table: "curriculum_edits", values: row, onConflict: "drill_id")
    }

    /// Revert any active overlay on a drill back to the original (deactivates the row).
    func revertDrillEdit(drillID: String) async {
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
