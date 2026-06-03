//
//  AnnouncementStore.swift
//  MFElite
//
//  Loads active coach announcements for the player Today screen and tracks which
//  ones the player has dismissed (persisted locally so they stay dismissed).
//

import Foundation
import Observation

@MainActor
@Observable
final class AnnouncementStore {
    static let shared = AnnouncementStore()

    private(set) var announcements: [SupabaseAnnouncement] = []
    private var dismissedIDs: Set<String>

    private let dismissedKey = "dismissed_announcement_ids"

    private init() {
        let stored = UserDefaults.standard.stringArray(forKey: dismissedKey) ?? []
        dismissedIDs = Set(stored)
    }

    /// Active announcements the player hasn't dismissed yet.
    var visible: [SupabaseAnnouncement] {
        announcements.filter { !dismissedIDs.contains($0.id) }
    }

    /// Refresh from Supabase. Safe to call on launch and on pull-to-refresh.
    func refresh() async {
        let remote = await CurriculumSyncService.shared.syncAnnouncements()
        announcements = remote
        // Prune dismissals for announcements that no longer exist.
        let liveIDs = Set(remote.map(\.id))
        let pruned = dismissedIDs.intersection(liveIDs)
        if pruned != dismissedIDs {
            dismissedIDs = pruned
            persist()
        }
    }

    func dismiss(_ id: String) {
        dismissedIDs.insert(id)
        persist()
    }

    private func persist() {
        UserDefaults.standard.set(Array(dismissedIDs), forKey: dismissedKey)
    }
}
