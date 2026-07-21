//
//  DrillResult.swift
//  MFElite
//
//  A single numeric score recorded for a drill (e.g. juggles in 60s, cone-weave
//  time). APPEND-ONLY: never update or delete old results — every attempt is a
//  new row, exactly like CombineResult, so progress over time is preserved.
//

import Foundation
import SwiftData

@Model
final class DrillResult {
    @Attribute(.unique) var id: UUID
    /// The local drill string id (Drill.id).
    var drillID: String
    var value: Double
    /// Free-form unit label the player chose ("reps", "seconds", "goals", ...).
    var unit: String = ""
    var recordedAt: Date

    init(id: UUID = UUID(), drillID: String, value: Double, unit: String = "", recordedAt: Date = Date()) {
        self.id = id
        self.drillID = drillID
        self.value = value
        self.unit = unit
        self.recordedAt = recordedAt
    }
}
