//
//  CoachWorkout.swift
//  MFElite
//
//  A local cache of a coach-published "Workout of the Day". Mirrors a row from
//  the remote `coach_workouts` table so the player's Today card still renders
//  offline. Purely additive: caching these never touches the curriculum, a
//  player's progress, history, or their own custom workouts.
//

import Foundation
import SwiftData

/// One coach-published featured workout, cached locally for offline display.
@Model
final class CoachWorkout {
    @Attribute(.unique) var id: UUID
    var title: String
    /// Optional note to players (e.g. "30 minutes, focus on your weak foot").
    var note: String
    /// Display name of the publishing coach, for the "FROM COACH …" eyebrow.
    var coachName: String
    /// Ordered local string drill IDs. Unknown IDs are skipped at render time.
    var drillIDs: [String]
    var createdAt: Date

    init(
        id: UUID,
        title: String,
        note: String,
        coachName: String,
        drillIDs: [String],
        createdAt: Date
    ) {
        self.id = id
        self.title = title
        self.note = note
        self.coachName = coachName
        self.drillIDs = drillIDs
        self.createdAt = createdAt
    }
}
