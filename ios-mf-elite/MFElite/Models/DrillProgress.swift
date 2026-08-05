//
//  DrillProgress.swift
//  MFElite
//

import Foundation
import SwiftData

/// Tracks a player's mastery progress on a single drill.
@Model
final class DrillProgress {
    @Attribute(.unique) var drillID: String
    var passesLogged: Int       // 0...3
    var lastLoggedAt: Date?
    var isMastered: Bool
    /// When mastery was actually reached. `lastLoggedAt` moves every time the
    /// drill is re-run, so it can't answer "was this mastered this month" —
    /// which is what the parent report claims to report. Optional so existing
    /// stores migrate in place; nil on drills mastered before this shipped.
    var masteredAt: Date?

    init(
        drillID: String,
        passesLogged: Int = 0,
        lastLoggedAt: Date? = nil,
        isMastered: Bool = false,
        masteredAt: Date? = nil
    ) {
        self.drillID = drillID
        self.passesLogged = passesLogged
        self.lastLoggedAt = lastLoggedAt
        self.isMastered = isMastered
        self.masteredAt = masteredAt
    }
}
