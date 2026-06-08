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

    /// Mastery / progression results, computed once the drill is logged.
    private(set) var newPassesLogged: Int = 0
    private(set) var justMastered: Bool = false
    private(set) var levelJustMastered: Bool = false
    private(set) var categoryJustCertified: Bool = false
    private(set) var newStreak: Int = 0

    /// Injected from the view so the VM can persist progress.
    var context: ModelContext?

    private static let restDuration: TimeInterval = 15

    init(drill: Drill, level: MasteryLevel, category: Category, discipline: Discipline) {
        self.drill = drill
        self.level = level
        self.category = category
        self.discipline = discipline
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

    /// Called when a set's countdown reaches zero.
    func completeSet() {
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

        try? context.save()
        isComplete = true
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
