//
//  GameEntry.swift
//  MFElite
//
//  A player-entered game on their schedule. Drives the Match Day card on
//  Today and the optional night-before prep reminder. Local-only (SwiftData).
//

import Foundation
import SwiftData

@Model
final class GameEntry {
    @Attribute(.unique) var id: UUID
    /// Game date (day precision is what matters; store the chosen date/time).
    var date: Date
    /// Optional opponent name, e.g. "Eagles". Empty string = not set.
    var opponent: String
    var createdAt: Date

    init(id: UUID = UUID(), date: Date, opponent: String = "", createdAt: Date = Date()) {
        self.id = id
        self.date = date
        self.opponent = opponent
        self.createdAt = createdAt
    }
}
