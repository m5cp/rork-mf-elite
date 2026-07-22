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

    func configure(context: ModelContext) { self.context = context }

    func applyPending() async {
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

        for row in rows {
            guard let id = row["id"] as? String,
                  let kind = row["kind"] as? String else { continue }
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
                if let badgeID = row["badge_id"] as? String {
                    AchievementStore.applyRemote([badgeID])
                    notices.append("restored a badge")
                }
            case "force_resync":
                SyncEngine.shared.retryQuarantined()
                SyncEngine.shared.syncNow()
                notices.append("refreshed your account sync")
            default:
                continue
            }

            // Mark consumed so it never applies twice.
            _ = await SupabaseClient.shared.update(
                table: "support_adjustments",
                values: ["consumed_at": ISO8601DateFormatter().string(from: Date())],
                match: [URLQueryItem(name: "id", value: "eq.\(id)")]
            )
        }

        try? context.save()
        SyncEngine.shared.enqueuePlayerState(player)
        if !notices.isEmpty {
            latestNotice = "Your coach " + notices.joined(separator: ", ") + "."
        }
    }

    func dismissNotice() { latestNotice = nil }
}
