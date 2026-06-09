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

    /// Optional gear the player needs (e.g. ["1 ball", "4 cones"]). Empty when
    /// the content hasn't specified any — the SET-UP line is then omitted.
    var equipment: [String]
    /// Optional playing area the drill needs (e.g. "5x5 yards"). `nil` when unspecified.
    var space: String?

    /// True when this drill is a step-driven mental exercise rather than a
    /// timer-based physical drill.
    var isMentalExercise: Bool { exerciseKind != nil }

    /// A single "SET-UP" summary combining equipment and space, or `nil` when the
    /// content provides neither. Equipment items are comma-joined, then the space
    /// is appended after a middot — e.g. "1 ball, 4 cones · 5x5 yards".
    var setupSummary: String? {
        var parts: [String] = []
        let gear = equipment.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        if !gear.isEmpty {
            parts.append(gear.joined(separator: ", "))
        }
        if let space, !space.trimmingCharacters(in: .whitespaces).isEmpty {
            parts.append(space)
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

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
        journalPrompt: String? = nil,
        equipment: [String] = [],
        space: String? = nil
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
        self.equipment = equipment
        self.space = space
    }
}
