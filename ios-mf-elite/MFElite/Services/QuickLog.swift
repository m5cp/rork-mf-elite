//
//  QuickLog.swift
//  MFElite
//
//  Timer-free logging. Records one or many drills as completed in a single pass —
//  awarding XP, advancing the streak once, updating mastery, writing per-drill
//  history, and re-evaluating today's rings — without running the live player.
//  Used by the "Mark workout complete" action on routines and custom workouts.
//

import Foundation
import SwiftData
import UIKit

@MainActor
enum QuickLog {
    /// Outcome of a quick-log pass, for confirmation UI.
    struct Result {
        let drillsLogged: Int
        let xpEarned: Int
        let newStreak: Int
        let perfectDayClosed: Bool
    }

    /// Log a batch of drills as completed without the timer. The full guide
    /// duration of each drill is banked as training time. Streak advances at most
    /// once (today), mirroring a normal session.
    @discardableResult
    static func logDrills(
        _ contexts: [DrillContext],
        source: SessionSource,
        sourceName: String?,
        context: ModelContext
    ) -> Result {
        guard !contexts.isEmpty else {
            return Result(drillsLogged: 0, xpEarned: 0, newStreak: 0, perfectDayClosed: false)
        }

        var xpEarned = 0
        for item in contexts {
            logProgressAndHistory(for: item, source: source, sourceName: sourceName, context: context)
            xpEarned += ProgressionRules.xpPerDrill
        }

        // Player XP + a single streak advance for the day.
        let player = try? context.fetch(FetchDescriptor<PlayerState>()).first
        if let player {
            player.xp += xpEarned
            if !Calendar.current.isDateInToday(player.lastTrainedDate ?? .distantPast) {
                player.streak += 1
            }
            player.lastTrainedDate = Date()

            if player.streak == 7 && player.freezesRemaining < 1 { player.freezesRemaining += 1 }
            if player.streak == 30 && player.freezesRemaining < 2 { player.freezesRemaining = 2 }
            if player.streak == 50 { player.freezesRemaining += 1 }

            NotificationService.shared.cancelStreakRisk()
        }

        // Achievement badges (counts after this batch).
        for _ in contexts { EngagementTracker.shared.recordDrillCompleted() }
        AchievementStore.earnAll(AchievementBadge.drillCountBadges(for: EngagementTracker.shared.drillsCompleted))
        let masteredTotal = masteredIDs(context: context).count
        AchievementStore.earnAll(AchievementBadge.masteryBadges(for: masteredTotal))
        if let player {
            AchievementStore.earnAll(AchievementBadge.streakBadges(for: player.streak))
        }

        try? context.save()

        // Submit updated total XP to Game Center leaderboards.
        if let player {
            GameCenterService.shared.submitXP(player.xp)
        }

        let perfectDay = evaluatePerfectDay(context: context)

        return Result(
            drillsLogged: contexts.count,
            xpEarned: xpEarned,
            newStreak: player?.streak ?? 0,
            perfectDayClosed: perfectDay
        )
    }

    /// Attach a post-session check-in (a 1–5 felt rating and optional note) to the
    /// `drillCount` most recently logged drills — i.e. the session just completed.
    /// Safe to call once per session from the check-in sheet.
    static func attachReflection(
        rating: Int,
        note: String?,
        toMostRecent drillCount: Int,
        context: ModelContext
    ) {
        guard drillCount > 0 else { return }
        var descriptor = FetchDescriptor<SessionLogEntry>(
            sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
        )
        descriptor.fetchLimit = drillCount
        guard let entries = try? context.fetch(descriptor), !entries.isEmpty else { return }
        let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        for entry in entries {
            entry.feltRating = rating
            entry.reflection = (trimmed?.isEmpty ?? true) ? nil : trimmed
        }
        try? context.save()
    }

    // MARK: - Per-drill record

    private static func logProgressAndHistory(
        for item: DrillContext,
        source: SessionSource,
        sourceName: String?,
        context: ModelContext
    ) {
        let drill = item.drill
        let drillID = drill.id
        let descriptor = FetchDescriptor<DrillProgress>(
            predicate: #Predicate { $0.drillID == drillID }
        )
        let progress: DrillProgress
        if let existing = try? context.fetch(descriptor).first {
            progress = existing
        } else {
            progress = DrillProgress(drillID: drillID)
            context.insert(progress)
        }

        progress.passesLogged = min(ProgressionRules.masteryPasses, progress.passesLogged + 1)
        progress.lastLoggedAt = Date()
        if progress.passesLogged >= ProgressionRules.masteryPasses {
            progress.isMastered = true
        }

        let entry = SessionLogEntry(
            drillID: drill.id,
            drillTitle: drill.title,
            disciplineID: item.discipline.id,
            disciplineName: item.discipline.name,
            categoryID: item.category.id,
            categoryName: item.category.name,
            levelNumber: item.level.number,
            durationSec: drill.durationSec,
            setsCompleted: max(1, drill.sets),
            source: source.rawValue,
            sourceName: sourceName,
            xpEarned: ProgressionRules.xpPerDrill,
            journalResponse: nil
        )
        context.insert(entry)
    }

    private static func masteredIDs(context: ModelContext) -> Set<String> {
        let descriptor = FetchDescriptor<DrillProgress>(
            predicate: #Predicate { $0.isMastered == true }
        )
        let mastered = (try? context.fetch(descriptor)) ?? []
        return Set(mastered.map(\.drillID))
    }

    /// Recompute today's rings; if all three just closed for the first time today,
    /// record it and award the perfect-day badges.
    private static func evaluatePerfectDay(context: ModelContext) -> Bool {
        let today = Date()
        guard !PerfectDayStore.isRecorded(today) else { return false }
        let allSessions = (try? context.fetch(FetchDescriptor<SessionLogEntry>())) ?? []
        let rings = DailyRings.make(from: allSessions, on: today)
        guard rings.allClosed else { return false }
        let total = PerfectDayStore.record(today)
        AchievementStore.earnAll(AchievementBadge.perfectDayBadges(for: total))
        return true
    }
}
