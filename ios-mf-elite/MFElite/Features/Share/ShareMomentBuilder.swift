//
//  ShareMomentBuilder.swift
//  MFElite
//
//  Resolves real `ShareMoment` values from the app's live data models so the
//  gallery tiles and celebration deep-links render the player's actual
//  accomplishments. Every builder falls back to `ShareMoment.empty(_:)` when
//  the underlying data isn't available yet, so a card always has something to
//  show. All identity is first-name-only via `ShareMoment.currentPlayerLine()`.
//

import Foundation

@MainActor
enum ShareMomentBuilder {

    /// FIRST NAME · #kit · age band — resolved from the live profile.
    static var playerLine: String { ShareMoment.currentPlayerLine() }

    /// "JUL 10, 2026" style date stamp for the card corner.
    static func dateStamp(_ date: Date = Date()) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        f.dateFormat = "MMM d, yyyy"
        return f.string(from: date).uppercased()
    }

    // MARK: - Streak

    /// Streak milestone card for a given day count (used by the streak card and
    /// the milestone celebration, which both know the real count).
    static func streak(days: Int, date: Date = Date()) -> ShareMoment {
        guard days > 0 else { return .empty(.streak, playerLine: playerLine) }
        let badge: String
        let title: String
        switch days {
        case ..<7:   badge = "medal_flame_badge_7";  title = "ON THE GRIND"
        case ..<30:  badge = "medal_flame_badge_7";  title = "ON FIRE"
        case ..<50:  badge = "medal_flame_badge_30"; title = "NO DAYS OFF"
        case ..<100: badge = "medal_lightning_badge_50"; title = "RELENTLESS"
        default:     badge = "medal_badge_100_crown"; title = "DIFFERENT ANIMAL"
        }
        return ShareMoment(
            kind: .streak,
            data: .streak(count: days, unit: "DAY STREAK", title: title, badge: badge, date: dateStamp(date)),
            playerLine: playerLine
        )
    }

    // MARK: - Weekly recap

    /// Weekly-recap card from a computed `WeekRecap`.
    static func weeklyRecap(_ recap: WeekRecap) -> ShareMoment {
        // Always real: shows this week's actual numbers (zeros are honest, not faked).
        var grid = [
            ShareStat(key: "SESSIONS", value: recap.sessions),
            ShareStat(key: "MINUTES", value: recap.minutes),
            ShareStat(key: "DRILLS", value: recap.drills),
            ShareStat(key: "STREAK", value: recap.streak),
        ]
        if let steps = WeeklyHealthStats.shared.weekSteps {
            grid.append(ShareStat(key: "STEPS", value: steps))
        }
        if let miles = WeeklyHealthStats.shared.weekMiles {
            grid.append(ShareStat(key: "MILES", value: Int(miles.rounded())))
        }
        return ShareMoment(
            kind: .weeklyRecap,
            data: .weeklyRecap(xp: recap.xp, grid: grid),
            playerLine: playerLine
        )
    }

    // MARK: - Combine result

    /// Single combine-test result card. `value` is the score to feature (the
    /// just-saved attempt or a personal best). Delta and tier are resolved from
    /// the result history and the bundled benchmarks when possible.
    static func combineResult(test: CombineTest, value: Double, results: [CombineResult] = []) -> ShareMoment {
        let valueText = CombineFormat.value(value, unit: test.unit)
        let unit = test.unit == "seconds" ? "SEC" : test.unit.uppercased()

        let history = results
            .filter { $0.testID == test.id }
            .sorted { $0.recordedAt < $1.recordedAt }

        // Delta against the attempt immediately BEFORE the one being featured.
        // This used to be `dropLast().last`, i.e. the second-most-recent attempt
        // regardless of which result the card was showing — so featuring a
        // personal best set three attempts ago compared two unrelated numbers,
        // and a history of 4.5 / 3.9(PB) / 4.3 made the card read "First
        // recorded result" for a player with three attempts.
        let featuredIndex = history.lastIndex { $0.value == value }
        let previous: Double? = {
            guard let featuredIndex, featuredIndex > 0 else { return nil }
            return history[featuredIndex - 1].value
        }()

        var deltaText = history.count <= 1 ? "First recorded result" : "Personal best"
        if let previous {
            if previous == value {
                deltaText = "Matches your best"
            } else {
                let diff = value - previous
                let improved = test.lowerIsBetter ? diff < 0 : diff > 0
                let magnitude = CombineFormat.value(abs(diff), unit: test.unit)
                deltaText = "\(improved ? "▲" : "▼") \(magnitude) vs previous"
            }
        }

        // Is the featured value actually the player's best for this test?
        // The card's headline claimed "NEW PERSONAL BEST" unconditionally, so
        // logging a worse score and tapping Share announced a PB that wasn't.
        let isPersonalBest: Bool = {
            guard let best = CombineStats.personalBest(test, results: results) else { return true }
            return value == best
        }()

        // Shareables show the raw result only — no population comparison / percentile.
        let pct = 0
        let pctLabel = ""

        return ShareMoment(
            kind: .combineResult,
            data: .combineResult(
                test: test.name, value: valueText, unit: unit,
                delta: deltaText, pct: pct, pctLabel: pctLabel,
                isPersonalBest: isPersonalBest
            ),
            playerLine: playerLine
        )
    }

    // MARK: - Combine scorecard

    /// Whole-combine scorecard from every test with at least one result. Returns
    /// a sample card when the player has no combine data yet.
    static func combineScorecard(tests: [CombineTest], results: [CombineResult], including: Set<String>? = nil) -> ShareMoment {
        let benchmarks = CombineBenchmarks.shared
        let profile = PlayerProfileStore.shared
        let age = profile.age
        let band = age.flatMap { benchmarks.ageBand(for: $0) }

        var rows: [ShareScoreRow] = []
        var pcts: [Int] = []
        for test in tests {
            if let including, !including.contains(test.id) { continue }
            guard let best = CombineStats.personalBest(test, results: results) else { continue }
            // Grade against the player's own scale. This was hardcoded to the
            // male tables while CombineScorecardView reads the real setting, so
            // a girl's shared OVR disagreed with the one in the app — and was
            // understated by roughly 20 points per physical test.
            var pct = 0
            if let band,
               let tier = benchmarks.tier(
                    testID: test.id, value: best, bandID: band.id, female: profile.gradesFemale
               ) {
                pct = tierPercent(tier)
                pcts.append(pct)
            }
            rows.append(ShareScoreRow(
                name: test.name,
                value: CombineFormat.value(best, unit: test.unit),
                pct: pct
            ))
        }

        guard !rows.isEmpty else { return .empty(.combineScorecard, playerLine: playerLine) }
        // With no birth year there is no age band, so nothing can be graded.
        // This used to default every row to 50 and print a confident "50 OVR"
        // the player never earned. 0 tells the body to omit the figure.
        let overall = pcts.isEmpty
            ? 0
            : Int((Double(pcts.reduce(0, +)) / Double(pcts.count)).rounded())
        return ShareMoment(
            kind: .combineScorecard,
            data: .combineScorecard(overall: overall, rows: rows),
            playerLine: playerLine
        )
    }

    // MARK: - Level mastered

    /// Level-mastered card. Used by the celebration, which knows the real level.
    static func levelMastered(levelNumber: Int, totalLevels: Int, drillName: String, category: String, sessions: Int) -> ShareMoment {
        ShareMoment(
            kind: .levelMastered,
            data: .levelMastered(
                badge: "medal_trophy_badge",
                level: levelNumber,
                of: max(totalLevels, levelNumber),
                drill: drillName,
                category: category,
                sessions: max(sessions, 1)
            ),
            playerLine: playerLine
        )
    }

    // MARK: - Badge

    /// Badge-unlocked card for a specific achievement badge.
    static func badge(_ badge: AchievementBadge, date: Date = Date()) -> ShareMoment {
        let content = badgeContent(badge)
        return ShareMoment(
            kind: .badge,
            data: .badge(image: content.image, big: content.big, unit: content.unit, title: content.title, date: dateStamp(date)),
            playerLine: playerLine
        )
    }

    /// The most impressive earned badge, or nil when the locker is empty.
    static func bestEarnedBadge() -> AchievementBadge? {
        badgePriority.first { AchievementStore.isEarned($0) }
    }

    // MARK: - Invite

    /// Invite-a-friend card. Uses a stable per-player code derived from the
    /// profile so it's consistent between launches (backend linking lands later).
    static func invite() -> ShareMoment {
        ShareMoment(
            kind: .invite,
            data: .invite(
                line1: "COME TRAIN",
                line2: "WITH ME",
                code: inviteCode(),
                body: "Daily drills, streaks and combine tests. Scan the code to start training with me on MF Elite."
            ),
            playerLine: playerLine
        )
    }

    // MARK: - Rep the badge

    static func repBadge(headlineIndex: Int = 0) -> ShareMoment {
        ShareMoment(
            kind: .repBadge,
            data: .repBadge(headlineIndex: headlineIndex),
            playerLine: playerLine
        )
    }

    // MARK: - Player card

    /// Player-card showcase built entirely from real data — no invented rating or
    /// attribute numbers. The hero number is the player's jersey number (falling
    /// back to drills mastered); the six cells are real training milestones.
    static func playerCard(player: PlayerState?, progress: [DrillProgress], sessions: [SessionLogEntry]) -> ShareMoment {
        let profile = PlayerProfileStore.shared
        let position = profile.positionCode.isEmpty ? "MF" : profile.positionCode.uppercased()
        let name = ShareText.firstName(profile.displayName).uppercased()

        let mastered = progress.filter { $0.isMastered }.count
        let streak = player?.streak ?? 0
        let sessionCount = sessions.count
        let minutes = sessions.map(\.durationSec).reduce(0, +) / 60
        let distinctDrills = Set(sessions.map { $0.drillID }).count
        let badges = earnedBadgeCount()

        let kit = Int(profile.kitNumber.trimmingCharacters(in: .whitespaces))
        let heroNumber = kit ?? mastered

        let stats = [
            ShareStat(key: "STREAK", value: streak),
            ShareStat(key: "MASTERED", value: mastered),
            ShareStat(key: "SESSIONS", value: sessionCount),
            ShareStat(key: "MINUTES", value: minutes),
            ShareStat(key: "DRILLS", value: distinctDrills),
            ShareStat(key: "BADGES", value: badges),
        ]
        return ShareMoment(
            kind: .playerCard,
            data: .playerCard(rating: heroNumber, position: position, name: name, club: "MF ELITE", stats: stats),
            playerLine: playerLine
        )
    }

    /// Count of achievement badges the player has actually earned.
    static func earnedBadgeCount() -> Int {
        badgePriority.filter { AchievementStore.isEarned($0) }.count
    }

    // MARK: - Gallery resolver

    /// Builds the best available real moment for a gallery tile, falling back to
    /// a sample when the player hasn't generated that data yet.
    static func galleryMoment(
        _ kind: ShareMomentKind,
        players: [PlayerState],
        progress: [DrillProgress],
        combineResults: [CombineResult],
        combineTests: [CombineTest],
        sessions: [SessionLogEntry]
    ) -> ShareMoment {
        let player = players.first
        switch kind {
        case .streak:
            return streak(days: player?.streak ?? 0)
        case .weeklyRecap:
            let recap = WeekRecap(sessions: sessions, currentXP: player?.xp ?? 0, currentStreak: player?.streak ?? 0)
            return weeklyRecap(recap)
        case .combineResult:
            if let (test, value) = bestCombineHighlight(tests: combineTests, results: combineResults) {
                return combineResult(test: test, value: value, results: combineResults)
            }
            return .empty(.combineResult, playerLine: playerLine)
        case .combineScorecard:
            return combineScorecard(tests: combineTests, results: combineResults)
        case .badge:
            if let badge = bestEarnedBadge() { return self.badge(badge) }
            return .empty(.badge, playerLine: playerLine)
        case .playerCard:
            return playerCard(player: player, progress: progress, sessions: sessions)
        case .invite:
            return invite()
        case .repBadge:
            return repBadge()
        case .levelMastered:
            // No cheap "most recently mastered level" lookup here — the real card
            // is deep-linked from the mastery celebration; the tile previews a sample.
            return .empty(.levelMastered, playerLine: playerLine)
        }
    }

    /// Whether a gallery card is "earned" and openable. The four always-on cards
    /// (player card, weekly recap, invite, rep the badge) are never locked; the
    /// rest unlock once the player has generated the underlying accomplishment.
    static func isEarned(
        _ kind: ShareMomentKind,
        players: [PlayerState],
        progress: [DrillProgress],
        combineResults: [CombineResult],
        combineTests: [CombineTest]
    ) -> Bool {
        // Every card is always viewable. Cards without underlying data render
        // their sample/empty state — that is intentional product behavior.
        return true
    }

    // MARK: - Helpers

    /// Maps a benchmark tier to a 0–100 fill for the card's percentile bar.
    private static func tierPercent(_ tier: CombineTier) -> Int {
        switch tier {
        case .recreational: return 25
        case .club:         return 45
        case .competitive:  return 65
        case .elite:        return 85
        case .proLevel:     return 97
        }
    }

    /// The test + value to feature on the combine-result tile: the player's most
    /// recently recorded test, using its personal best.
    private static func bestCombineHighlight(tests: [CombineTest], results: [CombineResult]) -> (CombineTest, Double)? {
        guard let latest = results.max(by: { $0.recordedAt < $1.recordedAt }),
              let test = tests.first(where: { $0.id == latest.testID }),
              let best = CombineStats.personalBest(test, results: results) else { return nil }
        return (test, best)
    }

    /// Stable, per-player invite code (e.g. "LEO-4821") derived from the profile.
    private static func inviteCode() -> String {
        let profile = PlayerProfileStore.shared
        let name = ShareText.firstName(profile.displayName).uppercased()
        let seed = "\(profile.displayName)|\(profile.kitNumber)"
        var hash: UInt64 = 5381
        for scalar in seed.unicodeScalars { hash = (hash &* 33) &+ UInt64(scalar.value) }
        let number = Int(hash % 9000) + 1000
        let prefix = String(name.prefix(4))
        return "\(prefix)-\(number)"
    }

    /// Earned badges ranked most-impressive first, for picking a hero badge.
    private static let badgePriority: [AchievementBadge] = [
        .hundredDayStreak, .hundredDrills, .fiftyMastered, .fiftyDayStreak,
        .perfectDay30, .monthStreak, .fiftyDrills, .firstCert, .tenMastered,
        .perfectWeek, .perfectDay7, .weekStreak, .tenDrills, .firstMastery,
        .earlyBird, .nightOwl, .perfectDay, .firstDrill,
    ]

    /// Card content (image, big numeral, unit, title) for each badge.
    private static func badgeContent(_ badge: AchievementBadge) -> (image: String, big: String, unit: String, title: String) {
        switch badge {
        case .firstDrill:       return ("medal_badge_10_soccer", "1", "DRILL", "FIRST REP")
        case .tenDrills:        return ("medal_badge_10_soccer", "10", "DRILLS", "GETTING STARTED")
        case .fiftyDrills:      return ("medal_badge_50", "50", "DRILLS", "COMMITTED")
        case .hundredDrills:    return ("medal_badge_100_crown", "100", "SESSIONS", "CENTURY CLUB")
        case .firstMastery:     return ("achievement_medal_rings", "1", "MASTERED", "FIRST MASTERY")
        case .tenMastered:      return ("achievement_medal_rings", "10", "MASTERED", "SHARPENING")
        case .fiftyMastered:    return ("medal_trophy_badge", "50", "MASTERED", "ELITE FORM")
        case .weekStreak:       return ("medal_flame_badge_7", "7", "DAY STREAK", "WEEK ONE")
        case .monthStreak:      return ("medal_flame_badge_30", "30", "DAY STREAK", "THE MONTH")
        case .fiftyDayStreak:   return ("medal_lightning_badge_50", "50", "DAY STREAK", "FIFTY")
        case .hundredDayStreak: return ("medal_badge_100_crown", "100", "DAY STREAK", "CENTURION")
        case .perfectWeek:      return ("weekly_xp_leaderboard", "7", "PERFECT DAYS", "PERFECT WEEK")
        case .firstCert:        return ("medal_trophy_badge", "1", "CERTIFIED", "CERTIFIED")
        case .earlyBird:        return ("medal_football_dawn", "AM", "GRIND", "EARLY BIRD")
        case .nightOwl:         return ("moon_stars_medal_badge", "PM", "GRIND", "NIGHT OWL")
        case .perfectDay:       return ("achievement_medal_rings", "1", "PERFECT DAY", "PERFECT DAY")
        case .perfectDay7:      return ("achievement_medal_rings", "7", "PERFECT DAYS", "SEVEN PERFECT")
        case .perfectDay30:     return ("achievement_medal_rings", "30", "PERFECT DAYS", "THIRTY PERFECT")
        }
    }
}
