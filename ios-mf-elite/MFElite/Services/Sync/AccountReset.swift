//
//  AccountReset.swift
//  MFElite
//
//  Everything that has to be forgotten when this device stops belonging to an
//  account — one list, in one place.
//
//  There are two ways an account leaves: it is deleted, or a different account
//  signs in over it. Both used to be handled partially and differently, and
//  what fell through the gap was the previous player's data showing up under
//  the next one:
//
//    * Account deletion cleared the SwiftData history but left badges, the
//      saved card design, favourites, the family roster and every counter that
//      regenerates badges sitting in UserDefaults.
//    * Signing out kept all local history by design (so the same player can
//      sign back in offline and lose nothing) — but nothing checked WHO signed
//      in next, so a second account inherited the first one's entire history
//      and the backfill then uploaded it to their server rows.
//
//  Plain sign-out still preserves everything. The wipe happens on sign-in, and
//  only when the account actually changed.
//

import Foundation
import SwiftData

@MainActor
enum AccountReset {

    /// Forget every trace of the previous account on this device.
    ///
    /// Seeded content — the curriculum, combine tests, Game IQ lessons — is
    /// left alone; only progress against it is cleared.
    static func everythingLocal(context: ModelContext) {
        // Route maps first: they are files on disk keyed by the WorkoutRecord
        // rows that are about to be deleted, so afterwards nothing knows they
        // exist. They are GPS traces of where the player trains.
        deleteRouteImages()

        SyncEngine.shared.wipeLocalData(context: context)

        // Identity and profile.
        PlayerProfileStore.shared.reset()
        // After the profile reset — FamilyStore.reset() re-seeds the primary
        // athlete from it, so the order decides whose name gets seeded.
        FamilyStore.shared.reset()

        // UserDefaults-backed state the SwiftData wipe cannot see.
        AchievementStore.reset()
        PlayerCardStore.shared.reset()
        FavoritesStore.shared.reset()
        MyTeamsStore.shared.reset()
        BallonDorStore.shared.reset()
        AnnouncementStore.shared.reset()
        // Holds a decoded copy in memory, so clearing the key isn't enough —
        // the resume banner would keep offering the last player's session.
        ResumeStore.shared.clear()

        // Counters that regenerate badges. Without these, the next player logs
        // one drill and is immediately awarded every drill-count badge the
        // previous player had earned — and they get enqueued to their account.
        let defaults = UserDefaults.standard
        for key in regeneratingKeys { defaults.removeObject(forKey: key) }

        // The Watch keeps its own snapshot in the shared App Group.
        WatchSyncBridge.shared.refreshAndPush()
    }

    /// Keys holding per-account state that no model wipe reaches.
    ///
    /// Only keys whose owners read them on demand belong here — anything cached
    /// in a singleton's `init()` needs a `reset()` call above instead, or the
    /// in-memory copy simply outlives the key.
    private static let regeneratingKeys = [
        "MF_PERFECT_DAYS",                       // DailyRings — drives perfectDay badges
        "mf.engagement.drillsCompleted",         // EngagementTracker — drives drill-count badges
        "MF_LAST_CELEBRATED_STREAK_MILESTONE",   // StreakMilestones
        "MF_SHARE_XP_AWARDS",                    // ShareXPService — daily per-platform ledger
        "MF_SHARE_PHOTO_GRANTS",                 // SharePhotoPermission
        "MF_LAST_SEEN_COACH_WORKOUT_AT",         // CoachWorkoutFeed
        "MF_NOTIFIED_ANNOUNCEMENT_ID",           // AnnouncementFeed
        // Apple returns fullName only on the FIRST authorization, so this is
        // the previous player's real name kept indefinitely — and it is what
        // the post-sign-in profile push prefers over the profile store.
        "MF_SUPABASE_APPLE_NAME",
        // Entitlements the previous account paid for or was granted.
        "MF_BOOSTER_UNTIL",
        "MF_BOOSTER_MONTH",
        "MF_PENDING_GRANTS",
        "MF_PURCHASED_XP_MONTH",
        "MF_SHIELDS_MONTH",
    ]

    /// Unlink the rendered route maps — GPS traces of where the player trains.
    ///
    /// Removes the whole directory rather than walking `WorkoutRecord`, so
    /// images already orphaned by an earlier wipe go too.
    private static func deleteRouteImages() {
        // `directory` recreates itself on next access, so this is safe to nuke.
        try? FileManager.default.removeItem(at: WorkoutRouteRenderer.directory)
    }
}
