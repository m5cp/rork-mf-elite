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

    /// Number of sets the player skipped with the skip button this session.
    private(set) var setsSkipped: Int = 0
    /// True once the player triggered an early log (didn't finish every set naturally).
    private var loggedEarly: Bool = false

    /// Real training seconds banked for the most recent log (set after logging).
    var loggedDurationSec: Int { Int(completedSetsTrainingSec.rounded()) }

    /// Mastery / progression results, computed once the drill is logged.
    private(set) var newPassesLogged: Int = 0
    private(set) var justMastered: Bool = false
    private(set) var levelJustMastered: Bool = false
    private(set) var categoryJustCertified: Bool = false
    private(set) var newStreak: Int = 0
    /// True when this completion actually moved the streak counter, so the
    /// post-session screen only shows "+1" when the streak really went up (a
    /// second drill on the same day does not advance it).
    private(set) var streakDidAdvance: Bool = false
    /// XP actually credited for this completion, including the 2x weekend
    /// booster and any level/category bonus. The post-session screens read this
    /// instead of the flat `ProgressionRules.xpPerDrill` constant, which
    /// under-reported every boosted session.
    private(set) var lastAwardedXP: Int = 0
    /// True when this completion closed all three daily rings for the first time today.
    private(set) var perfectDayJustClosed: Bool = false

    /// Injected from the view so the VM can persist progress.
    var context: ModelContext?

    /// The player's written journal reflection, captured by mental exercises.
    private var journalResponse: String?

    private static let restDuration: TimeInterval = 15

    /// The total rest duration for the current rest phase. Starts at the default
    /// but grows when the player taps "+15s", so the rest ring stays accurate.
    private(set) var currentRestDuration: TimeInterval = restDuration

    /// Reads a Bool setting, falling back to `fallback` when never set.
    private func setting(_ key: String, default fallback: Bool) -> Bool {
        UserDefaults.standard.object(forKey: key) == nil
            ? fallback
            : UserDefaults.standard.bool(forKey: key)
    }

    /// Whether sound + vibration cues are enabled. Defaults to on; mirrored by the
    /// "Sound & vibration cues" setting toggle.
    private var cuesEnabled: Bool { setting("MF_SOUND_CUES", default: true) }

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

    /// True when the session is currently in a rest phase.
    var isResting: Bool {
        if case .resting = phase { return true }
        return false
    }

    /// Active-set ring progress (1 → 0 as the set counts down).
    var progress: Double {
        let total = isResting ? currentRestDuration : setDuration
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
    /// Bumped every time the timer is invalidated. A queued tick compares the
    /// generation it captured and does nothing if the timer moved on, so a tick
    /// in flight can't resurrect a session the player already ended.
    private var tickGeneration: Int = 0
    /// One-shot guard so a session is only ever logged once, no matter which of
    /// the several completion paths gets there first.
    private var hasLogged = false

    private func playCountdownBeep() {
        guard cuesEnabled else { return }
        if CueAudioPlayer.shared.isSessionActive { CueAudioPlayer.shared.playCountdownBeep() }
        else { AudioServicesPlaySystemSound(1057) }
    }

    private func playSetCompleteSound() {
        guard cuesEnabled else { return }
        if CueAudioPlayer.shared.isSessionActive { CueAudioPlayer.shared.playSetComplete() }
        else { AudioServicesPlaySystemSound(1025) }
    }

    private func playSessionCompleteSound() {
        guard cuesEnabled else { return }
        if CueAudioPlayer.shared.isSessionActive { CueAudioPlayer.shared.playSessionComplete() }
        else { AudioServicesPlaySystemSound(1335) }
    }

    private func cueHaptic(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard cuesEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }

    private func invalidateTimer() {
        timer?.invalidate()
        timer = nil
        // Retire the current tick generation. Invalidating the Timer stops
        // future firings, but a tick that already fired hops to the main actor
        // through a Task and will still run afterwards — which is how "Log and
        // finish" during the last moments of a rest could kick the player into
        // another set and log the drill a second time.
        tickGeneration &+= 1
        // NOTE: `setStartDate` is deliberately left intact. `logDrillEarly()`
        // invalidates the timer and then calls `recordActiveSetIfNeeded()`,
        // which needs it to bank the partial set's training seconds.
    }

    private func startTicking(from duration: TimeInterval, onZero: @escaping () -> Void) {
        invalidateTimer()
        timeRemaining = duration
        isPaused = false
        setStartDate = Date()
        pauseAccumulated = 0
        pauseStartDate = nil

        let generation = tickGeneration
        let t = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.tickGeneration == generation else { return }
                guard let start = self.setStartDate else { return }
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
        startLiveSession()
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
        pushLiveActivity()
    }

    func stopSession() {
        invalidateTimer()
        tearDownLiveSession(delayAudio: false)
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
        setsSkipped += 1
        completeSet()
    }

    /// Restart the current set's timer from the top. Does not count as a skip
    /// or a completion — the set simply starts over.
    func restartSet() {
        guard case .active(let setIndex) = phase else { return }
        invalidateTimer()
        beginActiveSet(setIndex)
    }

    /// Restart the whole drill: back to set 1 in the ready state, clearing this
    /// drill's set counters. Nothing is logged — the player is starting over.
    func restartDrill() {
        invalidateTimer()
        tearDownLiveSession(delayAudio: false)
        phase = .ready
        currentSetIndex = 0
        setsCompleted = 0
        setsSkipped = 0
        completedSetsTrainingSec = 0
        loggedEarly = false
        isPaused = false
        timeRemaining = 0
        currentRestDuration = Self.restDuration
        setStartDate = nil
        pauseAccumulated = 0
        pauseStartDate = nil
    }

    /// Skip the remaining rest and start the next set immediately.
    func skipRest() {
        guard case let .resting(nextSetIndex) = phase else { return }
        invalidateTimer()
        if nextSetIndex <= drill.sets {
            beginActiveSet(nextSetIndex)
        }
    }

    /// Add 15 seconds to the current rest so the player can recover longer.
    func extendRest() {
        guard case let .resting(nextSetIndex) = phase else { return }
        let newRemaining = timeRemaining + 15
        invalidateTimer()
        currentRestDuration = max(currentRestDuration, newRemaining)
        phase = .resting(nextSetIndex: nextSetIndex)
        startTicking(from: newRemaining) { [weak self] in
            self?.beginActiveSet(nextSetIndex)
        }
        pushLiveActivity()
    }

    /// End the current set early from a deliberate shake (counts as completed,
    /// not skipped). No-op outside an active set.
    func completeSetEarlyByMotion() {
        guard case .active = phase else { return }
        invalidateTimer()
        completeSet()
    }

    /// Begin a numbered active set, wiring its countdown to `completeSet`.
    private func beginActiveSet(_ index: Int) {
        currentSetIndex = index
        phase = .active(setIndex: index)
        startTicking(from: setDuration) { [weak self] in
            self?.completeSet()
        }
        MotionTracker.shared.resetReps()
        pushLiveActivity()
    }

    /// Log the drill immediately regardless of how many sets were completed.
    /// Awards XP and updates progress just like a normal completion.
    func logDrillEarly() {
        invalidateTimer()
        loggedEarly = true
        recordActiveSetIfNeeded()
        logDrill()
        phase = .logged
    }

    /// Log the drill from the tap-to-complete set checklist — no timer. Banks the
    /// per-set guide duration for each set the player checked off, then logs
    /// through the shared path so XP, streak, mastery, and celebrations all count.
    func logFromChecklist(setsCompleted tapped: Int) {
        invalidateTimer()
        let count = max(1, tapped)
        completedSetsTrainingSec = setDuration * TimeInterval(count)
        setsCompleted = count
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
            currentRestDuration = Self.restDuration
            phase = .resting(nextSetIndex: next)
            playSetCompleteSound()
            cueHaptic(.success)
            startTicking(from: currentRestDuration) { [weak self] in
                self?.beginActiveSet(next)
            }
            pushLiveActivity()
        } else {
            invalidateTimer()
            logDrill()
            phase = .logged
        }
    }

    // MARK: - Logging

    func logDrill() {
        // A session can only be logged once. Several paths can race into here —
        // the natural end of the last set, "Log and finish", the set checklist's
        // delayed call, and a timer tick that was already queued when the player
        // acted — and without this guard the drill was logged twice: double XP,
        // two history rows, and an extra mastery pass from one session.
        guard !hasLogged else { return }
        hasLogged = true

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

        // Whether the level/category were ALREADY complete before this log.
        // The bonus is only for crossing the line, not for standing past it.
        let levelWasMastered = isLevelFullyMastered(context: context)
        let categoryWasCertified = levelWasMastered && isCategoryFullyMastered(context: context)

        progress.passesLogged = min(ProgressionRules.masteryPasses, progress.passesLogged + 1)
        progress.lastLoggedAt = Date()
        if progress.passesLogged >= ProgressionRules.masteryPasses && !progress.isMastered {
            progress.isMastered = true
            progress.masteredAt = Date()
            justMastered = true
        } else {
            justMastered = progress.isMastered && progress.passesLogged >= ProgressionRules.masteryPasses
        }
        newPassesLogged = progress.passesLogged

        // Player XP + streak. The 2x weekend booster (when active) doubles the
        // EARNED drill XP at this single award point so player state, the session
        // log, and Game Center all stay consistent.
        let awardedXP = ProgressionRules.xpPerDrill * XPStoreService.shared.earnMultiplier
        var totalAwardedXP = awardedXP
        let playerDescriptor = FetchDescriptor<PlayerState>()
        let player = try? context.fetch(playerDescriptor).first
        if let player {
            player.xp += awardedXP

            // StreakEngine owns advancing, freeze spending, streakPB and
            // milestone freezes, so every logging path behaves identically.
            let outcome = StreakEngine.recordTraining(player)
            newStreak = outcome.streak
            streakDidAdvance = outcome.showsIncrement

            // Fire a milestone notification only when this session actually
            // moved the streak onto the milestone (not on a repeat log).
            if outcome.didAdvance, let name = Self.milestoneName(for: player.streak) {
                NotificationService.shared.scheduleMilestone(days: player.streak, name: name)
            }
        }

        // Bonus XP for level / category completion — awarded ONLY on the log
        // that completes it. Previously this fired on every subsequent log of
        // any drill in an already-mastered level, granting the bonus again and
        // replaying the full-screen celebration each time.
        if !levelWasMastered, isLevelFullyMastered(context: context) {
            levelJustMastered = true
            player?.xp += ProgressionRules.xpLevelBonus
            totalAwardedXP += ProgressionRules.xpLevelBonus
            if !categoryWasCertified, isCategoryFullyMastered(context: context) {
                categoryJustCertified = true
                player?.xp += ProgressionRules.xpCategoryCert
                totalAwardedXP += ProgressionRules.xpCategoryCert
            }
        }
        lastAwardedXP = totalAwardedXP

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
            xpEarned: awardedXP,
            journalResponse: journalResponse,
            setsSkipped: setsSkipped,
            completedFully: !loggedEarly,
            steps: MotionTracker.shared.stepCount,
            movementIntensity: MotionTracker.shared.averageIntensity
        )
        context.insert(entry)
        SyncEngine.shared.enqueueSessionLog(entry)

        try? context.save()

        // Mirror player state + this drill's progress to the cloud (background,
        // fails soft when signed out / offline).
        SyncEngine.shared.syncAfterLogging(
            player: player,
            touchedDrillIDs: [drill.id],
            context: context
        )

        // Submit updated total XP to Game Center leaderboards.
        if let player {
            GameCenterService.shared.submitXP(player.xp)
        }

        // Optionally mirror this session to Apple Health as a soccer workout.
        HealthKitService.shared.logTraining(durationSec: Int(completedSetsTrainingSec.rounded()))

        // Refresh Home/Lock Screen widgets with the new status.
        WidgetBridge.refresh(context: context)

        // Refresh the Apple Watch glance/complication with the new status.
        WatchSyncBridge.shared.refreshAndPush()

        // Trained today — cancel tonight's streak warning, defend tomorrow
        // evening, and refresh the pending parent weekly summary.
        PostSessionNotifications.refresh(streak: player?.streak ?? 0, context: context)

        // Perfect Day: all three daily rings closed for the first time today.
        evaluatePerfectDay(context: context)

        isComplete = true
        tearDownLiveSession(delayAudio: true)
    }

    // MARK: - Live session (audio + motion + Live Activity)

    /// Begin background audio, motion tracking, the lock-screen Live Activity,
    /// and listen for its pause/skip commands. Called when a guided timer starts.
    private func startLiveSession() {
        if cuesEnabled { CueAudioPlayer.shared.beginSession() }

        DrillCommandListener.shared.startObserving()
        DrillCommandListener.shared.onCommand = { [weak self] command in
            self?.handleLiveCommand(command)
        }

        startMotionIfEnabled()
        LiveActivityController.shared.start(sessionName: sourceName ?? drill.title, state: makeLiveState())
    }

    /// Tear down everything started by `startLiveSession`. When `delayAudio` is
    /// true the audio engine lingers briefly so the completion flourish finishes.
    private func tearDownLiveSession(delayAudio: Bool) {
        LiveActivityController.shared.end()
        MotionTracker.shared.stop()
        // Clear leftover step/intensity totals so a later non-timer log (checklist
        // or instant) records 0 movement instead of inheriting these numbers.
        MotionTracker.shared.resetSessionStats()
        DrillCommandListener.shared.onCommand = nil
        if delayAudio {
            let player = CueAudioPlayer.shared
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { player.endSession() }
        } else {
            CueAudioPlayer.shared.endSession()
        }
    }

    private func startMotionIfEnabled() {
        let reps = setting("MF_MOTION_REPS", default: true)
        let shake = setting("MF_SHAKE_ADVANCE", default: true)
        let track = setting("MF_MOTION_TRACKING", default: true)
        guard reps || shake || track else { return }
        MotionTracker.shared.onShake = { [weak self] in
            guard let self else { return }
            if case .active = self.phase {
                self.cueHaptic(.success)
                self.completeSetEarlyByMotion()
            } else if case .resting = self.phase {
                self.skipRest()
            }
        }
        MotionTracker.shared.start(countReps: reps, detectShake: shake, trackMovement: track)
    }

    private func handleLiveCommand(_ command: DrillLiveActivityCommand) {
        switch command {
        case .pauseToggle:
            if case .active = phase { pauseResume() }
        case .skip:
            if case .active = phase { skipSet() }
            else if case .resting = phase { skipRest() }
        }
    }

    /// Snapshot of the current phase for the Live Activity.
    private func makeLiveState() -> DrillActivityAttributes.ContentState {
        let label: String
        switch phase {
        case .active(let set): label = "Set \(set) of \(drill.sets)"
        case .resting(let next): label = next <= drill.sets ? "Rest · next set \(next)" : "Rest"
        default: label = drill.title
        }
        return DrillActivityAttributes.ContentState(
            drillTitle: drill.title,
            phaseLabel: label,
            isResting: isResting,
            isPaused: isPaused,
            currentSet: max(1, currentSetIndex),
            totalSets: max(1, drill.sets),
            endDate: Date().addingTimeInterval(max(0, timeRemaining)),
            pausedRemaining: Int(ceil(max(0, timeRemaining)))
        )
    }

    private func pushLiveActivity() {
        LiveActivityController.shared.update(makeLiveState())
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
