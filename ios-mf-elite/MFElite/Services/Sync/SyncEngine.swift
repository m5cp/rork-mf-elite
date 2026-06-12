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
    }

    /// Tables we own and their upsert conflict keys (player_id injected at flush).
    private static let conflictKeys: [String: String] = [
        "player_state": "player_id",
        "player_progress": "player_id,drill_id"
    ]

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
        flush()
    }

    /// Called when the app returns to the foreground.
    func onForeground() {
        refreshPendingCount()
        pullPlayerStateOnLaunch()
        flush()
    }

    /// Called right after a successful sign-in: push queued work and check
    /// whether the cloud has more progress to restore onto this device.
    func handleSignIn() {
        backoffUntil = nil
        flush()
        if let context { SyncRestore.shared.checkForRestore(context: context) }
    }

    /// Called on sign-out: drop the outbox so a different account never inherits
    /// this session's queued mutations. Local SwiftData is untouched.
    func handleSignOut() {
        guard let context else { return }
        let ops = (try? context.fetch(FetchDescriptor<PendingOp>())) ?? []
        for op in ops { context.delete(op) }
        try? context.save()
        backoffUntil = nil
        refreshPendingCount()
    }

    /// Force a flush now (used by the Settings "Sync now" action).
    func syncNow() {
        backoffUntil = nil
        pullPlayerStateOnLaunch()
        flush()
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
                payload["player_id"] = playerID

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
