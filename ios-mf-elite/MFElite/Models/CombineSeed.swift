//
//  CombineSeed.swift
//  MFElite
//
//  Seeds the 8 MF Combine baseline tests on first launch. Mirrors SeedData's
//  "re-seed only if missing" approach: tests are keyed by a stable id, so any
//  test absent from the store is inserted, while CombineResult history (keyed
//  separately) is never touched.
//

import Foundation
import SwiftData

enum CombineSeed {

    /// Inserts any of the 8 combine tests that aren't already in the store.
    /// Safe to call on every launch — existing tests and results are preserved.
    static func seedIfNeeded(context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<CombineTest>())) ?? []
        let existingIDs = Set(existing.map(\.id))

        let missing = tests.filter { !existingIDs.contains($0.id) }
        guard !missing.isEmpty else { return }

        for test in missing {
            context.insert(
                CombineTest(
                    id: test.id,
                    name: test.name,
                    unit: test.unit,
                    lowerIsBetter: test.lowerIsBetter,
                    category: test.category,
                    instructions: test.instructions,
                    sortIndex: test.sortIndex
                )
            )
        }
        try? context.save()
    }

    // MARK: - Definitions

    private struct Definition {
        let id: String
        let name: String
        let unit: String
        let lowerIsBetter: Bool
        let category: String
        let instructions: [String]
        let sortIndex: Int
    }

    private static let tests: [Definition] = [
        Definition(
            id: "juggle",
            name: "Juggling Record",
            unit: "touches",
            lowerIsBetter: false,
            category: "technical",
            instructions: [
                "Ball starts in your hands.",
                "Drop it and keep it up with feet, thighs, head — no hands.",
                "Count every touch until the ball hits the ground.",
                "Best of 3 attempts — enter your best."
            ],
            sortIndex: 0
        ),
        Definition(
            id: "coneweave",
            name: "Cone Weave",
            unit: "seconds",
            lowerIsBetter: true,
            category: "technical",
            instructions: [
                "Set 5 cones in a line, 2 yards apart (10 yards total).",
                "Start behind cone 1 with the ball.",
                "Dribble weaving through all cones, turn, weave back.",
                "Time from first touch to crossing the start line. Best of 2."
            ],
            sortIndex: 1
        ),
        Definition(
            id: "wallpass",
            name: "Wall Pass 60",
            unit: "reps",
            lowerIsBetter: false,
            category: "technical",
            instructions: [
                "Stand 3 yards from a wall.",
                "Pass against the wall, control, pass again — two-touch maximum.",
                "Count completed passes in 60 seconds."
            ],
            sortIndex: 2
        ),
        Definition(
            id: "figure8",
            name: "Figure-8 Dribble",
            unit: "laps",
            lowerIsBetter: false,
            category: "technical",
            instructions: [
                "Place 2 cones 3 yards apart.",
                "Dribble in a figure-8 around both cones.",
                "Count full laps in 30 seconds — half laps count as .5."
            ],
            sortIndex: 3
        ),
        Definition(
            id: "toetap30",
            name: "Toe-Tap 30",
            unit: "reps",
            lowerIsBetter: false,
            category: "technical",
            instructions: [
                "Ball still on the ground.",
                "Alternate sole taps on top of the ball, fast as you can.",
                "Count taps in 30 seconds."
            ],
            sortIndex: 4
        ),
        Definition(
            id: "shuttle",
            name: "5-10-5 Shuttle",
            unit: "seconds",
            lowerIsBetter: true,
            category: "physical",
            instructions: [
                "3 cones in a line, 5 yards apart.",
                "Start at the middle cone.",
                "Sprint 5 yards right, touch line; 10 yards left, touch; 5 yards back through the middle.",
                "Time the run. Best of 2 with full rest."
            ],
            sortIndex: 5
        ),
        Definition(
            id: "sprint20",
            name: "Sprint 20",
            unit: "seconds",
            lowerIsBetter: true,
            category: "physical",
            instructions: [
                "Mark a straight 20-yard lane.",
                "From a standing start, sprint through the far line.",
                "Time from first movement. Best of 2 with full rest."
            ],
            sortIndex: 6
        ),
        Definition(
            id: "broadjump",
            name: "Broad Jump",
            unit: "inches",
            lowerIsBetter: false,
            category: "physical",
            instructions: [
                "Stand behind a line, feet shoulder-width.",
                "Swing arms and jump forward off both feet.",
                "Measure from the line to your closest heel, in inches. Best of 3."
            ],
            sortIndex: 7
        )
    ]
}
