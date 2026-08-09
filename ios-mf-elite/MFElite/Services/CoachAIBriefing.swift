//
//  CoachAIBriefing.swift
//  MFElite
//
//  On-device (Apple Intelligence) written briefings for coaches. Everything runs
//  locally via Foundation Models — nothing about a player leaves the device. On
//  devices without Apple Intelligence (older iPhones / iOS < 26), a clean
//  data-built summary is returned instead so the feature always works.
//

import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Which briefing the coach requested.
enum CoachBriefingKind: String, CaseIterable, Identifiable {
    case team
    case player
    case app
    var id: String { rawValue }
    var title: String {
        switch self {
        case .team: return "Team"
        case .player: return "Player"
        case .app: return "App"
        }
    }
}

@MainActor
enum CoachAIBriefing {
    /// True when on-device Apple Intelligence can generate text on this device.
    static var isAIAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return SystemLanguageModel.default.isAvailable
        }
        #endif
        return false
    }

    /// Human-readable reason AI is unavailable, or nil when it is available.
    static var unavailableReason: String? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return nil
            case .unavailable(.appleIntelligenceNotEnabled):
                return "Turn on Apple Intelligence in Settings to get AI-written briefings. Showing a data summary for now."
            case .unavailable(.modelNotReady):
                return "The on-device model is still downloading. Showing a data summary for now."
            default:
                return "This device can't run on-device AI. Showing a clean data summary instead."
            }
        }
        #endif
        return "AI briefings need an iPhone 15 Pro or later on the latest iOS. Showing a clean data summary instead."
    }

    // MARK: - Public generators

    static func teamBriefing(model: CoachViewModel) async -> String {
        let snap = model.teamSnapshot
        let attention = model.needsAttention.map { ShareText.firstName($0.displayName) }
        let data = """
        Weekly team data for a youth soccer training academy:
        - Players on roster: \(snap.totalPlayers)
        - Active this week: \(snap.activeThisWeek)
        - Needing attention (7+ days inactive): \(snap.needsAttentionCount)
        - Average training minutes per player: \(snap.avgMinutesPerPlayer)
        - Total team minutes: \(snap.teamMinutesThisWeek)
        - Most active: \(snap.mostActive.map { "\($0.name), \($0.minutes) min" } ?? "none")
        - Least active: \(snap.leastActive.map { "\($0.name), \($0.minutes) min" } ?? "none")
        - Players to nudge: \(attention.isEmpty ? "none" : attention.joined(separator: ", "))
        """
        let instructions = """
        You are an assistant coach for a youth soccer academy. Write an encouraging weekly \
        team briefing in 3 to 4 sentences for the head coach. Note momentum, who needs a nudge, \
        and one suggested focus. Be concrete and kind. DO NOT invent numbers beyond the data given.
        """
        return await generate(instructions: instructions, prompt: data, fallback: teamFallback(snap: snap, attention: attention))
    }

    static func appOverview(model: CoachViewModel) async -> String {
        let o = model.overview
        let data = """
        In-app activity data for a youth soccer training app (store downloads/revenue are not available inside the app):
        - Total members: \(o?.totalPlayers ?? 0)
        - Active this week: \(o?.activeThisWeek ?? 0)
        - Sessions this week: \(o?.sessionsThisWeek ?? 0)
        - Training minutes this week: \(o?.teamMinutesThisWeek ?? 0)
        """
        let instructions = """
        You are a product analyst. Summarise this app's in-app activity in 3 plain-language \
        sentences for the founder. Focus on engagement and one opportunity. DO NOT mention \
        downloads or revenue, and DO NOT invent numbers beyond the data given.
        """
        return await generate(instructions: instructions, prompt: data, fallback: appFallback(overview: o))
    }

    /// Per-player summary. `detail` must already be loaded by the caller.
    static func playerSummary(name: String, detail: CoachPlayerDetail) async -> String {
        let combine = detail.combineProgress.map {
            "\($0.label): baseline \(CoachFormat.combineValue($0.baseline, unit: $0.unit)) → latest \(CoachFormat.combineValue($0.latest, unit: $0.unit)), best \(CoachFormat.combineValue($0.best, unit: $0.unit))"
        }.joined(separator: "; ")
        let mastery = detail.masteryByDiscipline.map { "\($0.name) \($0.count)" }.joined(separator: ", ")
        // Built outside the block, because this text becomes the prompt and the
        // instructions below it tell the model not to invent numbers. A
        // player_state row written before `drills_completed` was wired reports
        // 0, and "12 of 0 started" is a number the model would faithfully carry
        // into a summary that goes home to a parent.
        let masteredText = detail.drillsStarted > 0
            ? "\(detail.totalMastered) of \(detail.drillsStarted) started"
            : "\(detail.totalMastered)"
        let data = """
        Training data for youth soccer player \(name):
        - Current streak: \(detail.streak) days (best \(detail.streakPB))
        - Sessions all-time: \(detail.sessionCount)
        - Minutes last 7 days: \(detail.minutes7d); last 30 days: \(detail.minutes30d)
        - Drills mastered: \(masteredText)\(mastery.isEmpty ? "" : " (\(mastery))")
        - Combine progress: \(combine.isEmpty ? "no combine tests yet" : combine)
        - Coach focus on record: \(detail.coachFocus.isEmpty ? "none set" : detail.coachFocus)
        """
        let instructions = """
        You are a youth soccer coach writing a short parent-friendly progress summary about \
        \(name) in 3 to 4 sentences. Be positive, specific, and mention one area to develop. \
        DO NOT invent numbers beyond the data given.
        """
        return await generate(instructions: instructions, prompt: data, fallback: playerFallback(name: name, detail: detail))
    }

    // MARK: - Core generation

    private static func generate(instructions: String, prompt: String, fallback: String) async -> String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), SystemLanguageModel.default.isAvailable {
            do {
                let session = LanguageModelSession { instructions }
                let response = try await session.respond(to: prompt)
                let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
                return text.isEmpty ? fallback : text
            } catch {
                return fallback
            }
        }
        #endif
        return fallback
    }

    // MARK: - Data-built fallbacks

    private static func teamFallback(snap: TeamSnapshot, attention: [String]) -> String {
        var lines: [String] = []
        lines.append("\(snap.activeThisWeek) of \(snap.totalPlayers) players trained this week, averaging \(CoachFormat.minutes(snap.avgMinutesPerPlayer)) each (\(CoachFormat.minutes(snap.teamMinutesThisWeek)) total).")
        if let most = snap.mostActive, most.minutes > 0 {
            lines.append("\(most.name) led the way with \(CoachFormat.minutes(most.minutes)).")
        }
        if snap.needsAttentionCount > 0 {
            let who = attention.prefix(4).joined(separator: ", ")
            lines.append("\(snap.needsAttentionCount) need a nudge: \(who)\(attention.count > 4 ? ", and more" : "").")
        } else {
            lines.append("Everyone has trained recently — great momentum.")
        }
        return lines.joined(separator: " ")
    }

    private static func appFallback(overview: CoachOverview?) -> String {
        let o = overview
        return "\(o?.totalPlayers ?? 0) members total, with \(o?.activeThisWeek ?? 0) active this week across \(o?.sessionsThisWeek ?? 0) sessions and \(o?.teamMinutesThisWeek ?? 0) training minutes. (Store downloads and revenue aren't visible inside the app.)"
    }

    private static func playerFallback(name: String, detail: CoachPlayerDetail) -> String {
        var lines: [String] = []
        lines.append("\(name) has logged \(detail.sessionCount) sessions with a \(detail.streak)-day streak (best \(detail.streakPB)).")
        lines.append("They trained \(CoachFormat.minutes(detail.minutes30d)) in the last 30 days and have mastered \(detail.totalMastered) drills.")
        if let combine = detail.combineProgress.first {
            let improved = combine.lowerIsBetter ? combine.latest < combine.baseline : combine.latest > combine.baseline
            lines.append("\(combine.label) has \(improved ? "improved" : "held steady") from \(CoachFormat.combineValue(combine.baseline, unit: combine.unit)) to \(CoachFormat.combineValue(combine.latest, unit: combine.unit)).")
        }
        if !detail.coachFocus.isEmpty {
            lines.append("Current focus: \(detail.coachFocus).")
        }
        return lines.joined(separator: " ")
    }
}
