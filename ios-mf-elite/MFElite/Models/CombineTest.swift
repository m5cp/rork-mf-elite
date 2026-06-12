//
//  CombineTest.swift
//  MFElite
//
//  Data layer for the "MF Combine" baseline skills test. Each CombineTest is a
//  self-measured event; CombineResult is an append-only log of recorded attempts
//  so a player's progress over time is preserved.
//

import Foundation
import SwiftData

/// A self-measured combine test. `lowerIsBetter` is true for timed events
/// (a faster time = a lower number = a better score).
@Model
final class CombineTest {
    @Attribute(.unique) var id: String
    var name: String
    var unit: String // "touches", "seconds", "reps", "inches", "laps"
    var lowerIsBetter: Bool
    var category: String // "technical" | "physical"
    var instructions: [String]
    var sortIndex: Int

    init(id: String, name: String, unit: String, lowerIsBetter: Bool,
         category: String, instructions: [String], sortIndex: Int) {
        self.id = id; self.name = name; self.unit = unit
        self.lowerIsBetter = lowerIsBetter; self.category = category
        self.instructions = instructions; self.sortIndex = sortIndex
    }
}

/// One recorded attempt. APPEND-ONLY: never update or delete old results —
/// every new score is a new row so progress over time is preserved.
@Model
final class CombineResult {
    @Attribute(.unique) var id: UUID
    var testID: String
    var value: Double
    var recordedAt: Date

    init(id: UUID = UUID(), testID: String, value: Double, recordedAt: Date = Date()) {
        self.id = id; self.testID = testID; self.value = value; self.recordedAt = recordedAt
    }
}
