//
//  SeedData.swift
//  MFElite
//

import Foundation
import SwiftData

/// Seeds the full MF Elite curriculum and demo player state on first launch.
enum SeedData {

    /// Inserts curriculum, player state, and progress only if the store is empty.
    static func seedIfNeeded(context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<Discipline>())) ?? []
        guard existing.isEmpty else { return }

        for discipline in buildDisciplines() {
            context.insert(discipline)
        }

        let player = PlayerState(xp: 3620, streak: 14, freezesRemaining: 2, lastTrainedDate: Date())
        context.insert(player)

        for drillID in masteredDrillIDs() {
            context.insert(DrillProgress(
                drillID: drillID,
                passesLogged: ProgressionRules.masteryPasses,
                lastLoggedAt: Date(),
                isMastered: true
            ))
        }

        try? context.save()
    }

    // MARK: - Builders

    /// A lightweight spec used to construct `Drill` models with sequential IDs.
    private struct DrillSpec {
        let title: String
        let focus: String
        let how: String
        let durationSec: Int
        let sets: Int
        let points: [String]
    }

    private static func makeDrill(_ spec: DrillSpec, id: String, sort: Int, video: Bool) -> Drill {
        Drill(
            id: id,
            title: spec.title,
            focus: spec.focus,
            how: spec.how,
            videoURL: video ? "https://video.mfelite.training/\(id).mp4" : nil,
            durationSec: spec.durationSec,
            sets: spec.sets,
            coachingPoints: spec.points,
            sortIndex: sort
        )
    }

    private static func buildDisciplines() -> [Discipline] {
        [
            technical(),
            physical(),
            tactical(),
            psychological()
        ]
    }

    // MARK: - 01 Technical

    private static func technical() -> Discipline {
        let video = false
        let prefix = "tech"

        let ballMastery = Category(
            id: "\(prefix)-a", letter: "A", name: "Ball Mastery",
            focus: "Close control under pressure", certName: "Ball Mastery Certified", sortIndex: 0,
            levels: [
                MasteryLevel(id: "\(prefix)-a-1", number: 1, name: "Foundation Touch", theme: "Building the base", sortIndex: 0, drills: [
                    makeDrill(.init(title: "Sole Rolls", focus: "Foot-ball connection", how: "Roll ball under sole, alternate feet, maintain posture", durationSec: 360, sets: 3, points: ["Keep weight on standing foot", "Light touches, ball stays close", "Head up between rolls"]), id: "\(prefix)-a-1-1", sort: 0, video: video),
                    makeDrill(.init(title: "Inside Taps", focus: "Inside-foot rhythm", how: "Tap ball between feet using inside of each foot", durationSec: 300, sets: 3, points: ["Knees slightly bent", "Stay on balls of feet", "Build speed gradually"]), id: "\(prefix)-a-1-2", sort: 1, video: video),
                    makeDrill(.init(title: "Toe Taps", focus: "Quick-foot coordination", how: "Alternate toe taps on top of ball at pace", durationSec: 300, sets: 3, points: ["Light contact with laces", "Stay compact, no bouncing", "Eyes forward not down"]), id: "\(prefix)-a-1-3", sort: 2, video: video)
                ]),
                MasteryLevel(id: "\(prefix)-a-2", number: 2, name: "Controlled Movement", theme: "Moving with the ball", sortIndex: 1, drills: [
                    makeDrill(.init(title: "Inside-Outside Control", focus: "Directional touch", how: "Push ball inside then outside with same foot", durationSec: 360, sets: 3, points: ["Small touches keep control", "Accelerate on the outside push", "Use both feet equally"]), id: "\(prefix)-a-2-1", sort: 0, video: video),
                    makeDrill(.init(title: "V-Pulls", focus: "Change of direction", how: "Pull ball back with sole then push forward at angle", durationSec: 360, sets: 3, points: ["Sell the initial direction", "Sharp change of angle", "Protect ball with body"]), id: "\(prefix)-a-2-2", sort: 1, video: video),
                    makeDrill(.init(title: "Cruyff Turns", focus: "Deception turn", how: "Fake pass then drag ball behind standing leg", durationSec: 360, sets: 3, points: ["Exaggerate the fake", "Plant foot firmly", "Accelerate out of the turn"]), id: "\(prefix)-a-2-3", sort: 2, video: video)
                ]),
                MasteryLevel(id: "\(prefix)-a-3", number: 3, name: "Pressure Mastery", theme: "Under defensive pressure", sortIndex: 2, drills: [
                    makeDrill(.init(title: "La Croqueta", focus: "Tight-space evasion", how: "Roll ball from one foot to the other laterally at speed", durationSec: 420, sets: 3, points: ["Keep ball under body", "Quick weight transfer", "Use when defender commits"]), id: "\(prefix)-a-3-1", sort: 0, video: video),
                    makeDrill(.init(title: "Drag-Back Step-Over", focus: "Combination move", how: "Pull back then step over and accelerate away", durationSec: 420, sets: 3, points: ["Smooth transition between moves", "Sell each part individually", "Burst of pace to finish"]), id: "\(prefix)-a-3-2", sort: 1, video: video),
                    makeDrill(.init(title: "360 Spin", focus: "Full rotation under control", how: "Drag ball with sole through a full 360 turn", durationSec: 420, sets: 3, points: ["Keep ball close throughout", "Use body to shield", "Eyes up on exit"]), id: "\(prefix)-a-3-3", sort: 2, video: video)
                ])
            ]
        )

        let firstTouch = Category(
            id: "\(prefix)-b", letter: "B", name: "First Touch",
            focus: "Receiving and redirecting", certName: "First Touch Certified", sortIndex: 1,
            levels: [
                MasteryLevel(id: "\(prefix)-b-1", number: 1, name: "Cushion Control", theme: "Soft receives", sortIndex: 0, drills: [
                    makeDrill(.init(title: "Inside Cushion", focus: "Absorbing pace", how: "Receive with inside of foot, cushion on contact", durationSec: 300, sets: 3, points: ["Withdraw foot on contact", "Angle body to next action"]), id: "\(prefix)-b-1-1", sort: 0, video: video),
                    makeDrill(.init(title: "Thigh Settle", focus: "Aerial control", how: "Bring ball down with thigh to feet", durationSec: 360, sets: 3, points: ["Lean back slightly", "Contact on flat of thigh"]), id: "\(prefix)-b-1-2", sort: 1, video: video)
                ]),
                MasteryLevel(id: "\(prefix)-b-2", number: 2, name: "Directional First Touch", theme: "Touch with intent", sortIndex: 1, drills: [
                    makeDrill(.init(title: "Open-Body Receive", focus: "Playing forward", how: "Open hips to receive across body into space", durationSec: 360, sets: 3, points: ["Check shoulder before ball arrives", "Touch into stride"]), id: "\(prefix)-b-2-1", sort: 0, video: video),
                    makeDrill(.init(title: "Back-Foot Pass", focus: "One-touch redirect", how: "Receive and redirect with back foot in one motion", durationSec: 360, sets: 3, points: ["Weight of pass matters", "Keep ankle locked"]), id: "\(prefix)-b-2-2", sort: 1, video: video)
                ])
            ]
        )

        let passing = Category(
            id: "\(prefix)-c", letter: "C", name: "Passing",
            focus: "Weight, timing, accuracy", certName: "Passing Certified", sortIndex: 2,
            levels: [
                MasteryLevel(id: "\(prefix)-c-1", number: 1, name: "Foundation Passing", theme: "Accuracy first", sortIndex: 0, drills: [
                    makeDrill(.init(title: "Inside-Foot Pass", focus: "Ground accuracy", how: "Lock ankle and pass through center of ball", durationSec: 300, sets: 3, points: ["Non-kicking foot beside ball", "Follow through to target"]), id: "\(prefix)-c-1-1", sort: 0, video: video),
                    makeDrill(.init(title: "Wall Passes", focus: "Quick combinations", how: "Two-touch pass-and-move against a wall or partner", durationSec: 360, sets: 3, points: ["First touch sets up second", "Move after every pass"]), id: "\(prefix)-c-1-2", sort: 1, video: video)
                ]),
                MasteryLevel(id: "\(prefix)-c-2", number: 2, name: "Weighted Passing", theme: "Right pace, right moment", sortIndex: 1, drills: [
                    makeDrill(.init(title: "Lofted Pass", focus: "Distance with arc", how: "Strike under the ball for elevation and distance", durationSec: 360, sets: 3, points: ["Lean back on contact", "Land the ball softly"]), id: "\(prefix)-c-2-1", sort: 0, video: video),
                    makeDrill(.init(title: "Through Ball", focus: "Threading the gap", how: "Weight a pass into space ahead of the runner", durationSec: 360, sets: 3, points: ["Time the runner's movement", "Disguise your intention"]), id: "\(prefix)-c-2-2", sort: 1, video: video)
                ])
            ]
        )

        let dribbling = Category(
            id: "\(prefix)-d", letter: "D", name: "Dribbling",
            focus: "Beating defenders in space", certName: "Dribbling Certified", sortIndex: 3,
            levels: [
                MasteryLevel(id: "\(prefix)-d-1", number: 1, name: "Close Dribbling", theme: "Tight space control", sortIndex: 0, drills: [
                    makeDrill(.init(title: "Cone Weave", focus: "Agility with ball", how: "Dribble through cones using both feet alternating", durationSec: 300, sets: 3, points: ["Small touches between cones", "Accelerate out of each turn"]), id: "\(prefix)-d-1-1", sort: 0, video: video),
                    makeDrill(.init(title: "Stop-Start", focus: "Change of pace", how: "Sole stop then explosive acceleration", durationSec: 300, sets: 3, points: ["Sell the stop", "Burst with outside of foot"]), id: "\(prefix)-d-1-2", sort: 1, video: video)
                ]),
                MasteryLevel(id: "\(prefix)-d-2", number: 2, name: "1v1 Moves", theme: "Beating a defender", sortIndex: 1, drills: [
                    makeDrill(.init(title: "Scissors", focus: "Body feint", how: "Step over ball then take with outside of opposite foot", durationSec: 360, sets: 3, points: ["Drop shoulder convincingly", "Go when defender shifts weight"]), id: "\(prefix)-d-2-1", sort: 0, video: video),
                    makeDrill(.init(title: "Elastico", focus: "Snap direction change", how: "Push outside then snap inside with same foot", durationSec: 420, sets: 3, points: ["All in the ankle", "Speed of snap is everything"]), id: "\(prefix)-d-2-2", sort: 1, video: video)
                ])
            ]
        )

        let shooting = Category(
            id: "\(prefix)-e", letter: "E", name: "Shooting",
            focus: "Finishing with precision", certName: "Shooting Certified", sortIndex: 4,
            levels: [
                MasteryLevel(id: "\(prefix)-e-1", number: 1, name: "Striking Technique", theme: "Clean contact", sortIndex: 0, drills: [
                    makeDrill(.init(title: "Instep Drive", focus: "Power shot", how: "Laces strike through center of ball", durationSec: 300, sets: 3, points: ["Plant foot pointing at target", "Strike through, not at"]), id: "\(prefix)-e-1-1", sort: 0, video: video),
                    makeDrill(.init(title: "Placed Finish", focus: "Side-foot accuracy", how: "Side-foot finish to corners", durationSec: 300, sets: 3, points: ["Pick your corner early", "Composure over power"]), id: "\(prefix)-e-1-2", sort: 1, video: video)
                ]),
                MasteryLevel(id: "\(prefix)-e-2", number: 2, name: "Finishing Under Pressure", theme: "When it matters", sortIndex: 1, drills: [
                    makeDrill(.init(title: "One-Touch Finish", focus: "Reaction shooting", how: "First-time strike from a pass", durationSec: 360, sets: 3, points: ["Body shape before ball arrives", "Attack the ball"]), id: "\(prefix)-e-2-1", sort: 0, video: video),
                    makeDrill(.init(title: "Weak-Foot Finish", focus: "Both feet clinical", how: "Finishing drill using only weak foot", durationSec: 360, sets: 3, points: ["Extra reps on weak side", "Same technique, build confidence"]), id: "\(prefix)-e-2-2", sort: 1, video: video)
                ])
            ]
        )

        return Discipline(
            id: "d-\(prefix)", number: "01", name: "Technical", mark: "square",
            tagline: "The ball, mastered",
            blurb: "Everything starts with your touch. Master the ball in every situation — under pressure, at speed, in tight spaces.",
            media: "drill", sortIndex: 0,
            categories: [ballMastery, firstTouch, passing, dribbling, shooting]
        )
    }

    // MARK: - 02 Physical

    private static func physical() -> Discipline {
        let video = false
        let prefix = "phys"

        let speed = Category(
            id: "\(prefix)-a", letter: "A", name: "Speed",
            focus: "Explosive acceleration", certName: "Speed Certified", sortIndex: 0,
            levels: [
                MasteryLevel(id: "\(prefix)-a-1", number: 1, name: "First-Step Quickness", theme: "Win the first metre", sortIndex: 0, drills: [
                    makeDrill(.init(title: "Standing Sprints", focus: "Explosive start", how: "10m sprints from standing, full recovery", durationSec: 480, sets: 5, points: ["Low body angle on start", "Drive arms aggressively"]), id: "\(prefix)-a-1-1", sort: 0, video: video),
                    makeDrill(.init(title: "Reaction Sprints", focus: "Mental trigger speed", how: "Sprint on visual or audio cue", durationSec: 480, sets: 5, points: ["Stay loaded and ready", "First step wins the race"]), id: "\(prefix)-a-1-2", sort: 1, video: video)
                ])
            ]
        )

        let agility = Category(
            id: "\(prefix)-b", letter: "B", name: "Agility",
            focus: "Multi-directional movement", certName: "Agility Certified", sortIndex: 1,
            levels: [
                MasteryLevel(id: "\(prefix)-b-1", number: 1, name: "Change of Direction", theme: "Sharp movements", sortIndex: 0, drills: [
                    makeDrill(.init(title: "T-Drill", focus: "4-direction agility", how: "Sprint forward, shuffle sides, backpedal", durationSec: 420, sets: 4, points: ["Low center of gravity", "Quick feet on direction change"]), id: "\(prefix)-b-1-1", sort: 0, video: video),
                    makeDrill(.init(title: "L-Drill", focus: "90-degree cuts", how: "Sprint and cut 90 degrees on command", durationSec: 420, sets: 4, points: ["Plant outside foot hard", "Lean into the new direction"]), id: "\(prefix)-b-1-2", sort: 1, video: video)
                ])
            ]
        )

        return Discipline(
            id: "d-\(prefix)", number: "02", name: "Physical", mark: "triangle",
            tagline: "The athlete, built",
            blurb: "Speed, power, endurance, agility. Build the athletic foundation that separates good from elite.",
            media: "drill", sortIndex: 1,
            categories: [speed, agility]
        )
    }

    // MARK: - 03 Tactical

    private static func tactical() -> Discipline {
        let video = true
        let prefix = "tact"

        let positioning = Category(
            id: "\(prefix)-a", letter: "A", name: "Positioning",
            focus: "Where to be and when", certName: "Positioning Certified", sortIndex: 0,
            levels: [
                MasteryLevel(id: "\(prefix)-a-1", number: 1, name: "Off-the-Ball Movement", theme: "Creating space", sortIndex: 0, drills: [
                    makeDrill(.init(title: "Check Away, Check To", focus: "Creating separation", how: "Move away from the ball then check back to receive", durationSec: 600, sets: 1, points: ["Timing of the run matters", "Show for the ball at pace"]), id: "\(prefix)-a-1-1", sort: 0, video: video),
                    makeDrill(.init(title: "Blind-Side Runs", focus: "Exploiting gaps", how: "Run behind the defender's line of sight", durationSec: 600, sets: 1, points: ["Wait for the right moment", "Curve your run to stay onside"]), id: "\(prefix)-a-1-2", sort: 1, video: video)
                ])
            ]
        )

        let decision = Category(
            id: "\(prefix)-b", letter: "B", name: "Decision Making",
            focus: "Reading the game", certName: "Decision Making Certified", sortIndex: 1,
            levels: [
                MasteryLevel(id: "\(prefix)-b-1", number: 1, name: "Scanning", theme: "Before the ball arrives", sortIndex: 0, drills: [
                    makeDrill(.init(title: "Head Checks", focus: "Awareness habit", how: "Scan shoulders before receiving every pass", durationSec: 600, sets: 1, points: ["Scan at least twice before ball", "Know your options before touching"]), id: "\(prefix)-b-1-1", sort: 0, video: video),
                    makeDrill(.init(title: "Option Assessment", focus: "Play selection", how: "Identify pass, dribble, or hold before receiving", durationSec: 600, sets: 1, points: ["Pre-decide then execute", "Change plan only if situation changes"]), id: "\(prefix)-b-1-2", sort: 1, video: video)
                ])
            ]
        )

        return Discipline(
            id: "d-\(prefix)", number: "03", name: "Tactical", mark: "diamond",
            tagline: "The game, understood",
            blurb: "Read the game before it happens. Understand positions, patterns, and decision-making at the highest level.",
            media: "video", sortIndex: 2,
            categories: [positioning, decision]
        )
    }

    // MARK: - 04 Psychological

    private static func psychological() -> Discipline {
        let video = true
        let prefix = "psy"

        let focus = Category(
            id: "\(prefix)-a", letter: "A", name: "Focus",
            focus: "Concentration under pressure", certName: "Focus Certified", sortIndex: 0,
            levels: [
                MasteryLevel(id: "\(prefix)-a-1", number: 1, name: "Controlled Breathing", theme: "Staying present", sortIndex: 0, drills: [
                    makeDrill(.init(title: "Box Breathing", focus: "Calm the nervous system", how: "Inhale 4 seconds, hold 4, exhale 4, hold 4", durationSec: 300, sets: 3, points: ["Use before high-pressure moments", "Focus on the count only"]), id: "\(prefix)-a-1-1", sort: 0, video: video),
                    makeDrill(.init(title: "Trigger Words", focus: "Instant refocus", how: "Choose one word to reset focus during play", durationSec: 300, sets: 1, points: ["Pick a word that means something to you", "Say it to yourself when distracted"]), id: "\(prefix)-a-1-2", sort: 1, video: video)
                ])
            ]
        )

        let resilience = Category(
            id: "\(prefix)-b", letter: "B", name: "Resilience",
            focus: "Bouncing back from setbacks", certName: "Resilience Certified", sortIndex: 1,
            levels: [
                MasteryLevel(id: "\(prefix)-b-1", number: 1, name: "Error Recovery", theme: "Next play mentality", sortIndex: 0, drills: [
                    makeDrill(.init(title: "Flush It", focus: "Letting go of mistakes", how: "Acknowledge the error, reset, execute next action", durationSec: 300, sets: 1, points: ["Mistakes are data, not identity", "Three seconds to reset"]), id: "\(prefix)-b-1-1", sort: 0, video: video),
                    makeDrill(.init(title: "Pressure Reframe", focus: "Turning nerves to fuel", how: "Reinterpret pressure as excitement and opportunity", durationSec: 300, sets: 1, points: ["Excitement and anxiety feel the same", "Say: I'm excited to compete"]), id: "\(prefix)-b-1-2", sort: 1, video: video)
                ])
            ]
        )

        return Discipline(
            id: "d-\(prefix)", number: "04", name: "Psychological", mark: "circle",
            tagline: "The mind, strengthened",
            blurb: "Confidence, focus, resilience, leadership. The mental game that defines champions.",
            media: "video", sortIndex: 3,
            categories: [focus, resilience]
        )
    }

    // MARK: - Mastered drills (demo state)

    /// Drill IDs marked mastered to back the 3,620 XP / Rank II Cadet demo player.
    /// All of Ball Mastery (9) plus scattered drills across other categories.
    private static func masteredDrillIDs() -> [String] {
        [
            // Technical · Ball Mastery (full)
            "tech-a-1-1", "tech-a-1-2", "tech-a-1-3",
            "tech-a-2-1", "tech-a-2-2", "tech-a-2-3",
            "tech-a-3-1", "tech-a-3-2", "tech-a-3-3",
            // Technical · First Touch
            "tech-b-1-1", "tech-b-1-2", "tech-b-2-1", "tech-b-2-2",
            // Technical · Passing
            "tech-c-1-1", "tech-c-1-2", "tech-c-2-1",
            // Technical · Dribbling
            "tech-d-1-1", "tech-d-1-2", "tech-d-2-1",
            // Technical · Shooting
            "tech-e-1-1", "tech-e-1-2",
            // Physical · Speed
            "phys-a-1-1", "phys-a-1-2",
            // Physical · Agility
            "phys-b-1-1", "phys-b-1-2",
            // Tactical · Positioning
            "tact-a-1-1", "tact-a-1-2",
            // Psychological · Focus
            "psy-a-1-1", "psy-a-1-2"
        ]
    }
}
