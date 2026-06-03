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

    init(
        drillID: String,
        passesLogged: Int = 0,
        lastLoggedAt: Date? = nil,
        isMastered: Bool = false
    ) {
        self.drillID = drillID
        self.passesLogged = passesLogged
        self.lastLoggedAt = lastLoggedAt
        self.isMastered = isMastered
    }
}
