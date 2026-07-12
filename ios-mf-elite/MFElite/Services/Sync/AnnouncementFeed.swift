//
//  AnnouncementFeed.swift
//  MFElite
//
//  Player-side pull of the most recent active team announcement (last 7 days,
//  title not starting with "__"). Mirrors it into a local SwiftData cache so the
//  Today banner renders even offline. Fails soft — any error leaves the existing
//  cache intact. Strictly additive and read-only on the player side.
//

import Foundation
import SwiftData
import Observation

/// Tracks which announcement the player has dismissed, so the banner stays
/// hidden once swiped away. Local-only, keyed by announcement id.
@Observable
@MainActor
final class AnnouncementStore {
    static let shared = AnnouncementStore()
    private let defaults = UserDefaults.standard
    private let key = "MF_DISMISSED_ANNOUNCEMENT_ID"
    private let poppedKey = "MF_POPPED_ANNOUNCEMENT_ID"

    private(set) var dismissedID: String
    private(set) var poppedID: String

    private init() {
        dismissedID = defaults.string(forKey: key) ?? ""
        poppedID = defaults.string(forKey: poppedKey) ?? ""
    }

    func isDismissed(_ id: UUID) -> Bool { dismissedID == id.uuidString }

    func dismiss(_ id: UUID) {
        dismissedID = id.uuidString
        defaults.set(dismissedID, forKey: key)
    }

    /// True until the player has seen the one-time pop-up for this announcement.
    func hasPopped(_ id: UUID) -> Bool { poppedID == id.uuidString }

    /// Record that the pop-up for this announcement has been shown.
    func markPopped(_ id: UUID) {
        poppedID = id.uuidString
        defaults.set(poppedID, forKey: poppedKey)
    }
}

@MainActor
enum AnnouncementFeed {
    /// Refresh the local cache from Supabase. Only runs when signed in. On a
    /// network failure the cache is left untouched (so it still shows offline);
    /// an explicit empty result clears stale cached announcements.
    static func refresh(context: ModelContext) async {
        guard SupabaseAuth.shared.isSignedIn else { return }

        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let since = SyncEngine.iso.string(from: weekAgo)

        let rows = await SupabaseClient.shared.get(
            table: "announcements",
            query: [
                URLQueryItem(name: "active", value: "eq.true"),
                URLQueryItem(name: "created_at", value: "gte.\(since)"),
                URLQueryItem(name: "order", value: "created_at.desc"),
                URLQueryItem(name: "limit", value: "10")
            ]
        )
        // nil = request failed → keep whatever is cached for offline display.
        guard let rows else { return }

        // Newest announcement whose title is not an internal "__"-prefixed one.
        let visible = rows.first { row in
            let title = (row["title"] as? String) ?? ""
            return !title.hasPrefix("__")
        }

        let existing = (try? context.fetch(FetchDescriptor<Announcement>())) ?? []
        for cached in existing { context.delete(cached) }

        if let row = visible,
           let idStr = row["id"] as? String, let id = UUID(uuidString: idStr) {
            let title = (row["title"] as? String) ?? ""
            let body = (row["body"] as? String) ?? ""
            context.insert(Announcement(
                id: id,
                title: title,
                body: body,
                createdAt: parseDate(row["created_at"]) ?? Date()
            ))
            // Fire a one-time local notification for a newly-seen announcement.
            NotificationService.shared.notifyAnnouncement(id: idStr, title: title, body: body)
        }
        try? context.save()
    }

    private static func parseDate(_ value: Any?) -> Date? {
        guard let string = value as? String else { return nil }
        return SyncEngine.iso.date(from: string)
            ?? ISO8601DateFormatter.withFractional.date(from: string)
    }
}
