//
//  SupportAdjustments.swift
//  MFElite
//
//  Player-side consumer of the head coach's support ledger. On launch and
//  foreground, fetch unconsumed adjustments for the signed-in user, apply
//  them exactly once, mark them consumed, and queue the changed state for
//  sync. Shows a small notice so the player knows what happened.
//

import Foundation
import SwiftData

@MainActor
@Observable
final class SupportAdjustments {
    static let shared = SupportAdjustments()
    private init() {}

    private var context: ModelContext?
    /// A human notice for the most recent applied adjustments ("Coach credited you 300 XP").
    private(set) var latestNotice: String?

    /// Guards against two overlapping runs. `applyPending()` is called from
    /// two places at cold launch (`MFEliteApp` scene setup and the
    /// foreground observer); both used to fetch the same unconsumed rows
    /// before either marked them consumed, and every grant applied twice.
    private var isApplying = false

    /// Adjustment ids already applied on this device.
    ///
    /// `consumed_at` alone is not enough: it is written over the network
    /// after the grant lands, so an offline or failed write left the row
    /// unconsumed server-side and it applied again on the next launch. This
    /// is the local record that makes each adjustment land exactly once.
    private static let appliedKey = "MF_SUPPORT_APPLIED_IDS"
    private static let appliedLimit = 500

    func configure(context: ModelContext) { self.context = context }

    func applyPending() async {
        guard !isApplying else { return }
        isApplying = true
        defer { isApplying = false }

        guard let context, SupabaseAuth.shared.isSignedIn,
              let uid = SupabaseAuth.shared.userID else { return }
        guard let rows = await SupabaseClient.shared.get(
            table: "support_adjustments",
            query: [
                URLQueryItem(name: "user_id", value: "eq.\(uid)"),
                URLQueryItem(name: "consumed_at", value: "is.null"),
                URLQueryItem(name: "order", value: "created_at.asc")
            ]
        ), !rows.isEmpty else { return }

        guard let player = try? context.fetch(FetchDescriptor<PlayerState>()).first else { return }
        var notices: [String] = []
        var consumed: [String] = []
        let alreadyApplied = Set(UserDefaults.standard.stringArray(forKey: Self.appliedKey) ?? [])

        for row in rows {
            guard let id = row["id"] as? String,
                  let kind = row["kind"] as? String else { continue }
            // Server says unconsumed, but this device already granted it —
            // the `consumed_at` write must have failed. Re-mark, don't re-apply.
            guard !alreadyApplied.contains(id) else {
                consumed.append(id)
                continue
            }
            let amount = row["amount"] as? Int ?? 0

            switch kind {
            case "xp":
                player.xp = max(0, player.xp + amount)
                notices.append(amount >= 0 ? "credited you \(amount) XP" : "adjusted your XP by \(amount)")
            case "purchased_xp":
                player.purchasedXP = max(0, player.purchasedXP + amount)
                notices.append("credited you \(amount) purchased XP")
            case "streak_freeze":
                player.freezesRemaining = min(XPStoreService.maxFreezes, player.freezesRemaining + max(0, amount))
                notices.append("granted you \(amount) streak shield\(amount == 1 ? "" : "s")")
            case "streak_set":
                player.streak = max(0, amount)
                player.streakPB = max(player.streakPB, player.streak)
                notices.append("restored your streak to \(amount) days")
            case "booster_hours":
                let until = max(Date().timeIntervalSince1970,
                                UserDefaults.standard.double(forKey: "MF_BOOSTER_UNTIL"))
                    + Double(max(0, amount)) * 3600
                UserDefaults.standard.set(until, forKey: "MF_BOOSTER_UNTIL")
                notices.append("granted you a \(amount)-hour 2x XP booster")
            case "badge":
                // Skip rather than fall through: without this the row is
                // marked consumed both locally and server-side, so the coach's
                // ledger reads "delivered" and the player never gets the badge.
                guard let badgeID = row["badge_id"] as? String else {
                    print("[SupportAdjustments] badge row \(id) has no badge_id — leaving unconsumed")
                    continue
                }
                AchievementStore.applyRemote([badgeID])
                notices.append("restored a badge")
            case "force_resync":
                SyncEngine.shared.retryQuarantined()
                SyncEngine.shared.syncNow()
                notices.append("refreshed your account sync")
            default:
                continue
            }

            consumed.append(id)
        }

        // Nothing recognised in this batch — an adjustment whose `kind` this
        // build doesn't know stays unconsumed on purpose, so a newer build can
        // still deliver it. Bail before the save and the sync enqueue.
        guard !consumed.isEmpty else { return }

        // Commit the grants first. A crash before this point marks nothing and
        // the whole batch retries cleanly; once it is recorded locally nothing
        // can land twice. If the save itself fails, mark nothing — better to
        // retry the batch than to record grants that were never written.
        do {
            try context.save()
        } catch {
            print("[SupportAdjustments] save failed, leaving batch unconsumed: \(error)")
            return
        }
        rememberApplied(consumed)

        // Then tell the server, so the coach's ledger shows them as consumed.
        // A failure here is survivable now — the local record above stops the
        // re-apply this used to cause.
        for id in consumed {
            _ = await SupabaseClient.shared.update(
                table: "support_adjustments",
                values: ["consumed_at": ISO8601DateFormatter().string(from: Date())],
                match: [URLQueryItem(name: "id", value: "eq.\(id)")]
            )
        }

        SyncEngine.shared.enqueuePlayerState(player)
        if !notices.isEmpty {
            latestNotice = "Your coach " + notices.joined(separator: ", ") + "."
        }
    }

    /// Append to the local applied-ledger, oldest trimmed off the front.
    private func rememberApplied(_ ids: [String]) {
        guard !ids.isEmpty else { return }
        var stored = UserDefaults.standard.stringArray(forKey: Self.appliedKey) ?? []
        for id in ids where !stored.contains(id) { stored.append(id) }
        if stored.count > Self.appliedLimit {
            stored.removeFirst(stored.count - Self.appliedLimit)
        }
        UserDefaults.standard.set(stored, forKey: Self.appliedKey)
    }

    func dismissNotice() { latestNotice = nil }
}
