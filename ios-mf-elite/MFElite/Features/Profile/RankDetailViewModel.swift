//
//  RankDetailViewModel.swift
//  MFElite
//
//  Reconciles the player's rank XP against the records that actually produced
//  it — the session log, watch workouts, and the purchased-XP ledger — instead
//  of re-estimating it from mastery state.
//

import Foundation
import Observation

/// A single labelled XP source row in the breakdown.
struct XPBreakdownRow: Identifiable {
    let id = UUID()
    let label: String
    /// Plain-language basis for the figure, e.g. "142 sessions logged".
    let detail: String
    let total: Int
}

@MainActor
@Observable
final class RankDetailViewModel {
    let disciplines: [Discipline]
    /// `PlayerState.xp` — everything the player earned: training, watch
    /// workouts, share bonuses, coach credits.
    let earnedXP: Int
    /// `PlayerState.purchasedXP` — store XP. Counts toward rank only, which is
    /// why it belongs in this screen's total but never on a leaderboard.
    let purchasedXP: Int
    private let sessions: [SessionLogEntry]
    private let workouts: [WorkoutRecord]

    init(
        disciplines: [Discipline],
        earnedXP: Int,
        purchasedXP: Int,
        sessions: [SessionLogEntry],
        workouts: [WorkoutRecord]
    ) {
        self.disciplines = disciplines.sorted { $0.sortIndex < $1.sortIndex }
        self.earnedXP = earnedXP
        self.purchasedXP = purchasedXP
        self.sessions = sessions
        self.workouts = workouts
    }

    /// The headline figure, and the only number the breakdown is allowed to sum
    /// to. Identical to `PlayerState.rankXP`, which every other rank surface reads.
    var rankXP: Int { earnedXP + purchasedXP }

    // MARK: - Rank

    private var hasFullAccess: Bool { SubscriptionService.shared.hasFullAccess }

    var currentRank: AcademyRank { AcademyRank.unlockedRank(for: rankXP, hasFullAccess: hasFullAccess) }
    var nextRank: AcademyRank? { AcademyRank.nextRank(for: rankXP, hasFullAccess: hasFullAccess) }
    var xpToNext: Int? { AcademyRank.xpToNext(for: rankXP, hasFullAccess: hasFullAccess) }
    var hasLockedEarnedRank: Bool { AcademyRank.hasLockedEarnedRank(for: rankXP, hasFullAccess: hasFullAccess) }

    var progressToNext: Double {
        guard let next = nextRank else { return 1 }
        let floorXP = currentRank.rawValue
        let span = next.rawValue - floorXP
        guard span > 0 else { return 1 }
        return min(1, max(0, Double(rankXP - floorXP) / Double(span)))
    }

    // MARK: - Breakdown
    //
    // Each row is read back from a record the device actually holds — one
    // `SessionLogEntry` per completed drill or lesson (with the weekend booster
    // already applied to `xpEarned`), one `WorkoutRecord` per wrist workout, and
    // the running purchased-XP balance. Counting mastered drills instead, as this
    // screen used to, contradicted the headline in both directions: it charged
    // 25 XP for the two logged passes that never earned it, invented discipline
    // diplomas the app has never awarded, and ignored workouts and store XP
    // entirely.
    //
    // Milestone bonuses, share XP and coach credits leave no local record — they
    // are folded straight into `PlayerState.xp` — so they are reported as one
    // named remainder rather than smeared across the rows above.

    /// Game IQ lessons are logged as sessions under a synthetic drill id
    /// (see `GameIQStore`); that prefix is the only thing separating them from
    /// drill sessions.
    private static let gameIQPrefix = "gameiq-"

    private var drillSessions: [SessionLogEntry] {
        sessions.filter { !$0.drillID.hasPrefix(Self.gameIQPrefix) }
    }

    private var lessonSessions: [SessionLogEntry] {
        sessions.filter { $0.drillID.hasPrefix(Self.gameIQPrefix) }
    }

    private var drillXP: Int { drillSessions.reduce(0) { $0 + $1.xpEarned } }
    private var lessonXP: Int { lessonSessions.reduce(0) { $0 + $1.xpEarned } }
    private var workoutXP: Int { workouts.reduce(0) { $0 + $1.xpEarned } }

    /// The part of the headline no record on this device explains: level and
    /// certification bonuses (awarded straight to `PlayerState.xp` at the moment
    /// of crossing), share XP, coach adjustments, and anything earned before
    /// this device had history to merge.
    ///
    /// It can legitimately come out negative — a coach correction can lower the
    /// total below what the local log adds up to, and session history merged
    /// from another device arrives without the XP that went with it. Showing the
    /// shortfall is better than clamping it and printing a total that lies.
    private var unattributedXP: Int {
        rankXP - (drillXP + lessonXP + workoutXP + purchasedXP)
    }

    var breakdownRows: [XPBreakdownRow] {
        // The drills row always shows, even at zero, so a new player still sees
        // where XP is going to come from.
        var rows = [
            XPBreakdownRow(
                label: "Drills logged",
                detail: Self.sessionCountDetail(drillSessions.count),
                total: drillXP
            )
        ]

        if lessonXP != 0 {
            rows.append(XPBreakdownRow(
                label: "Game IQ lessons",
                detail: Self.lessonCountDetail(lessonSessions.count),
                total: lessonXP
            ))
        }

        if workoutXP != 0 {
            rows.append(XPBreakdownRow(
                label: "Runs & workouts",
                detail: Self.workoutCountDetail(workouts.count),
                total: workoutXP
            ))
        }

        if purchasedXP != 0 {
            rows.append(XPBreakdownRow(
                label: "Store XP",
                detail: "XP packs and coach credits · rank only",
                total: purchasedXP
            ))
        }

        let remainder = unattributedXP
        if remainder > 0 {
            rows.append(XPBreakdownRow(
                label: "Milestones & other",
                detail: "Level and certification bonuses, share and coach XP",
                total: remainder
            ))
        } else if remainder < 0 {
            rows.append(XPBreakdownRow(
                label: "Adjustments",
                detail: "Coach corrections and history synced from other devices",
                total: remainder
            ))
        }

        return rows
    }

    // The total shown under the rows is summed from the rows themselves, in the
    // view, rather than read from `rankXP`. If the reconciliation above ever
    // breaks, the discrepancy shows on screen instead of being papered over.

    // MARK: - XP by discipline

    /// Training XP logged against one discipline. Watch workouts, store XP and
    /// the unattributed remainder belong to no discipline, so these rows add up
    /// to the training rows of the breakdown — not to the headline.
    func xp(for discipline: Discipline) -> Int {
        let disciplineID = discipline.id
        return sessions
            .filter { $0.disciplineID == disciplineID }
            .reduce(0) { $0 + $1.xpEarned }
    }

    // MARK: - Detail lines

    private static func sessionCountDetail(_ count: Int) -> String {
        "\(count.formatted()) \(count == 1 ? "session" : "sessions") logged"
    }

    private static func lessonCountDetail(_ count: Int) -> String {
        "\(count.formatted()) \(count == 1 ? "lesson" : "lessons") completed"
    }

    /// Deliberately device-agnostic: `WorkoutRecord` is now written by the
    /// phone's run tracker as well as the watch, so "from Apple Watch" would be
    /// wrong for a player who has never owned one.
    private static func workoutCountDetail(_ count: Int) -> String {
        "\(count.formatted()) \(count == 1 ? "workout" : "workouts") recorded"
    }
}
