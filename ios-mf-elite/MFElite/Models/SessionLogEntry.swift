//
//  SessionLogEntry.swift
//  MFElite
//
//  A permanent, per-completion training log record. Unlike DrillProgress
//  (which keeps a single rolling `lastLoggedAt` per drill), one SessionLogEntry
//  is written every time a drill is completed, so past days can be inspected
//  and analytics are computed from real history rather than lossy state.
//

import Foundation
import SwiftData

/// Where a logged session originated.
enum SessionSource: String {
    case single
    case routine
    case workout
}

/// One completed drill, denormalized so history survives curriculum re-seeds.
@Model
final class SessionLogEntry {
    @Attribute(.unique) var id: UUID
    var completedAt: Date
    var drillID: String
    var drillTitle: String
    var disciplineID: String
    var disciplineName: String
    var categoryID: String
    var categoryName: String
    var levelNumber: Int
    /// Actual time spent training, excluding rest and pauses.
    var durationSec: Int
    var setsCompleted: Int
    /// "single", "routine", or "workout".
    var source: String
    /// Routine or custom workout title; nil for single drills.
    var sourceName: String?
    var xpEarned: Int
    /// The player's written reflection for a mental exercise's journal prompt.
    var journalResponse: String?

    init(
        id: UUID = UUID(),
        completedAt: Date = Date(),
        drillID: String,
        drillTitle: String,
        disciplineID: String,
        disciplineName: String,
        categoryID: String,
        categoryName: String,
        levelNumber: Int,
        durationSec: Int,
        setsCompleted: Int,
        source: String = SessionSource.single.rawValue,
        sourceName: String? = nil,
        xpEarned: Int,
        journalResponse: String? = nil
    ) {
        self.id = id
        self.completedAt = completedAt
        self.drillID = drillID
        self.drillTitle = drillTitle
        self.disciplineID = disciplineID
        self.disciplineName = disciplineName
        self.categoryID = categoryID
        self.categoryName = categoryName
        self.levelNumber = levelNumber
        self.durationSec = durationSec
        self.setsCompleted = setsCompleted
        self.source = source
        self.sourceName = sourceName
        self.xpEarned = xpEarned
        self.journalResponse = journalResponse
    }
}
