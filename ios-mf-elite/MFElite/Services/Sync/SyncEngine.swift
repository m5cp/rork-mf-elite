//
//  SyncEngine.swift
//  MFElite
//
//  Local-first background mirror. SwiftData stays the single source of truth the
//  UI reads; the SyncEngine pushes a durable outbox of mutations up to Supabase
//  and, on launch / restore, pulls remote state back down. Nothing here ever
//  blocks the UI: every code path is fire-and-forget and fails soft. The app is
//  100% functional offline and signed out.
//
//  Outbox: each local mutation that must reach Supabase is written as a
//  `PendingOp` (FIFO). Ops are coalesced by natural key so the queue stays lean,
//  and flushed when online + signed in. Failures stay queued with exponential
//  backoff. The player_id is injected from the live session at flush time, so a
//  queued op stays valid across sign-ins.
//

import Foundation
import SwiftData
import Network
import CryptoKit
import Observation

@Observable
@MainActor
final class SyncEngine {
    static let shared = SyncEngine()

    /// Number of operations still waiting to reach the server.
    private(set) var pendingCount: Int = 0
    /// When the outbox was last fully drained (a successful push happened).
    private(set) var lastSyncedAt: Date?
    /// Live network reachability, from NWPathMonitor.
    private(set) var isOnline: Bool = true

    private var context: ModelContext?
    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "app.rork.mfelite.sync.monitor")

    private var isFlushing = false
    /// In-memory backoff gate; flushing is skipped until this time passes.
    private var backoffUntil: Date?

    private enum DefaultsKeys {
        static let lastSynced = "MF_SYNC_LAST_SYNCED"
        static let backfillDone = "MF_SYNC_BACKFILL_DONE"
    }

    /// Tables we own and their upsert conflict keys (owner column injected at flush).
    private static let conflictKeys: [String: String] = [
        "player_state": "player_id",
        "player_progress": "player_id,drill_id",
        "session_logs": "id",
        "combine_results": "id",
        "drill_notes": "user_id,drill_id",
        "custom_workouts": "id",
        "gameiq_completions": "user_id,lesson_id",
        "player_profiles": "id"
    ]

    /// Tables whose owner column is `user_id` rather than `player_id`. The signed-in
    /// UUID is injected into the right column at flush time.
    private static let userIDTables: Set<String> = [
        "session_logs", "combine_results", "drill_notes",
        "custom_workouts", "gameiq_completions"
    ]

    /// The owner column for a table: `id` for player_profiles (PK == user UUID),
    /// `user_id` for the user-data tables, else `player_id`.
    private static func ownerColumn(for table: String) -> String {
        if table == "player_profiles" { return "id" }
        return userIDTables.contains(table) ? "user_id" : "player_id"
    }

    private init() {
        let epoch = UserDefaults.standard.double(forKey: DefaultsKeys.lastSynced)
        if epoch > 0 { lastSyncedAt = Date(timeIntervalSince1970: epoch) }
    }

    // MARK: - Lifecycle

    /// Wire up the engine with the app's main context and start watching the
    /// network. Safe to call once at launch.
    func configure(context: ModelContext) {
        self.context = context
        refreshPendingCount()

        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor in
                guard let self else { return }
                let wasOffline = !self.isOnline
                self.isOnline = online
                // Network restored → flush.
                if online && wasOffline { self.flush() }
            }
        }
        monitor.start(queue: monitorQueue)

        // Initial pull + push for an already-signed-in session.
        pullPlayerStateOnLaunch()
        pullBallonDor()
        flush()
    }

    /// Called when the app returns to the foreground.
    func onForeground() {
        refreshPendingCount()
        pullPlayerStateOnLaunch()
        pullBallonDor()
        flush()
    }

    /// Called right after a successful sign-in: push queued work and check
    /// whether the cloud has more progress to restore onto this device.
    func handleSignIn() {
        backoffUntil = nil
        flush()
        pullBallonDor()
        if let context { SyncRestore.shared.checkForRestore(context: context) }
        maybeBackfill()
    }

    /// On the first sign-in for this device-account, enqueue all existing local
    /// history so an offline-trained player uploads everything. Runs once (a flag
    /// is reset on sign-out) and only when there is real local data to upload.
    private func maybeBackfill() {
        guard let context else { return }
        guard !UserDefaults.standard.bool(forKey: DefaultsKeys.backfillDone) else { return }
        let logCount = (try? context.fetchCount(FetchDescriptor<SessionLogEntry>())) ?? 0
        let combineCount = (try? context.fetchCount(FetchDescriptor<CombineResult>())) ?? 0
        let player = try? context.fetch(FetchDescriptor<PlayerState>()).first
        let hasHistory = logCount > 0 || combineCount > 0 || (player?.xp ?? 0) > 0
        guard hasHistory else { return }
        UserDefaults.standard.set(true, forKey: DefaultsKeys.backfillDone)
        backfillAllLocalData()
    }

    /// Called on sign-out: drop the outbox so a different account never inherits
    /// this session's queued mutations. Local SwiftData is untouched.
    func handleSignOut() {
        guard let context else { return }
        let ops = (try? context.fetch(FetchDescriptor<PendingOp>())) ?? []
        for op in ops { context.delete(op) }
        try? context.save()
        backoffUntil = nil
        isBackfilling = false
        UserDefaults.standard.removeObject(forKey: DefaultsKeys.backfillDone)
        refreshPendingCount()
    }

    /// Permanently wipe all locally-stored user history and progress (used by
    /// account deletion). The seeded curriculum/content models stay intact; the
    /// player's progress, logs, notes, custom workouts, and queued ops are
    /// removed, and PlayerState is reset to zero so the app stays consistent.
    func wipeLocalData(context: ModelContext) {
        deleteAll(SessionLogEntry.self, context: context)
        deleteAll(CombineResult.self, context: context)
        deleteAll(DrillNote.self, context: context)
        deleteAll(CustomWorkout.self, context: context)
        deleteAll(ProgramEnrollment.self, context: context)
        deleteAll(DrillProgress.self, context: context)
        deleteAll(PendingOp.self, context: context)

        // Reset the single PlayerState row rather than deleting it, so the rest
        // of the app always has a valid progression record to read.
        if let player = try? context.fetch(FetchDescriptor<PlayerState>()).first {
            player.xp = 0
            player.streak = 0
            player.freezesRemaining = 0
            player.streakPB = 0
            player.lastTrainedDate = nil
        }
        // Clear Game IQ lesson completions (seeded content stays, progress clears).
        let lessons = (try? context.fetch(FetchDescriptor<GameIQLesson>())) ?? []
        for lesson in lessons { lesson.completedAt = nil }
        try? context.save()

        // Reset sync bookkeeping so a fresh sign-in starts clean.
        lastSyncedAt = nil
        backoffUntil = nil
        isBackfilling = false
        UserDefaults.standard.removeObject(forKey: DefaultsKeys.lastSynced)
        UserDefaults.standard.removeObject(forKey: DefaultsKeys.backfillDone)
        refreshPendingCount()
        WidgetBridge.refresh(context: context)
    }

    private func deleteAll<T: PersistentModel>(_ type: T.Type, context: ModelContext) {
        let items = (try? context.fetch(FetchDescriptor<T>())) ?? []
        for item in items { context.delete(item) }
    }

    /// Force a flush now (used by the Settings "Sync now" action).
    func syncNow() {
        backoffUntil = nil
        pullPlayerStateOnLaunch()
        pullBallonDor()
        flush()
    }

    /// Reconcile the Ballon d'Or invitation state from the server (approval /
    /// decline). Reads the local XP so a declined request can require fresh
    /// progress before re-requesting.
    func pullBallonDor() {
        guard SupabaseAuth.shared.isSignedIn, let context else { return }
        let xp = (try? context.fetch(FetchDescriptor<PlayerState>()).first?.xp) ?? 0
        Task { await BallonDorStore.shared.pullFromRemote(currentXP: xp) }
    }

    // MARK: - Enqueue helpers (public API used by mutation sites)

    /// Enqueue the player's current progression state for upsert. Coalesces with
    /// any pending player_state op. Also maintains the personal-best streak.
    func enqueuePlayerState(_ player: PlayerState) {
        player.streakPB = max(player.streakPB, player.streak)

        var row: [String: Any] = [
            "xp": player.xp,
            "streak": player.streak,
            "freezes_remaining": player.freezesRemaining,
            "streak_pb": player.streakPB
        ]
        if let date = player.lastTrainedDate {
            row["last_trained_date"] = Self.dateString(date)
        }
        enqueueUpsert(table: "player_state", row: row, coalesceKey: "*")
    }

    /// Enqueue a single drill's progress for upsert, keyed by the deterministic
    /// drill UUID derived from the local string id.
    func enqueueDrillProgress(_ progress: DrillProgress) {
        var row: [String: Any] = [
            "drill_id": Self.drillUUID(from: progress.drillID),
            "passes_logged": progress.passesLogged,
            "is_mastered": progress.isMastered
        ]
        if let date = progress.lastLoggedAt {
            row["last_logged_at"] = ISO8601DateFormatter().string(from: date)
        }
        enqueueUpsert(table: "player_progress", row: row, coalesceKey: progress.drillID)
    }

    /// Enqueue the player's Ballon d'Or invitation request. A partial upsert to
    /// player_profiles (merge-duplicates), durable through the outbox so it still
    /// reaches the server if the player was offline when they qualified.
    func enqueueBallonDorRequest(requestedAt: Date) {
        let row: [String: Any] = ["ballon_dor_requested_at": Self.iso.string(from: requestedAt)]
        enqueueUpsert(table: "player_profiles", row: row, coalesceKey: "*")
    }

    /// Convenience: snapshot the whole player after a logging pass — the player
    /// state plus every drill that was just touched.
    func syncAfterLogging(player: PlayerState?, touchedDrillIDs: [String], context: ModelContext) {
        if let player { enqueuePlayerState(player) }
        let ids = Set(touchedDrillIDs)
        guard !ids.isEmpty else { return }
        let all = (try? context.fetch(FetchDescriptor<DrillProgress>())) ?? []
        for progress in all where ids.contains(progress.drillID) {
            enqueueDrillProgress(progress)
        }
    }

    // MARK: - User-data table enqueue helpers

    /// Enqueue a session log upsert (same UUID = idempotent). Append-only on the
    /// server: rows are never deleted. Called on creation and again if a felt
    /// rating / reflection is attached later (a same-id upsert just fills fields).
    func enqueueSessionLog(_ entry: SessionLogEntry) {
        var row: [String: Any] = [
            "id": entry.id.uuidString,
            "completed_at": Self.iso.string(from: entry.completedAt),
            "drill_id": entry.drillID,
            "drill_title": entry.drillTitle,
            "discipline_id": entry.disciplineID,
            "discipline_name": entry.disciplineName,
            "category_id": entry.categoryID,
            "category_name": entry.categoryName,
            "level_number": entry.levelNumber,
            "duration_sec": entry.durationSec,
            "sets_completed": entry.setsCompleted,
            "sets_skipped": entry.setsSkipped,
            "completed_fully": entry.completedFully,
            "source": entry.source,
            "xp_earned": entry.xpEarned
        ]
        if let v = entry.sourceName { row["source_name"] = v }
        if let v = entry.feltRating { row["felt_rating"] = v }
        if let v = entry.reflection { row["reflection"] = v }
        if let v = entry.journalResponse { row["journal_response"] = v }
        enqueueGeneric(table: "session_logs", opType: "upsert", row: row,
                       coalesce: ["id": entry.id.uuidString])
    }

    /// Enqueue a combine result upsert (same UUID). Append-only on the server.
    func enqueueCombineResult(_ result: CombineResult) {
        let row: [String: Any] = [
            "id": result.id.uuidString,
            "test_id": result.testID,
            "value": result.value,
            "recorded_at": Self.iso.string(from: result.recordedAt)
        ]
        enqueueGeneric(table: "combine_results", opType: "upsert", row: row,
                       coalesce: ["id": result.id.uuidString])
    }

    /// Enqueue a drill note upsert keyed (user_id, drill_id). Empty notes delete.
    func enqueueDrillNote(drillID: String, text: String, updatedAt: Date) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            enqueueDrillNoteDeletion(drillID: drillID)
            return
        }
        let row: [String: Any] = [
            "drill_id": drillID,
            "text": trimmed,
            "updated_at": Self.iso.string(from: updatedAt)
        ]
        enqueueGeneric(table: "drill_notes", opType: "upsert", row: row,
                       coalesce: ["drill_id": drillID])
    }

    /// Enqueue deletion of a drill note (saving an empty note).
    func enqueueDrillNoteDeletion(drillID: String) {
        enqueueGeneric(table: "drill_notes", opType: "delete",
                       row: ["drill_id": drillID], coalesce: ["drill_id": drillID])
    }

    /// Enqueue a custom workout upsert keyed by id (create or edit).
    func enqueueCustomWorkout(_ workout: CustomWorkout) {
        let row: [String: Any] = [
            "id": workout.id.uuidString,
            "name": workout.title,
            "drill_ids": workout.drillIDs,
            "is_shared_import": workout.isShared,
            "updated_at": Self.iso.string(from: workout.updatedAt)
        ]
        enqueueGeneric(table: "custom_workouts", opType: "upsert", row: row,
                       coalesce: ["id": workout.id.uuidString])
    }

    /// Enqueue deletion of a custom workout by id.
    func enqueueCustomWorkoutDeletion(id: UUID) {
        enqueueGeneric(table: "custom_workouts", opType: "delete",
                       row: ["id": id.uuidString], coalesce: ["id": id.uuidString])
    }

    /// Enqueue a Game IQ lesson completion keyed (user_id, lesson_id).
    func enqueueGameIQCompletion(lessonID: String, completedAt: Date) {
        let row: [String: Any] = [
            "lesson_id": lessonID,
            "completed_at": Self.iso.string(from: completedAt)
        ]
        enqueueGeneric(table: "gameiq_completions", opType: "upsert", row: row,
                       coalesce: ["lesson_id": lessonID])
    }

    // MARK: - Outbox writes

    private func enqueueUpsert(table: String, row: [String: Any], coalesceKey: String) {
        guard let context else { return }
        guard let data = try? JSONSerialization.data(withJSONObject: row) else { return }

        coalesce(table: table, key: coalesceKey, context: context)

        context.insert(PendingOp(table: table, opType: "upsert", payloadJSON: data))
        try? context.save()
        refreshPendingCount()
        flush()
    }

    /// Generic outbox write for the user-data tables. Coalesces any pending op for
    /// the same table whose payload matches every key/value in `coalesce`, so the
    /// newest idempotent snapshot supersedes older ones.
    private func enqueueGeneric(table: String, opType: String, row: [String: Any], coalesce: [String: String]) {
        guard let context else { return }
        guard let data = try? JSONSerialization.data(withJSONObject: row) else { return }
        coalesceMatching(table: table, match: coalesce, context: context)
        context.insert(PendingOp(table: table, opType: opType, payloadJSON: data))
        try? context.save()
        refreshPendingCount()
        flush()
    }

    /// Remove superseded pending ops for the same natural key so the queue stays
    /// small (every op is a full idempotent snapshot, so older ones are safe to
    /// drop). `key == "*"` coalesces all ops for the table (single-row tables).
    private func coalesce(table: String, key: String, context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<PendingOp>())) ?? []
        for op in existing where op.table == table && op.opType == "upsert" {
            if key == "*" {
                context.delete(op)
            } else if let dict = try? JSONSerialization.jsonObject(with: op.payloadJSON) as? [String: Any],
                      let drillID = dict["drill_id"] as? String,
                      drillID == Self.drillUUID(from: key) {
                context.delete(op)
            }
        }
    }

    /// Delete pending ops for `table` whose payload matches all `match` columns.
    private func coalesceMatching(table: String, match: [String: String], context: ModelContext) {
        guard !match.isEmpty else { return }
        let existing = (try? context.fetch(FetchDescriptor<PendingOp>())) ?? []
        for op in existing where op.table == table {
            guard let dict = try? JSONSerialization.jsonObject(with: op.payloadJSON) as? [String: Any] else { continue }
            let matches = match.allSatisfy { key, value in
                guard let raw = dict[key] else { return false }
                return "\(raw)" == value
            }
            if matches { context.delete(op) }
        }
    }

    // MARK: - Flush

    /// Drain the outbox FIFO. No-op unless online, signed in, and past any
    /// active backoff window. Never throws into the UI.
    func flush() {
        guard !isFlushing else { return }
        guard isOnline, SupabaseAuth.shared.isSignedIn else { return }
        guard let context, let playerID = SupabaseAuth.shared.userID else { return }
        if let backoffUntil, Date() < backoffUntil { scheduleBackoffRetry(); return }

        isFlushing = true
        Task {
            defer {
                isFlushing = false
                refreshPendingCount()
            }
            var descriptor = FetchDescriptor<PendingOp>(sortBy: [SortDescriptor(\.createdAt, order: .forward)])
            descriptor.fetchLimit = 200
            let ops = (try? context.fetch(descriptor)) ?? []
            guard !ops.isEmpty else { return }

            for op in ops {
                guard SupabaseAuth.shared.isSignedIn, isOnline else { break }
                guard var payload = try? JSONSerialization.jsonObject(with: op.payloadJSON) as? [String: Any] else {
                    // Corrupt payload — drop it rather than blocking the queue.
                    context.delete(op)
                    continue
                }
                payload[Self.ownerColumn(for: op.table)] = playerID

                let success: Bool
                if op.opType == "delete" {
                    let match = payload.compactMapValues { "\($0)" }
                    success = await SupabaseClient.shared.delete(table: op.table, match: match)
                } else {
                    let onConflict = Self.conflictKeys[op.table]
                    success = await SupabaseClient.shared.upsert(table: op.table, values: payload, onConflict: onConflict)
                }

                if success {
                    context.delete(op)
                    try? context.save()
                    backoffUntil = nil
                    markSynced()
                } else {
                    op.attempts += 1
                    try? context.save()
                    applyBackoff(attempts: op.attempts)
                    break
                }
            }
        }
    }

    private func applyBackoff(attempts: Int) {
        // 2^attempts seconds, capped at 5 minutes.
        let delay = min(pow(2.0, Double(attempts)), 300)
        backoffUntil = Date().addingTimeInterval(delay)
        scheduleBackoffRetry()
    }

    private func scheduleBackoffRetry() {
        guard let backoffUntil else { return }
        let delay = max(1, backoffUntil.timeIntervalSinceNow)
        Task {
            try? await Task.sleep(for: .seconds(delay))
            flush()
        }
    }

    private func markSynced() {
        let now = Date()
        lastSyncedAt = now
        UserDefaults.standard.set(now.timeIntervalSince1970, forKey: DefaultsKeys.lastSynced)
    }

    private func refreshPendingCount() {
        guard let context else { pendingCount = 0; return }
        pendingCount = (try? context.fetchCount(FetchDescriptor<PendingOp>())) ?? 0
    }

    // MARK: - Pull (launch reconcile)

    /// On launch when signed in, pull remote player_state once; if it looks newer
    /// than local, apply it. Never overwrites newer local progress.
    func pullPlayerStateOnLaunch() {
        guard SupabaseAuth.shared.isSignedIn, let context else { return }
        Task {
            guard let remote = await fetchRemotePlayerState() else { return }
            guard let player = try? context.fetch(FetchDescriptor<PlayerState>()).first else { return }
            // Remote wins only when it is strictly ahead (more XP) — a simple,
            // safe "newer" heuristic that never regresses local progress.
            if remote.xp > player.xp {
                apply(remote, to: player, context: context)
            }
        }
    }

    /// Fetch the signed-in player's remote state row, if any.
    func fetchRemotePlayerState() async -> RemotePlayerState? {
        guard let playerID = SupabaseAuth.shared.userID else { return nil }
        let rows = await SupabaseClient.shared.get(
            table: "player_state",
            query: [
                URLQueryItem(name: "player_id", value: "eq.\(playerID)"),
                URLQueryItem(name: "limit", value: "1")
            ]
        )
        guard let row = rows?.first else { return nil }
        return RemotePlayerState(row: row)
    }

    private func apply(_ remote: RemotePlayerState, to player: PlayerState, context: ModelContext) {
        player.xp = remote.xp
        player.streak = remote.streak
        player.freezesRemaining = remote.freezesRemaining
        player.streakPB = max(remote.streakPB, remote.streak)
        if let dateString = remote.lastTrainedDate {
            player.lastTrainedDate = Self.date(from: dateString)
        }
        try? context.save()
        WidgetBridge.refresh(context: context)
    }

    // MARK: - Restore (fresh install)

    /// Pull remote player_state + player_progress and apply them locally,
    /// replacing the fresh local state. Used by the "Restore your progress" flow.
    func restoreFromRemote() async {
        guard SupabaseAuth.shared.isSignedIn, let context, let playerID = SupabaseAuth.shared.userID else { return }

        if let remote = await fetchRemotePlayerState() {
            let player = (try? context.fetch(FetchDescriptor<PlayerState>()).first)
                ?? {
                    let new = PlayerState(playerID: playerID)
                    context.insert(new)
                    return new
                }()
            apply(remote, to: player, context: context)
        }

        // Pull all drill progress rows and reconcile against the local
        // drill-id ↔ UUID mapping.
        let rows = await SupabaseClient.shared.get(
            table: "player_progress",
            query: [URLQueryItem(name: "player_id", value: "eq.\(playerID)")]
        ) ?? []
        guard !rows.isEmpty else { return }

        let localDrills = (try? context.fetch(FetchDescriptor<Drill>())) ?? []
        let uuidToLocalID = Dictionary(localDrills.map { (Self.drillUUID(from: $0.id), $0.id) },
                                       uniquingKeysWith: { a, _ in a })
        let existing = (try? context.fetch(FetchDescriptor<DrillProgress>())) ?? []
        var byID = Dictionary(existing.map { ($0.drillID, $0) }, uniquingKeysWith: { a, _ in a })

        for row in rows {
            guard let remoteUUID = row["drill_id"] as? String,
                  let localID = uuidToLocalID[remoteUUID] else { continue }
            let passes = (row["passes_logged"] as? Int) ?? 0
            let mastered = (row["is_mastered"] as? Bool) ?? false
            let loggedAt = (row["last_logged_at"] as? String).flatMap { ISO8601DateFormatter().date(from: $0) }

            if let local = byID[localID] {
                local.passesLogged = max(local.passesLogged, passes)
                local.isMastered = local.isMastered || mastered
                if let loggedAt { local.lastLoggedAt = loggedAt }
            } else {
                let progress = DrillProgress(
                    drillID: localID,
                    passesLogged: passes,
                    lastLoggedAt: loggedAt,
                    isMastered: mastered
                )
                context.insert(progress)
                byID[localID] = progress
            }
        }
        try? context.save()
        WidgetBridge.refresh(context: context)

        // Pull-merge the five user-data tables alongside core progress.
        await restoreUserDataFromRemote(context: context)
        markSynced()
    }

    // MARK: - Deterministic drill UUID (UUIDv5-style)

    /// Maps a local string drill id (e.g. "TEC-A-L2-05") to a stable UUID so it
    /// satisfies the remote `player_progress.drill_id uuid` column. Deterministic
    /// (UUIDv5 over a fixed namespace), so every device derives the same value.
    static func drillUUID(from drillID: String) -> String {
        // Fixed namespace UUID for MF Elite drill ids.
        let namespace: [UInt8] = [
            0x6b, 0xa7, 0xb8, 0x11, 0x9d, 0xad, 0x11, 0xd1,
            0x80, 0xb4, 0x00, 0xc0, 0x4f, 0xd4, 0x30, 0xc8
        ]
        var data = Data(namespace)
        data.append(Data(drillID.utf8))
        var digest = Array(Insecure.SHA1.hash(data: data).prefix(16))
        digest[6] = (digest[6] & 0x0F) | 0x50          // version 5
        digest[8] = (digest[8] & 0x3F) | 0x80          // RFC 4122 variant
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        let s = Array(hex)
        return "\(String(s[0..<8]))-\(String(s[8..<12]))-\(String(s[12..<16]))-\(String(s[16..<20]))-\(String(s[20..<32]))"
    }

    // MARK: - Date helpers

    private static let dateOnly: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func dateString(_ date: Date) -> String { dateOnly.string(from: date) }
    static func date(from string: String) -> Date? { dateOnly.date(from: string) }

    /// Shared ISO-8601 formatter for timestamp columns.
    static let iso = ISO8601DateFormatter()

    private static func parseISO(_ value: Any?) -> Date? {
        guard let s = value as? String else { return nil }
        return iso.date(from: s) ?? ISO8601DateFormatter.withFractional.date(from: s)
    }

    // MARK: - Backfill (first sign-in with existing local history)

    /// Whether the one-time history backfill is currently draining.
    private(set) var isBackfilling: Bool = false

    /// Enqueue ALL existing local user data so an offline-trained player uploads
    /// their full history on first sign-in. Idempotent: every op upserts by a
    /// stable key, so re-running never duplicates remote rows.
    func backfillAllLocalData() {
        guard SupabaseAuth.shared.isSignedIn, let context else { return }
        isBackfilling = true

        let logs = (try? context.fetch(FetchDescriptor<SessionLogEntry>())) ?? []
        for entry in logs { enqueueSessionLog(entry) }

        let combine = (try? context.fetch(FetchDescriptor<CombineResult>())) ?? []
        for result in combine { enqueueCombineResult(result) }

        let notes = (try? context.fetch(FetchDescriptor<DrillNote>())) ?? []
        for note in notes {
            enqueueDrillNote(drillID: note.drillID, text: note.text, updatedAt: note.updatedAt)
        }

        let workouts = (try? context.fetch(FetchDescriptor<CustomWorkout>())) ?? []
        for workout in workouts { enqueueCustomWorkout(workout) }

        let lessons = (try? context.fetch(FetchDescriptor<GameIQLesson>())) ?? []
        for lesson in lessons where lesson.completedAt != nil {
            enqueueGameIQCompletion(lessonID: lesson.id, completedAt: lesson.completedAt!)
        }

        // Also snapshot player state + every touched drill so nothing is missed.
        if let player = try? context.fetch(FetchDescriptor<PlayerState>()).first {
            enqueuePlayerState(player)
        }
        let progress = (try? context.fetch(FetchDescriptor<DrillProgress>())) ?? []
        for p in progress where p.passesLogged > 0 || p.isMastered { enqueueDrillProgress(p) }

        refreshPendingCount()
        flush()
        // Clear the banner once the outbox finishes draining.
        scheduleBackfillCompletionCheck()
    }

    private func scheduleBackfillCompletionCheck() {
        Task {
            // Poll until the queue drains (or 2 minutes pass), then drop the banner.
            for _ in 0..<60 {
                try? await Task.sleep(for: .seconds(2))
                if pendingCount == 0 { break }
            }
            isBackfilling = false
        }
    }

    // MARK: - Pull-merge for user-data tables (restore)

    /// Pull the five user-data tables and merge them into local SwiftData. Called
    /// by the restore flow after player_state + player_progress are restored.
    func restoreUserDataFromRemote(context: ModelContext) async {
        guard let userID = SupabaseAuth.shared.userID else { return }
        await mergeSessionLogs(userID: userID, context: context)
        await mergeCombineResults(userID: userID, context: context)
        await mergeDrillNotes(userID: userID, context: context)
        await mergeCustomWorkouts(userID: userID, context: context)
        await mergeGameIQCompletions(userID: userID, context: context)
        try? context.save()
        WidgetBridge.refresh(context: context)
    }

    /// Union by id — append-only, no conflicts possible.
    private func mergeSessionLogs(userID: String, context: ModelContext) async {
        let rows = await SupabaseClient.shared.get(
            table: "session_logs",
            query: [URLQueryItem(name: "user_id", value: "eq.\(userID)")]
        ) ?? []
        guard !rows.isEmpty else { return }
        let existing = (try? context.fetch(FetchDescriptor<SessionLogEntry>())) ?? []
        let knownIDs = Set(existing.map(\.id))
        for row in rows {
            guard let idStr = row["id"] as? String, let id = UUID(uuidString: idStr),
                  !knownIDs.contains(id) else { continue }
            let entry = SessionLogEntry(
                id: id,
                completedAt: Self.parseISO(row["completed_at"]) ?? Date(),
                drillID: (row["drill_id"] as? String) ?? "",
                drillTitle: (row["drill_title"] as? String) ?? "",
                disciplineID: (row["discipline_id"] as? String) ?? "",
                disciplineName: (row["discipline_name"] as? String) ?? "",
                categoryID: (row["category_id"] as? String) ?? "",
                categoryName: (row["category_name"] as? String) ?? "",
                levelNumber: (row["level_number"] as? Int) ?? 1,
                durationSec: (row["duration_sec"] as? Int) ?? 0,
                setsCompleted: (row["sets_completed"] as? Int) ?? 1,
                source: (row["source"] as? String) ?? SessionSource.single.rawValue,
                sourceName: row["source_name"] as? String,
                xpEarned: (row["xp_earned"] as? Int) ?? 0,
                journalResponse: row["journal_response"] as? String,
                feltRating: row["felt_rating"] as? Int,
                reflection: row["reflection"] as? String,
                setsSkipped: (row["sets_skipped"] as? Int) ?? 0,
                completedFully: (row["completed_fully"] as? Bool) ?? true
            )
            context.insert(entry)
        }
    }

    /// Union by id — append-only.
    private func mergeCombineResults(userID: String, context: ModelContext) async {
        let rows = await SupabaseClient.shared.get(
            table: "combine_results",
            query: [URLQueryItem(name: "user_id", value: "eq.\(userID)")]
        ) ?? []
        guard !rows.isEmpty else { return }
        let existing = (try? context.fetch(FetchDescriptor<CombineResult>())) ?? []
        let knownIDs = Set(existing.map(\.id))
        for row in rows {
            guard let idStr = row["id"] as? String, let id = UUID(uuidString: idStr),
                  !knownIDs.contains(id) else { continue }
            let value = (row["value"] as? Double) ?? Double((row["value"] as? String) ?? "") ?? 0
            let result = CombineResult(
                id: id,
                testID: (row["test_id"] as? String) ?? "",
                value: value,
                recordedAt: Self.parseISO(row["recorded_at"]) ?? Date()
            )
            context.insert(result)
        }
    }

    /// Newest updated_at per (user, drill) wins.
    private func mergeDrillNotes(userID: String, context: ModelContext) async {
        let rows = await SupabaseClient.shared.get(
            table: "drill_notes",
            query: [URLQueryItem(name: "user_id", value: "eq.\(userID)")]
        ) ?? []
        guard !rows.isEmpty else { return }
        let existing = (try? context.fetch(FetchDescriptor<DrillNote>())) ?? []
        var byID = Dictionary(existing.map { ($0.drillID, $0) }, uniquingKeysWith: { a, _ in a })
        for row in rows {
            guard let drillID = row["drill_id"] as? String,
                  let text = row["text"] as? String else { continue }
            let updatedAt = Self.parseISO(row["updated_at"]) ?? .distantPast
            if let local = byID[drillID] {
                if updatedAt > local.updatedAt {
                    local.text = text
                    local.updatedAt = updatedAt
                }
            } else {
                let note = DrillNote(drillID: drillID, text: text, updatedAt: updatedAt)
                context.insert(note)
                byID[drillID] = note
            }
        }
    }

    /// Newest updated_at per workout id wins.
    private func mergeCustomWorkouts(userID: String, context: ModelContext) async {
        let rows = await SupabaseClient.shared.get(
            table: "custom_workouts",
            query: [URLQueryItem(name: "user_id", value: "eq.\(userID)")]
        ) ?? []
        guard !rows.isEmpty else { return }
        let existing = (try? context.fetch(FetchDescriptor<CustomWorkout>())) ?? []
        var byID = Dictionary(existing.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        for row in rows {
            guard let idStr = row["id"] as? String, let id = UUID(uuidString: idStr) else { continue }
            let name = (row["name"] as? String) ?? "Workout"
            let drillIDs = (row["drill_ids"] as? [String]) ?? []
            let isShared = (row["is_shared_import"] as? Bool) ?? false
            let updatedAt = Self.parseISO(row["updated_at"]) ?? .distantPast
            if let local = byID[id] {
                if updatedAt > local.updatedAt {
                    local.title = name
                    local.drillIDs = drillIDs
                    local.isShared = isShared
                    local.updatedAt = updatedAt
                }
            } else {
                let workout = CustomWorkout(id: id, title: name, updatedAt: updatedAt,
                                           drillIDs: drillIDs, isShared: isShared)
                context.insert(workout)
                byID[id] = workout
            }
        }
    }

    /// Union by lesson_id — stamp completedAt locally if missing.
    private func mergeGameIQCompletions(userID: String, context: ModelContext) async {
        let rows = await SupabaseClient.shared.get(
            table: "gameiq_completions",
            query: [URLQueryItem(name: "user_id", value: "eq.\(userID)")]
        ) ?? []
        guard !rows.isEmpty else { return }
        let lessons = (try? context.fetch(FetchDescriptor<GameIQLesson>())) ?? []
        let byID = Dictionary(lessons.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        for row in rows {
            guard let lessonID = row["lesson_id"] as? String, let lesson = byID[lessonID] else { continue }
            let completedAt = Self.parseISO(row["completed_at"]) ?? Date()
            if lesson.completedAt == nil { lesson.completedAt = completedAt }
        }
    }
}

nonisolated extension ISO8601DateFormatter {
    /// Variant that also parses fractional-second timestamps (Postgres timestamptz).
    static let withFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}

/// Decoded remote player_state row (PostgREST returns loosely-typed JSON).
nonisolated struct RemotePlayerState {
    let xp: Int
    let streak: Int
    let freezesRemaining: Int
    let lastTrainedDate: String?
    let streakPB: Int

    init?(row: [String: Any]) {
        self.xp = (row["xp"] as? Int) ?? Int((row["xp"] as? String) ?? "") ?? 0
        self.streak = (row["streak"] as? Int) ?? 0
        self.freezesRemaining = (row["freezes_remaining"] as? Int) ?? 0
        self.lastTrainedDate = row["last_trained_date"] as? String
        self.streakPB = (row["streak_pb"] as? Int) ?? 0
    }
}
