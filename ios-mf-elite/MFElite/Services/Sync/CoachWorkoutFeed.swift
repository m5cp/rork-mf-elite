//
//  CoachWorkoutFeed.swift
//  MFElite
//
//  Player-side pull of coach-published "Workout of the Day" rows. Mirrors the
//  latest active coach workouts (last 7 days) into a local SwiftData cache so
//  the Today card renders even offline. Strictly additive and read-only: this
//  never touches the curriculum, a player's progress, history, or their own
//  custom workouts. Fails soft — any error leaves the existing cache intact.
//

import Foundation
import SwiftData

@MainActor
enum CoachWorkoutFeed {
    /// Refresh the local cache from Supabase. Only runs when signed in. On a
    /// network failure the cache is left untouched (so it still shows offline);
    /// an explicit empty result clears stale cached workouts.
    static func refresh(context: ModelContext) async {
        guard SupabaseAuth.shared.isSignedIn else { return }

        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let since = SyncEngine.iso.string(from: weekAgo)

        let rows = await SupabaseClient.shared.get(
            table: "coach_workouts",
            query: [
                URLQueryItem(name: "active", value: "eq.true"),
                URLQueryItem(name: "created_at", value: "gte.\(since)"),
                URLQueryItem(name: "order", value: "created_at.desc"),
                URLQueryItem(name: "limit", value: "10")
            ]
        )
        // nil = request failed → keep whatever is cached for offline display.
        guard let rows else { return }

        var fetched: [CoachWorkout] = []
        for row in rows {
            guard let idStr = row["id"] as? String, let id = UUID(uuidString: idStr) else { continue }
            fetched.append(CoachWorkout(
                id: id,
                title: (row["title"] as? String) ?? "Workout",
                note: (row["note"] as? String) ?? "",
                coachName: (row["coach_name"] as? String) ?? "Coach",
                drillIDs: (row["drill_ids"] as? [String]) ?? [],
                createdAt: parseDate(row["created_at"]) ?? Date()
            ))
        }

        // Replace the cache wholesale — it's a disposable mirror of the server.
        let existing = (try? context.fetch(FetchDescriptor<CoachWorkout>())) ?? []
        for workout in existing { context.delete(workout) }
        for workout in fetched { context.insert(workout) }
        try? context.save()
    }

    private static func parseDate(_ value: Any?) -> Date? {
        guard let string = value as? String else { return nil }
        return SyncEngine.iso.date(from: string)
            ?? ISO8601DateFormatter.withFractional.date(from: string)
    }
}
