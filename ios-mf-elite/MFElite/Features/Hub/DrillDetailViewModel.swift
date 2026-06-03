//
//  DrillDetailViewModel.swift
//  MFElite
//

import Foundation
import Observation

/// Derives Drill-detail presentation values from one drill and player mastery.
@MainActor
@Observable
final class DrillDetailViewModel {
    let drill: Drill
    let level: MasteryLevel
    let category: Category
    let discipline: Discipline

    private let passes: Int
    private let mastered: Bool

    init(
        drill: Drill,
        level: MasteryLevel,
        category: Category,
        discipline: Discipline,
        passesLogged: Int,
        isMastered: Bool
    ) {
        self.drill = drill
        self.level = level
        self.category = category
        self.discipline = discipline
        self.passes = passesLogged
        self.mastered = isMastered
    }

    var passesLogged: Int { passes }

    var isMastered: Bool { mastered }

    /// Three-letter abbreviation of the discipline name (e.g. "Technical" → "TEC").
    private var disciplineAbbreviation: String {
        String(discipline.name.prefix(3)).uppercased()
    }

    /// Formatted as "DRILL TEC·A·L2·05".
    var drillCode: String {
        "DRILL \(disciplineAbbreviation)·\(category.letter)·L\(level.number)·\(String(format: "%02d", drill.sortIndex))"
    }

    /// Readable duration for the stat strip (e.g. "6 min").
    var formattedDuration: String {
        drill.durationSec.minutesDuration
    }

    /// Clock-style duration for the demo chip (e.g. "6:00").
    var clockDuration: String {
        drill.durationSec.clockDuration
    }
}
