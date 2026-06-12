//
//  CustomWorkout.swift
//  MFElite
//
//  A player-built training session: an ordered list of drill IDs that runs
//  exactly like a curated routine. Survives app restarts via SwiftData.
//

import Foundation
import SwiftData

/// A custom workout built by the player from any drills in the curriculum.
@Model
final class CustomWorkout {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    /// Ordered drill IDs. A drill may appear more than once for repeat blocks.
    var drillIDs: [String]
    /// True when the workout was imported from another player's QR code.
    /// Defaults to false so existing records migrate cleanly.
    var isShared: Bool = false

    init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        drillIDs: [String],
        isShared: Bool = false
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.drillIDs = drillIDs
        self.isShared = isShared
    }
}
