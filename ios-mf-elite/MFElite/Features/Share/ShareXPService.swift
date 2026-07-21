//
//  ShareXPService.swift
//  MFElite
//
//  Awards +5 XP per DISTINCT platform per day for CONFIRMED shares of the
//  Rep The Badge and Player Card cards. Capped at 4 platforms/day (20 XP).
//  Confirmation = the share sheet's completion callback with completed == true.
//  Awards count as earned XP and are logged to share_xp_events for audit.
//

import Foundation
import SwiftData

@MainActor
final class ShareXPService {
    static let shared = ShareXPService()
    private init() {}

    static let xpPerShare = 5
    static let maxPlatformsPerDay = 4
    private static let defaultsKey = "MF_SHARE_XP_AWARDS" // "yyyy-MM-dd|platform" strings

    private var context: ModelContext?

    /// The two cards that earn share XP.
    static func isEligible(_ kind: ShareMomentKind) -> Bool {
        kind == .repBadge || kind == .playerCard
    }

    func configure(context: ModelContext) {
        self.context = context
    }

    /// Record a completed share. Returns the XP awarded (0 if not eligible,
    /// cancelled, repeat platform today, or daily cap reached).
    @discardableResult
    func recordShare(cardKind: ShareMomentKind, activityRawValue: String?, completed: Bool) -> Int {
        guard completed, Self.isEligible(cardKind), let context else { return 0 }

        let platform = Self.platformKey(from: activityRawValue)
        let day = Self.dayString(Date())
        let token = "\(day)|\(platform)"

        var awards = Set(UserDefaults.standard.stringArray(forKey: Self.defaultsKey) ?? [])
        // Keep only today's tokens so the list never grows unbounded.
        awards = awards.filter { $0.hasPrefix(day) }
        guard !awards.contains(token) else { return 0 } // same platform today
        guard awards.count < Self.maxPlatformsPerDay else { return 0 } // daily cap
        awards.insert(token)
        UserDefaults.standard.set(Array(awards), forKey: Self.defaultsKey)

        // Award earned XP.
        guard let player = try? context.fetch(FetchDescriptor<PlayerState>()).first else { return 0 }
        player.xp += Self.xpPerShare
        try? context.save()
        SyncEngine.shared.enqueuePlayerState(player)
        SyncEngine.shared.enqueueShareXP(day: day, platform: platform, cardKind: cardKind.rawValue)
        return Self.xpPerShare
    }

    /// Normalize an activity type into a stable platform key.
    static func platformKey(from raw: String?) -> String {
        guard let raw, !raw.isEmpty else { return "other" }
        let lower = raw.lowercased()
        if lower.contains("message") { return "messages" }
        if lower.contains("whatsapp") { return "whatsapp" }
        if lower.contains("telegra") { return "telegram" }
        if lower.contains("instagram") { return "instagram" }
        if lower.contains("facebook") { return "facebook" }
        if lower.contains("tiktok") { return "tiktok" }
        if lower.contains("snap") { return "snapchat" }
        if lower.contains("mail") { return "mail" }
        if lower.contains("savetocamera") || lower.contains("saveto") { return "saved" }
        return "other"
    }

    private static func dayString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter.string(from: date)
    }
}
