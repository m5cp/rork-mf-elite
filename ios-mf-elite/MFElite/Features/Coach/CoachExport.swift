//
//  CoachExport.swift
//  MFElite
//
//  Builds a plain-text, shareable report of one player's progress for a coach.
//  Read-only — assembled entirely from already-loaded CoachPlayerDetail data.
//

import Foundation

/// Assembles a shareable text report for a single player.
enum CoachExport {
    static func report(for player: RosterPlayer, detail: CoachPlayerDetail) -> String {
        var lines: [String] = []

        // Header
        lines.append("MF ELITE — PLAYER REPORT")
        lines.append(player.displayName)
        var idParts: [String] = []
        if let username = player.username, !username.isEmpty { idParts.append("@\(username)") }
        if let kit = player.kitNumber, !kit.isEmpty { idParts.append("#\(kit)") }
        if let position = player.position, !position.isEmpty { idParts.append(position) }
        if !idParts.isEmpty { lines.append(idParts.joined(separator: " · ")) }
        if let email = player.email, !email.isEmpty { lines.append(email) }
        lines.append("Generated \(CoachFormat.shortDate(Date()))")
        lines.append("")

        // Progression
        lines.append("PROGRESSION")
        lines.append("XP: \(detail.xp)")
        lines.append("Current streak: \(detail.streak) day\(detail.streak == 1 ? "" : "s")")
        lines.append("Best streak: \(detail.streakPB)")
        lines.append("Last trained: \(CoachFormat.relative(detail.lastTrained))")
        lines.append("")

        // Training time
        lines.append("TRAINING TIME")
        lines.append("All time: \(CoachFormat.minutes(detail.minutesAllTime)) across \(detail.sessionCount) session\(detail.sessionCount == 1 ? "" : "s")")
        lines.append("Last 30 days: \(CoachFormat.minutes(detail.minutes30d))")
        lines.append("Last 7 days: \(CoachFormat.minutes(detail.minutes7d))")
        lines.append("")

        // Mastery
        lines.append("MASTERY — \(detail.totalMastered) drill\(detail.totalMastered == 1 ? "" : "s") mastered")
        if detail.masteryByDiscipline.isEmpty {
            lines.append("None yet")
        } else {
            for item in detail.masteryByDiscipline {
                lines.append("• \(item.name): \(item.count)")
            }
        }
        lines.append("")

        // Combine
        if !detail.combineLatest.isEmpty {
            lines.append("LATEST COMBINE")
            for item in detail.combineLatest {
                lines.append("• \(item.name): \(CoachFormat.combineValue(item.value, unit: item.unit)) (\(CoachFormat.shortDate(item.date)))")
            }
            lines.append("")
        }

        // Game IQ
        lines.append("GAME IQ")
        lines.append("Lessons completed: \(detail.gameIQCompleted)")
        lines.append("")

        // Session history (most recent 20 to keep the report readable)
        lines.append("RECENT SESSIONS")
        if detail.history.isEmpty {
            lines.append("None yet")
        } else {
            for item in detail.history.prefix(20) {
                let rating = item.feltRating.map { " · felt \($0)/5" } ?? ""
                lines.append("• \(CoachFormat.shortDate(item.date)) — \(item.drillTitle) (\(CoachFormat.duration(item.durationSec)))\(rating)")
            }
            if detail.history.count > 20 {
                lines.append("…and \(detail.history.count - 20) more")
            }
        }

        return lines.joined(separator: "\n")
    }

    /// A short, shareable weekly team digest built from loaded overview data.
    static func weeklyDigest(_ overview: CoachOverview) -> String {
        let weekOf = CoachFormat.shortDate(
            Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        )
        var text = "MF Elite — Week of \(weekOf): "
        text += "\(overview.activeThisWeek) player\(overview.activeThisWeek == 1 ? "" : "s") trained, "
        text += "\(overview.teamMinutesThisWeek) minutes, "
        text += "\(overview.sessionsThisWeek) session\(overview.sessionsThisWeek == 1 ? "" : "s")."
        if !overview.topActiveNames.isEmpty {
            text += " Most active: \(overview.topActiveNames.joined(separator: ", "))."
        }
        return text
    }
}
