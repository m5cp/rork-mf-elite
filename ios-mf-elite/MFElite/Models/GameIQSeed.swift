//
//  GameIQSeed.swift
//  MFElite
//
//  Seeds the first 6 Game IQ tactical lessons on launch. Mirrors CombineSeed's
//  "re-seed only if missing" approach: lessons are keyed by a stable id, so any
//  lesson absent from the store is inserted while a player's completedAt stamps
//  (on lessons that already exist) are never touched.
//

import Foundation
import SwiftData

enum GameIQSeed {

    /// Inserts any of the lessons that aren't already in the store. Safe to call
    /// on every launch — existing lessons and their completion stamps are kept.
    static func seedIfNeeded(context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<GameIQLesson>())) ?? []
        let existingIDs = Set(existing.map(\.id))

        let missing = lessons.filter { !existingIDs.contains($0.id) }
        guard !missing.isEmpty else { return }

        for lesson in missing {
            context.insert(
                GameIQLesson(
                    id: lesson.id,
                    title: lesson.title,
                    summary: lesson.summary,
                    keyPoints: lesson.keyPoints,
                    quizData: GameIQLesson.encode(lesson.quiz),
                    relatedCategoryID: lesson.relatedCategoryID,
                    sortIndex: lesson.sortIndex
                )
            )
        }
        try? context.save()
    }

    // MARK: - Definitions

    private struct Definition {
        let id: String
        let title: String
        let summary: String
        let keyPoints: [String]
        let quiz: [GameIQLesson.QuizQuestion]
        let relatedCategoryID: String
        let sortIndex: Int
    }

    private typealias Q = GameIQLesson.QuizQuestion

    private static let lessons: [Definition] = [
        Definition(
            id: "iq-ddd",
            title: "Delay, Deny, Dictate",
            summary: "When you press the ball, you have three jobs in order: slow the attacker down, take away their easy pass, and force them where you want them to go. Good defenders do all three on every press.",
            keyPoints: [
                "Delay first. Don't dive in. Slow the attacker down so your teammates can get back and get set.",
                "Deny second. Show the attacker away from goal and block the easy forward pass with your body shape.",
                "Dictate third. Angle your run so the attacker can only go where you want — usually toward the sideline.",
                "Stay on your toes and keep a side-on body shape so you can react either way.",
                "Be patient. Win the ball when they make a mistake, not by lunging at it."
            ],
            quiz: [
                Q(prompt: "What is the FIRST job when you press the ball?",
                  choices: ["Win the ball immediately", "Delay — slow the attacker down", "Sprint past the attacker"],
                  correctIndex: 1,
                  whyText: "Delay comes first. Slowing the attacker buys time for your teammates to recover and get organised before you try to win it."),
                Q(prompt: "To 'dictate' play, you want to force the attacker to go where?",
                  choices: ["Straight at your goal", "Toward the sideline, away from danger", "Wherever they want"],
                  correctIndex: 1,
                  whyText: "Dictating means steering the attacker toward the sideline — it acts like an extra defender and takes away their best options."),
                Q(prompt: "What body shape helps you delay and deny at the same time?",
                  choices: ["Square on, facing the attacker", "Side-on, showing them one way", "Turned away from the ball"],
                  correctIndex: 1,
                  whyText: "A side-on stance lets you block one direction (deny) while staying balanced to react and slow them down (delay).")
            ],
            relatedCategoryID: "tact-c",
            sortIndex: 0
        ),
        Definition(
            id: "iq-triggers",
            title: "Pressing Triggers",
            summary: "Smart defenders don't chase the ball all game — they wait for the right moment to GO. A pressing trigger is a signal that the attacker is vulnerable. Learn to spot them and your timing transforms.",
            keyPoints: [
                "A bad first touch is your loudest trigger. The instant the ball runs away from them, GO.",
                "A back pass is a trigger. The attacker is going backwards and often facing their own goal — press hard.",
                "When the ball carrier's head is down, they can't see their options. That's your moment.",
                "A bouncing or in-the-air ball is hard to control — attack it as it lands.",
                "No trigger? Stay patient and hold your shape. Don't press just because you're bored."
            ],
            quiz: [
                Q(prompt: "Which of these is a classic pressing trigger?",
                  choices: ["A clean, settled first touch", "A heavy first touch that runs away from the attacker", "The attacker passing sideways with their head up"],
                  correctIndex: 1,
                  whyText: "A heavy touch means the ball is briefly out of their control — the perfect moment to win it back."),
                Q(prompt: "Why is a back pass a good moment to press?",
                  choices: ["The attacker is going forward fast", "The receiver is often facing their own goal and under less control", "It's never a good moment"],
                  correctIndex: 1,
                  whyText: "On a back pass the receiver is usually facing the wrong way, so pressing it can force a mistake or a rushed clearance."),
                Q(prompt: "There's no trigger and the attacker is calm with their head up. What should you do?",
                  choices: ["Dive in anyway", "Hold your shape and stay patient", "Turn your back and jog away"],
                  correctIndex: 1,
                  whyText: "With no trigger, pressing just opens space behind you. Stay patient, keep your shape, and wait for the signal.")
            ],
            relatedCategoryID: "tact-c",
            sortIndex: 1
        ),
        Definition(
            id: "iq-counterpress",
            title: "The 5-Second Rule",
            summary: "The best moment to win the ball back is right after you lose it. For five seconds the other team is disorganised and the player who just won it is unbalanced. Counterpress immediately instead of jogging back.",
            keyPoints: [
                "The instant you lose the ball, your first thought is WIN IT BACK — not retreat.",
                "The player who just won the ball is often off-balance and not yet looking up. Pounce.",
                "The first few seconds after a turnover, the other team is out of shape — that's your best chance.",
                "Surround the ball: the nearest players swarm while teammates cut off the escape passes.",
                "If you don't win it back in about five seconds, then drop into your defensive shape."
            ],
            quiz: [
                Q(prompt: "When is often the BEST moment to win the ball back?",
                  choices: ["After a few minutes of resting", "In the first few seconds right after you lose it", "Only in your own penalty box"],
                  correctIndex: 1,
                  whyText: "Right after a turnover the opponent is disorganised and the ball-winner is unbalanced — that's your highest-percentage chance to recover it."),
                Q(prompt: "What's your first thought the moment you lose the ball?",
                  choices: ["Jog back slowly", "Win it back immediately", "Complain to the referee"],
                  correctIndex: 1,
                  whyText: "Counterpressing starts in your head — react instantly to win it back before the opponent settles."),
                Q(prompt: "What if you can't win it back in about five seconds?",
                  choices: ["Keep chasing forever", "Drop into your defensive shape", "Stand still"],
                  correctIndex: 1,
                  whyText: "If the quick counterpress fails, recover into your organised defensive shape rather than chasing and leaving gaps.")
            ],
            relatedCategoryID: "tact-c",
            sortIndex: 2
        ),
        Definition(
            id: "iq-lines",
            title: "Breaking Lines",
            summary: "A line-breaking pass travels past a row of opponents and takes them out of the game in one go. Learning to spot and receive these passes is what separates players who keep possession from players who actually create.",
            keyPoints: [
                "A 'line' is a row of opponents — their forwards, midfield, or defence. A pass that goes past a line eliminates those players.",
                "One line-breaking pass can beat several defenders at once — far more valuable than a safe sideways pass.",
                "To receive between lines, find the gap between their midfield and defence where no one is marking you.",
                "Open your body before the ball arrives so you can play forward, not back toward your own goal.",
                "A half-turn as you receive lets you face the game and attack the space you just found."
            ],
            quiz: [
                Q(prompt: "What does a line-breaking pass do?",
                  choices: ["Goes sideways to a teammate", "Travels past a row of opponents and takes them out of the play", "Always goes backwards"],
                  correctIndex: 1,
                  whyText: "A line-breaking pass eliminates a whole row of defenders at once, which is why it's so much more dangerous than a square ball."),
                Q(prompt: "Where do you want to receive to be 'between the lines'?",
                  choices: ["Right next to your own keeper", "In the gap between the opponent's midfield and defence", "Stood inside their goal"],
                  correctIndex: 1,
                  whyText: "The space between their midfield and defence is where defenders struggle to pick you up — receive there to turn and attack."),
                Q(prompt: "What should you do with your body just before the ball arrives?",
                  choices: ["Open up so you can play forward", "Face your own goal", "Close your eyes"],
                  correctIndex: 0,
                  whyText: "Opening your body before you receive lets you take a half-turn and play forward instead of being forced backwards.")
            ],
            relatedCategoryID: "tact-b",
            sortIndex: 3
        ),
        Definition(
            id: "iq-scanning",
            title: "Scan Before It Arrives",
            summary: "Great players know what they'll do before the ball reaches them. The secret is scanning — a quick look over your shoulder before you receive — so you collect a picture of the space, the pressure, and your teammates.",
            keyPoints: [
                "Scanning means a quick glance over your shoulder before the ball comes to you.",
                "Look for space: where is the open grass you could move into?",
                "Look for pressure: is a defender about to close you down, and from which side?",
                "Look for teammates: who is open for your next pass before you even receive?",
                "Scan often — a glance every few seconds — so your picture stays up to date."
            ],
            quiz: [
                Q(prompt: "When should you scan?",
                  choices: ["Only after you've already received the ball", "Before the ball arrives, while it's travelling to you", "Never — just watch the ball"],
                  correctIndex: 1,
                  whyText: "Scanning before the ball arrives means you already know your options the moment it reaches your feet — no wasted touches."),
                Q(prompt: "Which of these should you look for when you scan?",
                  choices: ["Space, pressure, and teammates", "The scoreboard", "The crowd"],
                  correctIndex: 0,
                  whyText: "A good scan collects three things: open space to move into, where pressure is coming from, and which teammates are free."),
                Q(prompt: "How often should you scan?",
                  choices: ["Once at kickoff", "Frequently — a quick glance every few seconds", "Only at halftime"],
                  correctIndex: 1,
                  whyText: "The game changes constantly, so a single look isn't enough. Scan often to keep your mental picture fresh.")
            ],
            relatedCategoryID: "tact-a",
            sortIndex: 4
        ),
        Definition(
            id: "iq-finishing-areas",
            title: "High-Percentage Areas",
            summary: "Most goals come from a small zone in front of goal — not from the edges. Smart attackers time a run to ARRIVE in the box as the ball comes in, instead of standing and waiting to be marked.",
            keyPoints: [
                "Most goals are scored from central areas close to goal, between the penalty spot and the six-yard box.",
                "Shots from tight angles or far out go in far less often — get the ball central when you can.",
                "Don't stand still in the box waiting — defenders will mark you and you're easy to track.",
                "Time your run to ARRIVE as the cross or pass comes in, attacking the ball with momentum.",
                "Aim for the gap between the last defender and the keeper — the danger zone for a finish."
            ],
            quiz: [
                Q(prompt: "Where do most goals come from?",
                  choices: ["The corner flag", "Central areas close to goal", "The halfway line"],
                  correctIndex: 1,
                  whyText: "The central zone between the penalty spot and the six-yard box is where the vast majority of goals are scored."),
                Q(prompt: "What's better than standing still in the box waiting for a cross?",
                  choices: ["Timing a run to arrive as the ball comes in", "Standing on the penalty spot the whole time", "Running away from goal"],
                  correctIndex: 0,
                  whyText: "A well-timed run is hard to mark and lets you attack the ball with momentum, instead of being tracked while you wait."),
                Q(prompt: "Which shot is the highest percentage?",
                  choices: ["A tight-angle shot from the byline", "A central chance close to goal", "A long shot from your own half"],
                  correctIndex: 1,
                  whyText: "Central, close-range chances go in far more often than tight angles or long-range efforts — get into that zone to finish.")
            ],
            relatedCategoryID: "tact-d",
            sortIndex: 5
        )
    ]
}
