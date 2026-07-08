//
//  GameIQStore.swift
//  MFElite
//
//  Completion logic for Game IQ lessons. First-ever completion stamps the lesson,
//  awards a one-time XP bonus, and writes a SessionLogEntry against the Tactical
//  discipline so the lesson counts toward the day's training rings exactly like a
//  single tactical drill. Retakes are free: they never re-award XP or re-credit.
//

import Foundation
import SwiftData

@MainActor
enum GameIQStore {
    /// XP awarded the first time a lesson is completed.
    static let xpReward = 15

    /// Result of attempting to complete a lesson, for the completion screen.
    struct Outcome {
        let xpAwarded: Int      // 0 on a retake
        let wasFirstCompletion: Bool
    }

    /// Marks a lesson complete. On the first-ever completion this stamps
    /// `completedAt`, awards `xpReward` once, and logs one Tactical session so
    /// the Drills/Train rings advance like a normal tactical drill. Retakes are
    /// idempotent — they award nothing and don't write history.
    @discardableResult
    static func complete(_ lesson: GameIQLesson, context: ModelContext) -> Outcome {
        guard lesson.completedAt == nil else {
            return Outcome(xpAwarded: 0, wasFirstCompletion: false)
        }

        lesson.completedAt = Date()

        // One-time XP.
        let player = try? context.fetch(FetchDescriptor<PlayerState>()).first
        if let player {
            player.xp += xpReward
            if !Calendar.current.isDateInToday(player.lastTrainedDate ?? .distantPast) {
                player.streak += 1
            }
            player.lastTrainedDate = Date()
        }

        // Write a Tactical session so today's rings credit this like one drill.
        if let (discipline, category, level) = tacticalContext(for: lesson, context: context) {
            let entry = SessionLogEntry(
                drillID: "gameiq-\(lesson.id)",
                drillTitle: lesson.title,
                disciplineID: discipline.id,
                disciplineName: discipline.name,
                categoryID: category.id,
                categoryName: category.name,
                levelNumber: level?.number ?? 1,
                durationSec: 300,
                setsCompleted: 1,
                source: SessionSource.single.rawValue,
                sourceName: "Game IQ",
                xpEarned: xpReward
            )
            context.insert(entry)
            SyncEngine.shared.enqueueSessionLog(entry)
        }

        // Mirror the lesson completion itself.
        if let completedAt = lesson.completedAt {
            SyncEngine.shared.enqueueGameIQCompletion(lessonID: lesson.id, completedAt: completedAt)
        }

        try? context.save()

        // Mirror to Game Center / widgets so the new XP and ring state propagate.
        if let player {
            GameCenterService.shared.submitXP(player.xp)
            SyncEngine.shared.enqueuePlayerState(player)
        }
        WidgetBridge.refresh(context: context)

        // Trained today — cancel tonight's streak warning, defend tomorrow
        // evening, and refresh the pending parent weekly summary.
        PostSessionNotifications.refresh(streak: player?.streak ?? 0, context: context)

        return Outcome(xpAwarded: xpReward, wasFirstCompletion: true)
    }

    /// Resolves the Tactical discipline, the lesson's related category, and its
    /// first level, used to denormalize a SessionLogEntry. Falls back to the
    /// discipline's first category if the related one can't be found.
    private static func tacticalContext(
        for lesson: GameIQLesson,
        context: ModelContext
    ) -> (Discipline, Category, MasteryLevel?)? {
        let disciplines = (try? context.fetch(FetchDescriptor<Discipline>())) ?? []
        guard let tactical = disciplines.first(where: { $0.name == "Tactical" }) ?? disciplines.first(where: { $0.id == "d-tact" }) else {
            return nil
        }
        let category = tactical.categories.first(where: { $0.id == lesson.relatedCategoryID })
            ?? tactical.categories.sorted(by: { $0.sortIndex < $1.sortIndex }).first
        guard let category else { return nil }
        let level = category.levels.sorted(by: { $0.sortIndex < $1.sortIndex }).first
        return (tactical, category, level)
    }
}
