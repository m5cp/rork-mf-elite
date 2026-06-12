//
//  CurriculumEdit.swift
//  MFElite
//
//  Durable local cache of coach-published curriculum overlay rows (the remote
//  `curriculum_edits` table). Storing them locally lets the overlay re-apply
//  after a curriculum re-seed and keeps coach content working offline. Purely
//  additive: applying these only changes drill CONTENT — never a player's
//  progress, history, streaks, favorites, routines, or custom workouts.
//

import Foundation
import SwiftData

/// One cached coach curriculum edit. `kind` is "edit" | "new" | "hide".
@Model
final class CurriculumEditCache {
    /// The target drill's string id ("edit"/"hide") or a generated "COACH-…" id ("new").
    @Attribute(.unique) var drillID: String
    var kind: String
    /// JSON object of the changed content fields (camelCase keys matching Drill).
    var payloadJSON: Data
    var updatedBy: String
    /// For "new": the category the drill belongs to. `nil` for "edit"/"hide".
    var categoryID: String?
    /// For "new": which level inside the category. 0 when unspecified.
    var levelNumber: Int
    /// When this edit was first seen on this device — drives the 7-day NEW tag.
    var firstSeenAt: Date

    init(
        drillID: String,
        kind: String,
        payloadJSON: Data,
        updatedBy: String,
        categoryID: String? = nil,
        levelNumber: Int = 0,
        firstSeenAt: Date = Date()
    ) {
        self.drillID = drillID
        self.kind = kind
        self.payloadJSON = payloadJSON
        self.updatedBy = updatedBy
        self.categoryID = categoryID
        self.levelNumber = levelNumber
        self.firstSeenAt = firstSeenAt
    }

    /// Decoded payload as a loosely-typed dictionary.
    var payload: [String: Any] {
        (try? JSONSerialization.jsonObject(with: payloadJSON)) as? [String: Any] ?? [:]
    }
}
