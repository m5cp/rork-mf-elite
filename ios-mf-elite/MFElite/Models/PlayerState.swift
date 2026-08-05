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
    /// Highest streak ever reached (personal best). Maintained whenever the
    /// streak advances; mirrored to `player_state.streak_pb` on the server.
    var streakPB: Int = 0
    /// XP bought through the store. Counts toward academy rank/levels ONLY.
    /// Leaderboards, Game Center, and coach views read earned `xp` — never this.
    var purchasedXP: Int = 0

    /// The XP used for academy rank / level progression displays.
    var rankXP: Int { xp + purchasedXP }

    init(
        playerID: String = UUID().uuidString,
        xp: Int = 0,
        streak: Int = 0,
        freezesRemaining: Int = 0,
        lastTrainedDate: Date? = nil,
        streakPB: Int = 0
    ) {
        self.playerID = playerID
        self.xp = xp
        self.streak = streak
        self.freezesRemaining = freezesRemaining
        self.lastTrainedDate = lastTrainedDate
        self.streakPB = streakPB
    }
}
