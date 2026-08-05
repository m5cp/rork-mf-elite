//
//  ShareMoment.swift
//  MFElite
//
//  The nine shareable "moments" and the data each card body renders. Card bodies
//  are laid out from this model in `MFShareCardV2`. Player identity (first name,
//  kit, age band) is pulled from `PlayerProfileStore` so the on-card player line
//  is always real and first-name-only; the accomplishment specifics are wired to
//  the app's data models per moment.
//

import SwiftUI

// MARK: - Moment kind

/// The nine card types. The first eight come from the design handoff; `repBadge`
/// is the brand card that ships anytime, tied to no accomplishment.
enum ShareMomentKind: String, CaseIterable, Identifiable {
    case badge
    case streak
    case playerCard
    case combineResult
    case combineScorecard
    case levelMastered
    case weeklyRecap
    case invite
    case repBadge

    var id: String { rawValue }

    /// Gallery / debug label.
    var label: String {
        switch self {
        case .badge:            return "Badge Unlocked"
        case .streak:           return "Streak Milestone"
        case .playerCard:       return "Player Card"
        case .combineResult:    return "Combine Result"
        case .combineScorecard: return "Combine Scorecard"
        case .levelMastered:    return "Level Mastered"
        case .weeklyRecap:      return "Weekly Recap"
        case .invite:           return "Invite a Friend"
        case .repBadge:         return "Rep The Badge"
        }
    }

    /// Catalog image used for the gallery tile.
    var tileAsset: String {
        switch self {
        case .badge:            return "medal_badge_100_crown"
        case .streak:           return "medal_flame_badge_30"
        case .playerCard:       return "mf-logo-white"
        case .combineResult:    return "medal_lightning_badge_50"
        case .combineScorecard: return "achievement_medal_rings"
        case .levelMastered:    return "medal_badge_50"
        case .weeklyRecap:      return "medal_football_dawn"
        case .invite:           return "mf-logo-white"
        case .repBadge:         return "mf-logo-white"
        }
    }
}

// MARK: - Body data

/// A single stat cell on the player card / recap grids.
struct ShareStat: Equatable {
    let key: String
    let value: Int
}

/// A single row on the combine scorecard.
struct ShareScoreRow: Equatable {
    let name: String
    let value: String
    /// 0–100 fill for the mini bar.
    let pct: Int
}

/// The body payload for each moment, carrying only what that body renders.
enum ShareMomentData: Equatable {
    case badge(image: String, big: String, unit: String, title: String, date: String)
    case streak(count: Int, unit: String, title: String, badge: String, date: String)
    case playerCard(rating: Int, position: String, name: String, club: String, stats: [ShareStat])
    case combineResult(test: String, value: String, unit: String, delta: String, pct: Int, pctLabel: String, isPersonalBest: Bool)
    case combineScorecard(overall: Int, rows: [ShareScoreRow])
    case levelMastered(badge: String, level: Int, of: Int, drill: String, category: String, sessions: Int)
    case weeklyRecap(xp: Int, grid: [ShareStat])
    case invite(line1: String, line2: String, code: String, body: String)
    case repBadge(headlineIndex: Int)
}

// MARK: - Moment

/// A fully-resolved moment ready to render on a card.
struct ShareMoment: Identifiable {
    let kind: ShareMomentKind
    let data: ShareMomentData
    /// e.g. "LEO · #10 · U14" — first name only.
    let playerLine: String

    var id: String { kind.rawValue }

    /// Rough natural body height in design px, used by the card's auto-fit so a
    /// body never overflows the space above the footer. Deliberately generous:
    /// overestimating only adds breathing room, it never clips.
    var naturalHeight: CGFloat {
        switch kind {
        case .badge:            return 1120
        case .streak:           return 1360
        case .playerCard:       return 900
        case .combineResult:    return 1040
        case .combineScorecard: return 1000
        case .levelMastered:    return 1140
        case .weeklyRecap:      return 1120
        case .invite:           return 980
        case .repBadge:         return 720
        }
    }
}

// MARK: - Rep-the-badge headlines

extension ShareMoment {
    /// Cyclable brand headlines for the "Rep The Badge" card. The last word is
    /// rendered in the theme accent color by the card body.
    static let repHeadlines: [String] = [
        "NO DAYS OFF",
        "TRAIN LIKE IT MATTERS",
        "EARN EVERYTHING",
        "THE GRIND IS MINE",
    ]
}

// MARK: - Builders

extension ShareMoment {
    /// The current player line from the real profile: FIRST NAME · #kit · age band.
    /// Uses `ShareText.firstName` so a surname is never exposed.
    @MainActor
    static func currentPlayerLine() -> String {
        let profile = PlayerProfileStore.shared
        var parts: [String] = [ShareText.firstName(profile.displayName).uppercased()]
        let kit = profile.kitNumber.trimmingCharacters(in: .whitespaces)
        if !kit.isEmpty { parts.append("#\(kit)") }
        if let age = profile.age, let band = CombineBenchmarks.shared.ageBand(for: age) {
            parts.append(band.id)
        }
        return parts.joined(separator: "  ·  ")
    }

    /// An honest "nothing yet" version of a card, for a player who hasn't
    /// generated the underlying accomplishment.
    ///
    /// Cards used to fall back to `sample(_:)` here, which meant a player with a
    /// zero streak who tapped the Streak tile got a card reading "30 · DAY
    /// STREAK · NO DAYS OFF", and a player with no badges got "100 SESSIONS ·
    /// CENTURY CLUB · JUL 10, 2026" — a hardcoded date. Those are shareable to
    /// Instagram, so the app was handing players a fabricated achievement to
    /// post as their own. `sample(_:)` is now for previews only.
    static func empty(_ kind: ShareMomentKind, playerLine: String) -> ShareMoment {
        let data: ShareMomentData
        switch kind {
        case .badge:
            data = .badge(image: "medal_badge_100_crown", big: "0", unit: "BADGES YET",
                          title: "FIRST ONE'S COMING", date: "")
        case .streak:
            data = .streak(count: 0, unit: "DAY STREAK", title: "DAY ONE STARTS NOW",
                           badge: "medal_flame_badge_30", date: "")
        case .combineResult:
            data = .combineResult(test: "MF COMBINE", value: "—", unit: "",
                                  delta: "No test recorded yet", pct: 0, pctLabel: "",
                                  isPersonalBest: false)
        case .combineScorecard:
            data = .combineScorecard(overall: 0, rows: [])
        case .levelMastered:
            data = .levelMastered(badge: "medal_trophy_badge", level: 0, of: 5,
                                  drill: "NOT YET", category: "KEEP TRAINING", sessions: 0)
        case .playerCard, .weeklyRecap, .invite, .repBadge:
            // These four are always built from real data (or need none), so an
            // empty state never renders for them — fall back to the real
            // builder's own zero output.
            return sample(kind, playerLine: playerLine)
        }
        return ShareMoment(kind: kind, data: data, playerLine: playerLine)
    }

    /// Sample data matching the design handoff — **previews only.** Do not use
    /// as a runtime fallback; see `empty(_:)`.
    static func sample(_ kind: ShareMomentKind, playerLine: String = "LEO  ·  #10  ·  U14") -> ShareMoment {
        let data: ShareMomentData
        switch kind {
        case .badge:
            data = .badge(image: "medal_badge_100_crown", big: "100", unit: "SESSIONS", title: "CENTURY CLUB", date: "JUL 10, 2026")
        case .streak:
            data = .streak(count: 30, unit: "DAY STREAK", title: "NO DAYS OFF", badge: "medal_flame_badge_30", date: "JUL 10, 2026")
        case .playerCard:
            data = .playerCard(
                rating: 87, position: "RW", name: "LEO", club: "MF ACADEMY",
                stats: [
                    ShareStat(key: "PACE", value: 91), ShareStat(key: "TOUCH", value: 85),
                    ShareStat(key: "PASS", value: 82), ShareStat(key: "DRIB", value: 90),
                    ShareStat(key: "SHOT", value: 84), ShareStat(key: "IQ", value: 88),
                ]
            )
        case .combineResult:
            data = .combineResult(test: "20M SPRINT", value: "3.12", unit: "SEC", delta: "-0.18s vs last test", pct: 92, pctLabel: "FASTER THAN 92% OF U14", isPersonalBest: true)
        case .combineScorecard:
            data = .combineScorecard(
                overall: 82,
                rows: [
                    ShareScoreRow(name: "20M SPRINT", value: "3.12s", pct: 92),
                    ShareScoreRow(name: "AGILITY 5-10-5", value: "5.48s", pct: 84),
                    ShareScoreRow(name: "JUGGLES 60S", value: "74", pct: 78),
                    ShareScoreRow(name: "WALL PASSES", value: "41", pct: 81),
                    ShareScoreRow(name: "SHOT SPEED", value: "58 mph", pct: 73),
                ]
            )
        case .levelMastered:
            data = .levelMastered(badge: "medal_trophy_badge", level: 4, of: 5, drill: "TIGHT-SPACE TOE TAPS", category: "BALL MASTERY", sessions: 9)
        case .weeklyRecap:
            data = .weeklyRecap(
                xp: 920,
                grid: [
                    ShareStat(key: "SESSIONS", value: 6), ShareStat(key: "MINUTES", value: 148),
                    ShareStat(key: "DRILLS", value: 23), ShareStat(key: "STREAK", value: 12),
                ]
            )
        case .invite:
            data = .invite(line1: "COME TRAIN", line2: "WITH ME", code: "LEO-4821", body: "Daily drills, streaks and combine tests. Scan the code to join my academy.")
        case .repBadge:
            data = .repBadge(headlineIndex: 0)
        }
        return ShareMoment(kind: kind, data: data, playerLine: playerLine)
    }
}
