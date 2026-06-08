//
//  Drill.swift
//  MFElite
//

import Foundation
import SwiftData

/// A single trainable drill with coaching detail.
@Model
final class Drill {
    @Attribute(.unique) var id: String
    var title: String
    var focus: String
    var how: String
    var videoURL: String?
    var durationSec: Int
    var sets: Int
    var coachingPoints: [String]
    var instructions: [String]
    var sortIndex: Int

    init(
        id: String,
        title: String,
        focus: String,
        how: String,
        videoURL: String? = nil,
        durationSec: Int,
        sets: Int,
        coachingPoints: [String],
        instructions: [String] = [],
        sortIndex: Int
    ) {
        self.id = id
        self.title = title
        self.focus = focus
        self.how = how
        self.videoURL = videoURL
        self.durationSec = durationSec
        self.sets = sets
        self.coachingPoints = coachingPoints
        self.instructions = instructions
        self.sortIndex = sortIndex
    }
}
