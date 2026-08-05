//
//  StreakEngine.swift
//  MFElite
//
//  The single source of truth for how the training streak advances, how it is
//  defended by a streak freeze, and when it breaks.
//
//  Before this existed, every logging path did `if !isDateInToday(lastTrained)
//  { streak += 1 }` and nothing in the app ever decreased the streak — so a
//  player who trained once in January and once in March showed a "2 day
//  streak", and `freezesRemaining` (awarded at milestones AND sold in the
//  store) was never read or spent by any streak logic. Every caller now goes
//  through this type.
//
//  The rules, in one place:
//
//  * Training on a day already counted changes nothing.
//  * Training the day after the last training day keeps the run going: +1.
//  * Training after a longer gap spends one freeze per fully missed day. With
//    enough freezes the streak survives and still advances; without them it
//    restarts at 1.
//  * Opening the app settles the same arithmetic (`reconcile`) so the number on
//    screen is honest before the next session rather than only after it.
//
//  One deliberate asymmetry: **only `recordTraining` ever spends a freeze.**
//  `reconcile` decides whether the streak is still defensible and breaks it if
//  it isn't, but it never debits the wallet. A freeze is a thing the player
//  earned or paid for, and it should only be consumed at the moment it
//  demonstrably rescues a streak — not drained a day at a time by someone who
//  opens the app, doesn't train, and never comes back.
//

import Foundation
import SwiftData

@MainActor
enum StreakEngine {

    /// What a streak evaluation did, so callers can drive celebration UI and
    /// copy without re-deriving it.
    struct Outcome {
        /// The streak value after the evaluation.
        var streak: Int
        /// True when the streak counter moved as a result of this training
        /// event (false for a second session on a day already counted).
        var didAdvance: Bool
        /// Freezes spent to bridge missed days during this evaluation.
        var freezesUsed: Int
        /// True when the gap was too long to defend and the streak restarted.
        var didReset: Bool

        /// True when it is honest to show a "+1" next to the streak.
        var showsIncrement: Bool { didAdvance && !didReset }
    }

    // MARK: - Public API

    /// Settle a stale streak against the current date **without** recording any
    /// training and without spending anything. Safe and cheap to call on every
    /// launch and foreground, and idempotent within a day.
    ///
    /// Returns `true` when it changed something worth saving.
    @discardableResult
    static func reconcile(
        _ player: PlayerState,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        guard player.streak > 0, let last = player.lastTrainedDate else { return false }

        let missed = missedDays(since: last, now: now, calendar: calendar)
        // The streak is only broken once the missed days outrun the freezes the
        // player is holding. Nothing is debited here — see the note above.
        guard missed > player.freezesRemaining else { return false }

        player.streak = 0
        return true
    }

    /// Record that the player trained at `now` and advance the streak by the
    /// rules above. Also maintains `streakPB` and awards milestone freezes,
    /// which every previous caller either duplicated or forgot.
    @discardableResult
    static func recordTraining(
        _ player: PlayerState,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Outcome {
        var freezesUsed = 0
        var didReset = false

        if player.streak > 0, let last = player.lastTrainedDate {
            if calendar.isDate(last, inSameDayAs: now) {
                // Already counted today. Refresh the timestamp so "last trained"
                // stays accurate, but don't advance the streak a second time.
                player.lastTrainedDate = now
                return Outcome(streak: player.streak, didAdvance: false, freezesUsed: 0, didReset: false)
            }

            let missed = missedDays(since: last, now: now, calendar: calendar)
            if missed == 0 {
                // Trained yesterday — an unbroken run.
                player.streak += 1
            } else if missed <= player.freezesRemaining {
                // Freezes cover every missed day, so the run survives.
                player.freezesRemaining -= missed
                freezesUsed = missed
                player.streak += 1
            } else {
                player.streak = 1
                didReset = true
            }
        } else {
            // First ever session, resuming after a broken streak, or a restored
            // account whose streak came down without a last-trained date. Any
            // non-trivial prior streak being replaced by 1 is a reset, and the
            // post-session screen must not claim "+1" for it.
            didReset = player.streak > 1
            player.streak = 1
        }

        player.lastTrainedDate = now
        player.streakPB = max(player.streakPB, player.streak)
        awardMilestoneFreezes(player)

        return Outcome(
            streak: player.streak,
            didAdvance: true,
            freezesUsed: freezesUsed,
            didReset: didReset
        )
    }

    // MARK: - Internals

    /// Whole days that passed with no training between `last` and today,
    /// excluding today itself — the player still has today to train.
    ///
    /// Uses `Calendar` day arithmetic rather than dividing a time interval, so
    /// DST transitions and timezone changes can't produce a 23- or 25-hour
    /// "day". Clamped at 0 so a clock moved backwards can't return a negative.
    private static func missedDays(since last: Date, now: Date, calendar: Calendar) -> Int {
        let gap = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: last),
            to: calendar.startOfDay(for: now)
        ).day ?? 0
        return max(0, gap - 1)
    }

    /// Milestone freeze rewards, clamped to the store's cap so the counter can
    /// never exceed the three dots the UI draws.
    private static func awardMilestoneFreezes(_ player: PlayerState) {
        let cap = XPStoreService.maxFreezes
        switch player.streak {
        case 7:
            if player.freezesRemaining < 1 { player.freezesRemaining = min(cap, player.freezesRemaining + 1) }
        case 30:
            if player.freezesRemaining < 2 { player.freezesRemaining = min(cap, 2) }
        case 50:
            player.freezesRemaining = min(cap, player.freezesRemaining + 1)
        default:
            break
        }
    }
}
