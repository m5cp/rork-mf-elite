//
//  BallonDorStore.swift
//  MFElite
//
//  Local mirror of the player's Ballon d'Or invitation state. The unlock is
//  NEVER granted locally — it is only set true when the server reports a coach
//  approval. The request, by contrast, is recorded locally the moment the player
//  first meets the requirements and is pushed up through the durable outbox.
//

import Foundation
import Observation

@Observable
@MainActor
final class BallonDorStore {
    static let shared = BallonDorStore()

    /// When the player first met the requirements and a request was recorded.
    private(set) var requestedAt: Date?
    /// True only when the server reports a coach approval. Never set locally.
    private(set) var approved: Bool
    /// The coach who approved the invitation, when known.
    private(set) var approvedBy: String?
    /// When the approval was granted.
    private(set) var approvedAt: Date?
    /// True once the full unlock celebration has been shown.
    private(set) var celebrationSeen: Bool
    /// XP at the moment a coach last declined; the player must surpass it (train
    /// more / re-qualify) before another request is recorded.
    private var declinedXP: Int

    private enum Keys {
        static let requestedAt = "MF_BDOR_REQUESTED_AT"
        static let approved = "MF_BDOR_APPROVED"
        static let approvedBy = "MF_BDOR_APPROVED_BY"
        static let approvedAt = "MF_BDOR_APPROVED_AT"
        static let celebrationSeen = "MF_BDOR_CELEBRATION_SEEN"
        static let declinedXP = "MF_BDOR_DECLINED_XP"
    }

    private let defaults = UserDefaults.standard

    private init() {
        let req = defaults.double(forKey: Keys.requestedAt)
        requestedAt = req > 0 ? Date(timeIntervalSince1970: req) : nil
        approved = defaults.bool(forKey: Keys.approved)
        approvedBy = defaults.string(forKey: Keys.approvedBy)
        let app = defaults.double(forKey: Keys.approvedAt)
        approvedAt = app > 0 ? Date(timeIntervalSince1970: app) : nil
        celebrationSeen = defaults.bool(forKey: Keys.celebrationSeen)
        declinedXP = defaults.integer(forKey: Keys.declinedXP)
    }

    /// The presentation state for the progression UI.
    func state(meetsRequirements: Bool) -> BallonDorState {
        if approved { return .approved }
        if requestedAt != nil { return .pending }
        return meetsRequirements ? .eligible : .locked
    }

    // MARK: - Request (player → server)

    /// Record a request once, the first time the player meets the requirements.
    /// Idempotent; also enqueues a durable outbox upsert to player_profiles.
    func recordRequestIfNeeded(meets: Bool, xp: Int) {
        guard meets, !approved, requestedAt == nil else { return }
        // After a decline, require fresh progress before re-requesting.
        if declinedXP > 0, xp <= declinedXP { return }
        let now = Date()
        requestedAt = now
        defaults.set(now.timeIntervalSince1970, forKey: Keys.requestedAt)
        SyncEngine.shared.enqueueBallonDorRequest(requestedAt: now)
    }

    // MARK: - Pull (server → player)

    /// Reconcile local state with the server's player_profiles row. Applies a
    /// coach approval (the only path to unlock) or resets a declined request.
    func pullFromRemote(currentXP: Int) async {
        guard SupabaseAuth.shared.isSignedIn, let uid = SupabaseAuth.shared.userID else { return }
        let rows = await SupabaseClient.shared.get(
            table: "player_profiles",
            query: [
                URLQueryItem(name: "id", value: "eq.\(uid)"),
                URLQueryItem(name: "select", value: "ballon_dor_requested_at,ballon_dor_approved,ballon_dor_approved_at,ballon_dor_approved_by"),
                URLQueryItem(name: "limit", value: "1")
            ]
        )
        guard let row = rows?.first else { return }

        let serverApproved = (row["ballon_dor_approved"] as? Bool) ?? false
        let serverRequested = Self.parseDate(row["ballon_dor_requested_at"])

        if serverApproved {
            guard !approved else { return }
            approved = true
            approvedBy = row["ballon_dor_approved_by"] as? String
            approvedAt = Self.parseDate(row["ballon_dor_approved_at"])
            defaults.set(true, forKey: Keys.approved)
            if let approvedBy { defaults.set(approvedBy, forKey: Keys.approvedBy) }
            if let approvedAt { defaults.set(approvedAt.timeIntervalSince1970, forKey: Keys.approvedAt) }
            return
        }

        // Not approved on the server.
        if requestedAt != nil, serverRequested == nil {
            // Coach declined ("Not yet") → reset quietly to locked. The player
            // must make fresh progress before another request is recorded.
            requestedAt = nil
            declinedXP = currentXP
            defaults.removeObject(forKey: Keys.requestedAt)
            defaults.set(currentXP, forKey: Keys.declinedXP)
        } else if let serverRequested, requestedAt == nil {
            // A request recorded on another device — mirror the pending state.
            requestedAt = serverRequested
            defaults.set(serverRequested.timeIntervalSince1970, forKey: Keys.requestedAt)
        }
    }

    // MARK: - Celebration

    func markCelebrationSeen() {
        guard !celebrationSeen else { return }
        celebrationSeen = true
        defaults.set(true, forKey: Keys.celebrationSeen)
    }

    // MARK: - Sign-out reset

    /// Clear all Ballon d'Or state. The invitation is account-specific server
    /// state, so it is reset on sign-out and re-pulled on the next sign-in.
    func reset() {
        requestedAt = nil
        approved = false
        approvedBy = nil
        approvedAt = nil
        celebrationSeen = false
        declinedXP = 0
        defaults.removeObject(forKey: Keys.requestedAt)
        defaults.removeObject(forKey: Keys.approved)
        defaults.removeObject(forKey: Keys.approvedBy)
        defaults.removeObject(forKey: Keys.approvedAt)
        defaults.removeObject(forKey: Keys.celebrationSeen)
        defaults.removeObject(forKey: Keys.declinedXP)
    }

    // MARK: - Helpers

    private static func parseDate(_ value: Any?) -> Date? {
        guard let string = value as? String else { return nil }
        if let date = ISO8601DateFormatter.withFractional.date(from: string) { return date }
        if let date = ISO8601DateFormatter().date(from: string) { return date }
        return SyncEngine.date(from: string)
    }
}
