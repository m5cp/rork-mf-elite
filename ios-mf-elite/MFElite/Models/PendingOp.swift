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

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        table: String,
        opType: String,
        payloadJSON: Data,
        attempts: Int = 0
    ) {
        self.id = id
        self.createdAt = createdAt
        self.table = table
        self.opType = opType
        self.payloadJSON = payloadJSON
        self.attempts = attempts
    }
}
