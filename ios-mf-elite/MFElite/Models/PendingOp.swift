//
//  PendingOp.swift
//  MFElite
//
//  A single durable outbox entry. Every local mutation that must reach Supabase
//  is recorded as a PendingOp and flushed FIFO by the SyncEngine when online and
//  signed in. Ops are idempotent (natural keys + upsert) so retries are always
//  safe. The row stores the table, the operation kind, and the JSON payload
//  (without the player_id, which the engine injects from the live session at
//  flush time so a queued op stays valid across sign-ins).
//

import Foundation
import SwiftData

@Model
final class PendingOp {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var table: String
    /// "upsert" | "delete"
    var opType: String
    /// JSON-encoded row (upsert) or match filters (delete).
    var payloadJSON: Data
    var attempts: Int
    /// True when the server rejected this op with a permanent (4xx) error.
    /// Quarantined ops are skipped by the flush loop so one bad op can never
    /// block the queue. They are retried only via retryQuarantined().
    /// Defaulted so existing stores migrate in place (lightweight migration).
    var isQuarantined: Bool = false
    /// The HTTP status that caused quarantine, for diagnostics. 0 = none.
    var lastErrorStatus: Int = 0
    /// The account this op belongs to.
    ///
    /// Sign-out used to delete the whole queue, so anything not yet uploaded —
    /// drill scores, watch workouts, purchases, favorites, every delete — was
    /// lost, and the backfill doesn't regenerate those. Keeping the queue
    /// instead means it has to be attributable, or the next account signed in
    /// would flush someone else's writes under its own credentials.
    ///
    /// Empty on rows written before this existed; those are treated as
    /// belonging to whoever is signed in when they are next flushed, which is
    /// correct for the single-account case they were all created in.
    /// Defaulted so existing stores migrate in place (lightweight migration).
    var ownerID: String = ""

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        table: String,
        opType: String,
        payloadJSON: Data,
        attempts: Int = 0,
        ownerID: String = ""
    ) {
        self.id = id
        self.createdAt = createdAt
        self.table = table
        self.opType = opType
        self.payloadJSON = payloadJSON
        self.attempts = attempts
        self.isQuarantined = false
        self.lastErrorStatus = 0
        self.ownerID = ownerID
    }
}
