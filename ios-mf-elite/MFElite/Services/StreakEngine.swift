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
//  * A streak is alive through the later of the last training day and the last
//    day covered by a spent freeze (`streakShieldedThrough`).
//  * Training on the same day it is already alive through changes nothing.
//  * Training the day after keeps it going: +1.
//  * Training after a longer gap spends one freeze per fully missed day. If
//    there are enough freezes the streak survives and still advances; if not,
//    the streak restarts at 1.
//  * Simply opening the app after a missed day settles the same arithmetic via
//    `reconcile`, so the number on screen is honest before the player trains
//    again rather than only being corrected on their next session.
//
//  Freezes are spent for whole missed days, never for the current day — the
//  player still has today to train.
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
    /// training. Safe and cheap to call on every launch and foreground.
    ///
    /// Returns `true` when it changed something worth saving.
    @discardableResult
    static func reconcile(
        _ player: PlayerState,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        guard player.streak > 0, let alive = aliveThrough(player, calendar) else { return false }

        let gap = dayGap(from: alive, to: now, calendar)
        // gap 0 = alive today, gap 1 = alive yesterday and today is still open.
        guard gap >= 2 else { return false }

        let missedDays = gap - 1
        if player.freezesRemaining >= missedDays {
            player.freezesRemaining -= missedDays
            player.streakShieldedThrough = calendar.date(
                byAdding: .day, value: -1, to: calendar.startOfDay(for: now)
            )
        } else {
            player.streak = 0
            player.streakShieldedThrough = nil
        }
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
        var didAdvance = true

        if player.streak > 0, let alive = aliveThrough(player, calendar) {
            let gap = dayGap(from: alive, to: now, calendar)
            if gap <= 0 {
                // Already counted today. Refresh the timestamp so "last trained"
                // is accurate, but do not advance the streak a second time.
                player.lastTrainedDate = now
                return Outcome(streak: player.streak, didAdvance: false, freezesUsed: 0, didReset: false)
            } else if gap == 1 {
                player.streak += 1
            } else {
                let missedDays = gap - 1
                if player.freezesRemaining >= missedDays {
                    player.freezesRemaining -= missedDays
                    freezesUsed = missedDays
                    player.streak += 1
                } else {
                    player.streak = 1
                    didReset = true
                }
            }
        } else {
            // First ever session, or picking back up after a broken streak.
            didReset = player.streak == 0 && player.lastTrainedDate != nil
            player.streak = 1
        }

        player.lastTrainedDate = now
        // Any shield is consumed by actually training.
        player.streakShieldedThrough = nil
        player.streakPB = max(player.streakPB, player.streak)
        awardMilestoneFreezes(player)

        return Outcome(
            streak: player.streak,
            didAdvance: didAdvance,
            freezesUsed: freezesUsed,
            didReset: didReset
        )
    }

    /// True when the player has already banked a training day today, so a
    /// second session should not advance the streak again.
    static func hasTrainedToday(
        _ player: PlayerState,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        guard let last = player.lastTrainedDate else { return false }
        return calendar.isDate(last, inSameDayAs: now)
    }

    // MARK: - Internals

    /// The last calendar day the streak is known to be intact through: the
    /// later of the last training day and any day a spent freeze covered.
    private static func aliveThrough(_ player: PlayerState, _ calendar: Calendar) -> Date? {
        let trained = player.lastTrainedDate.map { calendar.startOfDay(for: $0) }
        let shielded = player.streakShieldedThrough.map { calendar.startOfDay(for: $0) }
        switch (trained, shielded) {
        case let (trained?, shielded?): return max(trained, shielded)
        case let (trained?, nil):       return trained
        case let (nil, shielded?):      return shielded
        case (nil, nil):                return nil
        }
    }

    /// Whole calendar days between two instants. Uses `Calendar` day arithmetic
    /// rather than dividing a time interval, so DST transitions and timezone
    /// changes don't produce a 23- or 25-hour "day".
    private static func dayGap(from: Date, to: Date, _ calendar: Calendar) -> Int {
        calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: from),
            to: calendar.startOfDay(for: to)
        ).day ?? 0
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
