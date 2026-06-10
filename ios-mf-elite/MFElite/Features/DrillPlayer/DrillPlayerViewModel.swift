//
//  DrillPlayerViewModel.swift
//  MFElite
//
//  Drives the full-screen drill session state machine, timing, and logging.
//

import Foundation
import Observation
import SwiftData
import UserNotifications
import AudioToolbox
import UIKit

/// The phase of a live drill session.
enum PlayerPhase: Equatable {
    case ready
    case active(setIndex: Int)
    case resting(nextSetIndex: Int)
    case logged
}

@MainActor
@Observable
final class DrillPlayerViewModel {
    let drill: Drill
    let level: MasteryLevel
    let category: Category
    let discipline: Discipline

    var phase: PlayerPhase = .ready
    var currentSetIndex: Int = 0
    var timeRemaining: TimeInterval = 0
    var isPaused: Bool = false
    var isComplete: Bool = false

    /// Where this session originated (single drill, routine, or workout).
    let source: String
    let sourceName: String?

    /// Accumulated real training time (excludes rest and pauses) and number of
    /// sets actually performed — used to write an accurate SessionLogEntry.
    private var completedSetsTrainingSec: TimeInterval = 0
    private(set) var setsCompleted: Int = 0

    /// Real training seconds banked for the most recent log (set after logging).
    var loggedDurationSec: Int { Int(completedSetsTrainingSec.rounded()) }

    /// Mastery / progression results, computed once the drill is logged.
    private(set) var newPassesLogged: Int = 0
    private(set) var justMastered: Bool = false
    private(set) var levelJustMastered: Bool = false
    private(set) var categoryJustCertified: Bool = false
    private(set) var newStreak: Int = 0
    /// True when this completion closed all three daily rings for the first time today.
    private(set) var perfectDayJustClosed: Bool = false

    /// Injected from the view so the VM can persist progress.
    var context: ModelContext?

    /// The player's written journal reflection, captured by mental exercises.
    private var journalResponse: String?

    private static let restDuration: TimeInterval = 15

    init(
        drill: Drill,
        level: MasteryLevel,
        category: Category,
        discipline: Discipline,
        source: String = SessionSource.single.rawValue,
        sourceName: String? = nil
    ) {
        self.drill = drill
        self.level = level
        self.category = category
        self.discipline = discipline
        self.source = source
        self.sourceName = sourceName
    }

    // MARK: - Derived values

    /// Duration of a single set. Falls back to 60s if it doesn't divide evenly.
    var setDuration: TimeInterval {
        guard drill.sets > 0, drill.durationSec % drill.sets == 0 else { return 60 }
        return TimeInterval(drill.durationSec / drill.sets)
    }

    /// Active-set ring progress (1 → 0 as the set counts down).
    var progress: Double {
        let total = phase == .resting(nextSetIndex: currentSetIndex + 1) ? Self.restDuration : setDuration
        guard total > 0 else { return 0 }
        return max(0, min(1, timeRemaining / total))
    }

    /// "M:SS" of the remaining time.
    var formattedTime: String {
        Int(ceil(timeRemaining)).clockDuration
    }

    /// Cycles through coaching points as the current set elapses.
    var currentCoachingCue: String {
        let points = drill.coachingPoints
        guard !points.isEmpty else { return "" }
        let elapsed = setDuration - timeRemaining
        let slice = max(setDuration / Double(points.count), 1)
        let index = min(points.count - 1, max(0, Int(elapsed / slice)))
        return points[index]
    }

    // MARK: - Timer

    private var timer: Timer?
    private var setStartDate: Date?
    private var pauseAccumulated: TimeInterval = 0
    private var pauseStartDate: Date?

    private func playCountdownBeep() {
        AudioServicesPlaySystemSound(1057)
    }

    private func playSetCompleteSound() {
        AudioServicesPlaySystemSound(1025)
    }

    private func playSessionCompleteSound() {
        AudioServicesPlaySystemSound(1335)
    }

    private func invalidateTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func startTicking(from duration: TimeInterval, onZero: @escaping () -> Void) {
        invalidateTimer()
        timeRemaining = duration
        isPaused = false
        setStartDate = Date()
        pauseAccumulated = 0
        pauseStartDate = nil

        let t = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let start = self.setStartDate else { return }
                guard !self.isPaused else { return }

                let elapsed = Date().timeIntervalSince(start) - self.pauseAccumulated
                self.timeRemaining = max(0, duration - elapsed)

                // Countdown beeps at 3, 2, 1 seconds
                let secondsLeft = Int(ceil(self.timeRemaining))
                if secondsLeft <= 3 && secondsLeft >= 1 {
                    let fraction = self.timeRemaining - Double(secondsLeft - 1)
                    if fraction >= 0.9 && fraction < 1.0 {
                        self.playCountdownBeep()
                    }
                }

                if self.timeRemaining <= 0 {
                    self.invalidateTimer()
                    onZero()
                }
            }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    // MARK: - Actions

    func startSet() {
        currentSetIndex = 1
        phase = .active(setIndex: 1)
        startTicking(from: setDuration) { [weak self] in
            self?.completeSet()
        }
    }

    func pauseResume() {
        if isPaused {
            // Resuming — add pause duration to accumulated
            if let pauseStart = pauseStartDate {
                pauseAccumulated += Date().timeIntervalSince(pauseStart)
            }
            pauseStartDate = nil
        } else {
            // Pausing — record when pause started
            pauseStartDate = Date()
        }
        isPaused.toggle()
    }

    func stopSession() {
        invalidateTimer()
    }

    /// Complete a step-driven mental exercise. Banks the drill's guide duration as
    /// training time, stores the optional journal reflection, then logs the drill
    /// through the same path as a physical drill (XP, streak, mastery, badges).
    func completeMentalExercise(journal: String?) {
        let trimmed = journal?.trimmingCharacters(in: .whitespacesAndNewlines)
        journalResponse = (trimmed?.isEmpty ?? true) ? nil : trimmed
        completedSetsTrainingSec = TimeInterval(drill.durationSec)
        setsCompleted = 1
        logDrill()
        phase = .logged
    }

    /// Elapsed time within the currently active set, excluding pauses.
    private func currentSetElapsed() -> TimeInterval {
        guard let start = setStartDate else { return 0 }
        var pauses = pauseAccumulated
        if isPaused, let pauseStart = pauseStartDate {
            pauses += Date().timeIntervalSince(pauseStart)
        }
        return max(0, Date().timeIntervalSince(start) - pauses)
    }

    /// If a set is currently active, bank its real training time before ending it.
    private func recordActiveSetIfNeeded() {
        if case .active = phase {
            completedSetsTrainingSec += min(setDuration, currentSetElapsed())
            setsCompleted += 1
        }
    }

    /// Skip the current set's timer and move to the next set (or log if final set).
    func skipSet() {
        invalidateTimer()
        completeSet()
    }

    /// Log the drill immediately regardless of how many sets were completed.
    /// Awards XP and updates progress just like a normal completion.
    func logDrillEarly() {
        invalidateTimer()
        recordActiveSetIfNeeded()
        logDrill()
        phase = .logged
    }

    /// Log the drill as done from the ready screen — no timer. Banks the full
    /// guide duration as training time, then logs through the shared path so XP,
    /// streak, mastery, and celebrations all still count.
    func logInstant() {
        invalidateTimer()
        completedSetsTrainingSec = TimeInterval(drill.durationSec)
        setsCompleted = max(1, drill.sets)
        logDrill()
        phase = .logged
    }

    /// Called when a set's countdown reaches zero.
    func completeSet() {
        recordActiveSetIfNeeded()
        if currentSetIndex < drill.sets {
            let next = currentSetIndex + 1
            phase = .resting(nextSetIndex: next)
            playSetCompleteSound()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            startTicking(from: Self.restDuration) { [weak self] in
                guard let self else { return }
                self.currentSetIndex = next
                self.phase = .active(setIndex: next)
                self.startTicking(from: self.setDuration) { [weak self] in
                    self?.completeSet()
                }
            }
        } else {
            invalidateTimer()
            logDrill()
            phase = .logged
        }
    }

    // MARK: - Logging

    func logDrill() {
        playSessionCompleteSound()
        guard let context else { return }

        // Find or create progress for this drill.
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
        if progress.passesLogged >= ProgressionRules.masteryPasses && !progress.isMastered {
            progress.isMastered = true
            justMastered = true
        } else {
            justMastered = progress.isMastered && progress.passesLogged >= ProgressionRules.masteryPasses
        }
        newPassesLogged = progress.passesLogged

        // Player XP + streak.
        let playerDescriptor = FetchDescriptor<PlayerState>()
        let player = try? context.fetch(playerDescriptor).first
        if let player {
            player.xp += ProgressionRules.xpPerDrill

            if !Calendar.current.isDateInToday(player.lastTrainedDate ?? .distantPast) {
                player.streak += 1
            }
            player.lastTrainedDate = Date()
            newStreak = player.streak

            // Award streak freezes at milestones.
            if player.streak == 7 && player.freezesRemaining < 1 {
                player.freezesRemaining += 1
            }
            if player.streak == 30 && player.freezesRemaining < 2 {
                player.freezesRemaining = 2
            }
            if player.streak == 50 {
                player.freezesRemaining += 1
            }

            // Logged today — cancel tonight's streak-risk warning.
            NotificationService.shared.cancelStreakRisk()
            // Fire a milestone notification if this run hit a milestone.
            if let name = Self.milestoneName(for: player.streak) {
                NotificationService.shared.scheduleMilestone(days: player.streak, name: name)
            }
        }

        // Bonus XP for level / category completion.
        if isLevelFullyMastered(context: context) {
            levelJustMastered = true
            player?.xp += ProgressionRules.xpLevelBonus
            if isCategoryFullyMastered(context: context) {
                categoryJustCertified = true
                player?.xp += ProgressionRules.xpCategoryCert
            }
        }

        // Award achievement badges.
        let totalCompleted = EngagementTracker.shared.drillsCompleted + 1
        AchievementStore.earnAll(AchievementBadge.drillCountBadges(for: totalCompleted))

        let masteredTotal = masteredIDs(context: context).count
        AchievementStore.earnAll(AchievementBadge.masteryBadges(for: masteredTotal))

        if let player {
            AchievementStore.earnAll(AchievementBadge.streakBadges(for: player.streak))
        }

        if categoryJustCertified {
            AchievementStore.earn(.firstCert)
        }

        // Time-based badges.
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 7 {
            AchievementStore.earn(.earlyBird)
        }
        if hour >= 21 {
            AchievementStore.earn(.nightOwl)
        }

        // Write a permanent per-completion record for history & analytics.
        let entry = SessionLogEntry(
            drillID: drill.id,
            drillTitle: drill.title,
            disciplineID: discipline.id,
            disciplineName: discipline.name,
            categoryID: category.id,
            categoryName: category.name,
            levelNumber: level.number,
            durationSec: Int(completedSetsTrainingSec.rounded()),
            setsCompleted: max(1, setsCompleted),
            source: source,
            sourceName: sourceName,
            xpEarned: ProgressionRules.xpPerDrill,
            journalResponse: journalResponse
        )
        context.insert(entry)

        try? context.save()

        // Submit updated total XP to Game Center leaderboards.
        if let player {
            GameCenterService.shared.submitXP(player.xp)
        }

        // Perfect Day: all three daily rings closed for the first time today.
        evaluatePerfectDay(context: context)

        isComplete = true
    }

    /// After saving, recompute today's rings. If all three just closed for the
    /// first time today, flag the celebration and award the perfect-day badges.
    private func evaluatePerfectDay(context: ModelContext) {
        let today = Date()
        guard !PerfectDayStore.isRecorded(today) else { return }
        let allSessions = (try? context.fetch(FetchDescriptor<SessionLogEntry>())) ?? []
        let rings = DailyRings.make(from: allSessions, on: today)
        guard rings.allClosed else { return }
        let total = PerfectDayStore.record(today)
        AchievementStore.earnAll(AchievementBadge.perfectDayBadges(for: total))
        perfectDayJustClosed = true
    }

    /// Returns the milestone name if `streak` exactly matches a milestone threshold.
    private static func milestoneName(for streak: Int) -> String? {
        switch streak {
        case 7: return "Week One"
        case 14: return "Fortnight"
        case 30: return "The Month"
        case 50: return "Fifty"
        case 100: return "Century"
        default: return nil
        }
    }

    // MARK: - Completion checks

    private func masteredIDs(context: ModelContext) -> Set<String> {
        let descriptor = FetchDescriptor<DrillProgress>(
            predicate: #Predicate { $0.isMastered == true }
        )
        let mastered = (try? context.fetch(descriptor)) ?? []
        return Set(mastered.map(\.drillID))
    }

    private func isLevelFullyMastered(context: ModelContext) -> Bool {
        let ids = masteredIDs(context: context)
        return level.drills.allSatisfy { ids.contains($0.id) }
    }

    private func isCategoryFullyMastered(context: ModelContext) -> Bool {
        let ids = masteredIDs(context: context)
        for level in category.levels {
            for drill in level.drills where !ids.contains(drill.id) {
                return false
            }
        }
        return true
    }
}
