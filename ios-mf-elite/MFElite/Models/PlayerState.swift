//
//  PlayerState.swift
//  MFElite
//

import Foundation
import SwiftData

/// The player's overall progression state.
@Model
final class PlayerState {
    var playerID: String
    var xp: Int
    var streak: Int
    var freezesRemaining: Int
    var lastTrainedDate: Date?

    init(
        playerID: String = UUID().uuidString,
        xp: Int = 0,
        streak: Int = 0,
        freezesRemaining: Int = 0,
        lastTrainedDate: Date? = nil
    ) {
        self.playerID = playerID
        self.xp = xp
        self.streak = streak
        self.freezesRemaining = freezesRemaining
        self.lastTrainedDate = lastTrainedDate
    }
}
