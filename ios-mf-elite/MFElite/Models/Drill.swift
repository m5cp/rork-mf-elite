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

    /// For mental exercises: "guided" | "breathing" | "visualization" | "journal".
    /// `nil` for physical, timer-based drills.
    var exerciseKind: String?
    /// Ordered, step-driven instructions for mental exercises.
    var steps: [String]
    /// A reflective question shown at the end of a mental exercise.
    var journalPrompt: String?

    /// True when this drill is a step-driven mental exercise rather than a
    /// timer-based physical drill.
    var isMentalExercise: Bool { exerciseKind != nil }

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
        sortIndex: Int,
        exerciseKind: String? = nil,
        steps: [String] = [],
        journalPrompt: String? = nil
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
        self.exerciseKind = exerciseKind
        self.steps = steps
        self.journalPrompt = journalPrompt
    }
}
