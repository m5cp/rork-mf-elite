//
//  DrillActivityAttributes.swift
//  MFEliteShared
//
//  Live Activity model shared between the app (which starts/updates the
//  activity) and the widget extension (which renders it on the lock screen and
//  in the Dynamic Island). Lives in a shared synchronized group so both targets
//  compile the exact same type.
//

import Foundation
import ActivityKit

nonisolated struct DrillActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// Title of the drill currently being trained.
        var drillTitle: String
        /// Short phase label, e.g. "Set 2 of 3" or "Rest".
        var phaseLabel: String
        /// True while resting between sets.
        var isResting: Bool
        /// True while the timer is paused.
        var isPaused: Bool
        /// 1-based index of the current set.
        var currentSet: Int
        /// Total number of sets in the drill.
        var totalSets: Int
        /// The moment the current countdown reaches zero — drives the live
        /// ticking text on the lock screen while running.
        var endDate: Date
        /// Seconds remaining, frozen, used to render the time while paused.
        var pausedRemaining: Int
    }

    /// The session name (routine/workout) or the drill name for a single drill.
    var sessionName: String
}
