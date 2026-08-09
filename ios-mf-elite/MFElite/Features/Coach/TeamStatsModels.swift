//
//  TeamStatsModels.swift
//  MFElite
//
//  The season stat sheet's data model and its rollup.
//
//  A coach files one report per game and nothing else. Every number the season
//  sheet shows is derived from those reports here, on device — no running
//  totals are stored anywhere. That is the whole point: when a coach discovers
//  that the goal in game 4 was actually an own goal, they fix game 4 and the
//  season corrects itself. A stored cumulative row would have to be recomputed,
//  and the moment one recompute is missed the sheet quietly lies.
//

import Foundation

// MARK: - A filed game report

/// How a game finished, from this team's side.
enum TeamStatResult: String, CaseIterable, Identifiable {
    case win = "W"
    case loss = "L"
    case draw = "D"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .win:  return "Win"
        case .loss: return "Loss"
        case .draw: return "Draw"
        }
    }

    /// The result a score implies. Used to keep the picker honest as the coach
    /// types the score, which is the order they actually fill the form in.
    static func from(goalsFor: Int, goalsAgainst: Int) -> TeamStatResult {
        if goalsFor > goalsAgainst { return .win }
        if goalsFor < goalsAgainst { return .loss }
        return .draw
    }
}

/// One player's line in one game report.
///
/// Stored as JSON on the report row rather than as its own table. The rollup
/// runs on device anyway (as every other Coach Mode aggregate does), a season
/// is around 25 rows per team, and one report is then one write — which
/// matters, because `SupabaseClient` posts a single row per request and a
/// twenty-five-player squad would otherwise be twenty-five round trips per
/// save. `progress_reports.sections` already works exactly this way.
///
/// Mapped by hand rather than through `Codable` so a report written by an
/// older build — one that never had `saves`, say — still loads. A synthesized
/// decoder throws on a missing key and would take the whole season's rollup
/// down with it; `as?` with a fallback just reads zero.
struct TeamStatLine: Identifiable, Equatable {
    var playerID: String
    /// Whether the player appeared in this game.
    ///
    /// Every average on the sheet divides by this, not by the team's game
    /// count: a striker who played 12 of 25 games and scored 12 goals averages
    /// a goal a game, and a squad player who never came on must not drag the
    /// division down for everyone.
    var played: Bool
    var goals: Int
    var assists: Int
    var saves: Int
    var goalsAllowed: Int
    var shutout: Bool

    var id: String { playerID }

    init(
        playerID: String,
        played: Bool = false,
        goals: Int = 0,
        assists: Int = 0,
        saves: Int = 0,
        goalsAllowed: Int = 0,
        shutout: Bool = false
    ) {
        self.playerID = playerID
        self.played = played
        self.goals = goals
        self.assists = assists
        self.saves = saves
        self.goalsAllowed = goalsAllowed
        self.shutout = shutout
    }

    init?(json: [String: Any]) {
        guard let playerID = json["player_id"] as? String, !playerID.isEmpty else { return nil }
        self.init(
            playerID: playerID,
            played: (json["played"] as? Bool) ?? false,
            goals: (json["goals"] as? Int) ?? 0,
            assists: (json["assists"] as? Int) ?? 0,
            saves: (json["saves"] as? Int) ?? 0,
            goalsAllowed: (json["goals_allowed"] as? Int) ?? 0,
            shutout: (json["shutout"] as? Bool) ?? false
        )
    }

    /// Snake-cased so the stored JSON reads like the rest of the schema when
    /// someone opens the row in the Supabase table editor.
    var jsonObject: [String: Any] {
        [
            "player_id": playerID,
            "played": played,
            "goals": goals,
            "assists": assists,
            "saves": saves,
            "goals_allowed": goalsAllowed,
            "shutout": shutout
        ]
    }

    /// Nothing recorded. Dropped before saving so the stored JSON only carries
    /// the players who were actually involved in that game.
    var isEmpty: Bool {
        !played && goals == 0 && assists == 0 && saves == 0 && goalsAllowed == 0 && !shutout
    }
}

/// One game, as the coach filed it.
struct TeamStatReport: Identifiable, Equatable {
    let id: String
    var teamID: String
    /// The `team_events` row this report covers, when the game was on the
    /// published schedule. Nil for a game the coach never scheduled — those
    /// still count as played, they just can't be "missing".
    var eventID: String?
    var season: String
    var gameDate: Date
    var opponent: String
    var result: TeamStatResult
    var goalsFor: Int
    var goalsAgainst: Int
    var lines: [TeamStatLine]

    /// A blank report for a new game, pre-populated with a line per roster
    /// player so the coach only has to tick who played.
    static func draft(teamID: String, season: String, roster: [TeamStatsPlayer]) -> TeamStatReport {
        TeamStatReport(
            id: UUID().uuidString,
            teamID: teamID,
            eventID: nil,
            season: season,
            gameDate: Date(),
            opponent: "",
            result: .win,
            goalsFor: 0,
            goalsAgainst: 0,
            lines: roster.map { TeamStatLine(playerID: $0.id) }
        )
    }

    /// The score as it reads on a results page.
    var scoreLine: String { "\(goalsFor)\u{2013}\(goalsAgainst)" }
}

// MARK: - Roster & schedule inputs

/// A roster player, with the two identity fields the printed sheet uses.
struct TeamStatsPlayer: Identifiable, Equatable {
    let id: String
    var displayName: String
    var kitNumber: String
    /// Graduation year from `player_profiles.class_year`; 0 when never set.
    var classYear: Int
}

/// A game already on the team's published schedule. The only reason the sheet
/// can say a report is *missing* rather than just absent.
struct TeamStatsScheduledGame: Identifiable, Equatable {
    let id: String
    var title: String
    var startsAt: Date
    var season: String
}

// MARK: - The cumulative sheet

/// One player's season line — the same row feeds all three player tables.
struct TeamStatsRow: Identifiable, Equatable {
    let id: String
    var displayName: String
    var number: String
    var grade: String
    var gamesPlayed: Int
    var goals: Int
    var assists: Int
    var saves: Int
    var goalsAllowed: Int
    var shutouts: Int

    /// Two points a goal, one an assist — the scoring the Kentucky high-school
    /// sheets this is modelled on use, and the US high-school convention
    /// generally. It is a convention, not arithmetic: if the owner's league
    /// counts a goal as one point, this is the single line to change.
    var points: Int { goals * 2 + assists }

    /// Per game played *by this player*, not per team game.
    private func perGame(_ total: Int) -> Double {
        gamesPlayed > 0 ? Double(total) / Double(gamesPlayed) : 0
    }

    var goalsAvg: Double { perGame(goals) }
    var assistsAvg: Double { perGame(assists) }
    var pointsAvg: Double { perGame(points) }
    var savesAvg: Double { perGame(saves) }
    var goalsAllowedAvg: Double { perGame(goalsAllowed) }
    var shutoutsAvg: Double { perGame(shutouts) }

    /// Only players who actually kept goal belong in the keeper table. A field
    /// player with a clean sheet ticked against their name is a mis-tap, not a
    /// goalkeeper, so shutouts alone don't qualify anyone.
    var isGoalkeeper: Bool { saves > 0 || goalsAllowed > 0 }
}

/// Everything the season sheet renders, rolled up from the filed reports.
struct TeamStatsSheet: Equatable {
    var teamName: String
    var season: String
    /// Games the team has played: past scheduled games, plus any reported game
    /// that was never on the schedule.
    var gamesPlayed: Int
    var reportsFiled: Int
    /// Past scheduled games with no report against them.
    var missingReports: Int
    var wins: Int
    var losses: Int
    var draws: Int
    var goalsScored: Int
    var goalsAllowed: Int
    /// Every roster player, in shirt-number order.
    var players: [TeamStatsRow]

    /// "18-5-2", or "18-5" when nothing was drawn.
    var record: String {
        draws > 0 ? "\(wins)-\(losses)-\(draws)" : "\(wins)-\(losses)"
    }

    /// Scoring table: anyone who has played, most goals first.
    var scoring: [TeamStatsRow] {
        players
            // Also anyone with a goal or an assist. A coach who taps the
            // steppers but forgets the Played toggle would otherwise have that
            // player vanish from Scoring entirely while their goals still count
            // toward the team total — the sheet contradicting itself.
            .filter { $0.gamesPlayed > 0 || $0.goals > 0 || $0.assists > 0 }
            .sorted { left, right in
                if left.goals != right.goals { return left.goals > right.goals }
                if left.points != right.points { return left.points > right.points }
                return left.displayName.localizedCaseInsensitiveCompare(right.displayName) == .orderedAscending
            }
    }

    /// Goalkeeper table: most saves first.
    var goalkeepers: [TeamStatsRow] {
        players
            .filter { $0.isGoalkeeper }
            .sorted { left, right in
                if left.saves != right.saves { return left.saves > right.saves }
                return left.displayName.localizedCaseInsensitiveCompare(right.displayName) == .orderedAscending
            }
    }

    /// Roll the filed reports up into the four sections of the sheet.
    ///
    /// `scheduledGameIDs` are the team's *past* game events for this season.
    /// They are what makes "missing stat reports" meaningful: a report is
    /// missing when a game the coach published has no report against it. A
    /// report with no scheduled game behind it is not an error — it is a game
    /// that was played and never put on the schedule — so it adds to games
    /// played rather than being ignored.
    static func build(
        teamName: String,
        season: String,
        roster: [TeamStatsPlayer],
        reports: [TeamStatReport],
        scheduledGameIDs: Set<String>
    ) -> TeamStatsSheet {
        let covered = Set(reports.compactMap { $0.eventID })
        let unscheduledReports = reports.filter { report in
            guard let eventID = report.eventID else { return true }
            return !scheduledGameIDs.contains(eventID)
        }

        var totals: [String: TeamStatsRow] = [:]
        for player in roster {
            totals[player.id] = TeamStatsRow(
                id: player.id,
                displayName: player.displayName,
                number: player.kitNumber.isEmpty ? "\u{2014}" : player.kitNumber,
                grade: TeamStatsFormat.grade(classYear: player.classYear),
                gamesPlayed: 0,
                goals: 0,
                assists: 0,
                saves: 0,
                goalsAllowed: 0,
                shutouts: 0
            )
        }

        var wins = 0
        var losses = 0
        var draws = 0
        var goalsScored = 0
        var goalsAgainstTotal = 0

        for report in reports {
            switch report.result {
            case .win:  wins += 1
            case .loss: losses += 1
            case .draw: draws += 1
            }
            goalsScored += report.goalsFor
            goalsAgainstTotal += report.goalsAgainst

            for line in report.lines {
                // A line for someone no longer on the roster is skipped rather
                // than invented into a row: the team tables list the current
                // squad, and the team totals above already carry that game's
                // goals either way.
                guard var row = totals[line.playerID] else { continue }
                if line.played { row.gamesPlayed += 1 }
                row.goals += line.goals
                row.assists += line.assists
                row.saves += line.saves
                row.goalsAllowed += line.goalsAllowed
                if line.shutout { row.shutouts += 1 }
                totals[line.playerID] = row
            }
        }

        let ordered = roster.compactMap { totals[$0.id] }

        return TeamStatsSheet(
            teamName: teamName,
            season: season,
            gamesPlayed: scheduledGameIDs.count + unscheduledReports.count,
            reportsFiled: reports.count,
            missingReports: scheduledGameIDs.subtracting(covered).count,
            wins: wins,
            losses: losses,
            draws: draws,
            goalsScored: goalsScored,
            goalsAllowed: goalsAgainstTotal,
            players: ordered
        )
    }
}

// MARK: - Formatting

enum TeamStatsFormat {

    /// Averages read as two decimals, the way the printed sheet does.
    static func avg(_ value: Double) -> String {
        guard value.isFinite else { return "0.00" }
        return String(format: "%.2f", value)
    }

    /// The season a date belongs to.
    ///
    /// A bare calendar year, matching the owner's own sheet ("2025 KY Girls
    /// Soccer Stats"). Right for a fall or a spring season; a winter league
    /// running across New Year would be split in two, which is the one case to
    /// revisit if it ever comes up.
    static func season(for date: Date) -> String {
        String(Calendar.current.component(.year, from: date))
    }

    /// US school grade for a graduation year, or an em dash when we can't tell.
    ///
    /// `player_profiles.class_year` is the year the athlete graduates — that is
    /// what onboarding asks for ("You are now Class of 2029"). Grade counts
    /// back from senior year against the school year we are currently in, and
    /// the school year is treated as rolling over in July so that an August
    /// game already belongs to the new one.
    static func grade(classYear: Int, on date: Date = Date()) -> String {
        guard classYear > 1900 else { return "\u{2014}" }
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        let schoolYearEnd = month >= 7 ? year + 1 : year
        let grade = 12 - (classYear - schoolYearEnd)
        guard grade >= 1, grade <= 12 else { return "\u{2014}" }
        return String(grade)
    }

    /// Shirt-number order, with unnumbered players last and ties broken by name.
    static func sortRoster(_ players: [TeamStatsPlayer]) -> [TeamStatsPlayer] {
        players.sorted { left, right in
            let leftNumber = Int(left.kitNumber) ?? Int.max
            let rightNumber = Int(right.kitNumber) ?? Int.max
            if leftNumber != rightNumber { return leftNumber < rightNumber }
            return left.displayName.localizedCaseInsensitiveCompare(right.displayName) == .orderedAscending
        }
    }
}

// MARK: - Shareable text

/// Renders the sheet as plain text for the system share sheet, and as a short
/// summary for a team announcement. Same shape as `CoachExport`: read-only,
/// assembled entirely from data already on screen.
enum TeamStatsExport {

    static func sheetText(_ sheet: TeamStatsSheet) -> String {
        var lines: [String] = []

        lines.append("MF ELITE \u{2014} TEAM STATS")
        lines.append("\(sheet.teamName) \u{00B7} \(sheet.season) \u{00B7} Cumulative Season")
        lines.append("\(sheet.gamesPlayed) game\(sheet.gamesPlayed == 1 ? "" : "s") played; \(sheet.reportsFiled) stat report\(sheet.reportsFiled == 1 ? "" : "s") filed")
        lines.append("")

        lines.append("TEAM STATS")
        lines.append("Games played: \(sheet.gamesPlayed)")
        lines.append("Stat reports filed: \(sheet.reportsFiled)")
        lines.append("Missing stat reports: \(sheet.missingReports)")
        lines.append("Win-loss record: \(sheet.record)")
        lines.append("Goals scored: \(sheet.goalsScored)")
        lines.append("Goals allowed: \(sheet.goalsAllowed)")
        lines.append("")

        let playerWidths = [18, 4, 4, 4]
        lines.append("PLAYERS")
        if sheet.players.isEmpty {
            lines.append("No players on this team yet.")
        } else {
            lines.append(row(["Player", "#", "Gr", "GP"], widths: playerWidths))
            for player in sheet.players {
                lines.append(row(
                    [player.displayName, player.number, player.grade, "\(player.gamesPlayed)"],
                    widths: playerWidths
                ))
            }
        }
        lines.append("")

        let scoringWidths = [18, 4, 4, 4, 4, 6, 4, 6, 5, 6]
        lines.append("SCORING")
        let scoring = sheet.scoring
        if scoring.isEmpty {
            lines.append("No scoring recorded yet.")
        } else {
            lines.append(row(["Player", "#", "Gr", "GP", "G", "G/G", "A", "A/G", "Pts", "P/G"],
                             widths: scoringWidths))
            for player in scoring {
                lines.append(row([
                    player.displayName,
                    player.number,
                    player.grade,
                    "\(player.gamesPlayed)",
                    "\(player.goals)",
                    TeamStatsFormat.avg(player.goalsAvg),
                    "\(player.assists)",
                    TeamStatsFormat.avg(player.assistsAvg),
                    "\(player.points)",
                    TeamStatsFormat.avg(player.pointsAvg)
                ], widths: scoringWidths))
            }
        }
        lines.append("")

        let keeperWidths = [18, 4, 4, 4, 5, 7, 4, 7, 4, 7]
        lines.append("GOALKEEPER")
        let keepers = sheet.goalkeepers
        if keepers.isEmpty {
            lines.append("No goalkeeper minutes recorded yet.")
        } else {
            lines.append(row(["Player", "#", "Gr", "GP", "Sv", "Sv/G", "GA", "GA/G", "SO", "SO/G"],
                             widths: keeperWidths))
            for player in keepers {
                lines.append(row([
                    player.displayName,
                    player.number,
                    player.grade,
                    "\(player.gamesPlayed)",
                    "\(player.saves)",
                    TeamStatsFormat.avg(player.savesAvg),
                    "\(player.goalsAllowed)",
                    TeamStatsFormat.avg(player.goalsAllowedAvg),
                    "\(player.shutouts)",
                    TeamStatsFormat.avg(player.shutoutsAvg)
                ], widths: keeperWidths))
            }
        }

        return lines.joined(separator: "\n")
    }

    /// The short version that goes out as a team announcement. The full sheet
    /// is far too long for a Today banner, and the coach can send that
    /// separately through the system share sheet.
    static func announcement(_ sheet: TeamStatsSheet) -> String {
        var parts: [String] = []
        parts.append("\(sheet.season) season \u{00B7} \(sheet.record) \u{00B7} \(sheet.goalsScored) scored, \(sheet.goalsAllowed) allowed across \(sheet.gamesPlayed) game\(sheet.gamesPlayed == 1 ? "" : "s").")
        let leaders = sheet.scoring.prefix(3).filter { $0.goals > 0 }
        if !leaders.isEmpty {
            let names = leaders.map { "\($0.displayName) (\($0.goals))" }
            parts.append("Leading scorers: \(names.joined(separator: ", ")).")
        }
        return parts.joined(separator: " ")
    }

    /// Pads each value into a fixed-width column so the text sheet still lines
    /// up when it lands in Messages or Notes.
    private static func row(_ values: [String], widths: [Int]) -> String {
        var out = ""
        for (index, value) in values.enumerated() {
            let width = index < widths.count ? widths[index] : 6
            out += pad(value, to: width)
        }
        while out.hasSuffix(" ") { out.removeLast() }
        return out
    }

    private static func pad(_ value: String, to width: Int) -> String {
        let limit = max(1, width - 1)
        let clipped = value.count > limit ? String(value.prefix(limit)) : value
        return clipped.padding(toLength: max(width, clipped.count + 1), withPad: " ", startingAt: 0)
    }
}
