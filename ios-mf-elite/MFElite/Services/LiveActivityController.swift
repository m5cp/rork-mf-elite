//
//  LiveActivityController.swift
//  MFElite
//
//  Owns the lifecycle of the drill timer Live Activity (lock screen + Dynamic
//  Island). The drill player starts it when a guided timer begins, updates it on
//  every phase change, and ends it when the drill is logged or the session ends.
//
//  ActivityKit outlives the process, so this controller also has to settle up
//  with it at launch: see `reconcileOrphans()`.
//

import Foundation
import ActivityKit

@MainActor
final class LiveActivityController {
    static let shared = LiveActivityController()

    private var activity: Activity<DrillActivityAttributes>?

    /// True when `activity` is a leftover from a previous process that we picked
    /// up at launch rather than one this process started. Nothing is driving it,
    /// so it is kept only while the player still has a session to come back to —
    /// see `reconcileOrphans()`.
    private var isAdopted = false

    /// Slack allowed on top of a running countdown before the content is treated
    /// as out of date. Every phase change pushes a new state, and the longest gap
    /// between pushes is a single set, so silence past the current countdown plus
    /// this much means nobody is feeding the timer any more. Marking it stale
    /// that soon is what stops a dead activity from ticking convincingly for the
    /// eight hours ActivityKit would otherwise hand it.
    private static let runningStaleSlack: TimeInterval = 90

    /// How long a paused drill may sit untouched before its content goes stale.
    /// Longer than the running slack on purpose — pausing to catch a breath, take
    /// a call, or reset the cones is normal and shouldn't grey out the card — but
    /// still short enough that a pause nobody ever comes back from stops
    /// presenting itself as a live session.
    private static let pausedStaleWindow: TimeInterval = 10 * 60

    /// How recently the player must have been mid-session for a leftover activity
    /// to count as theirs to return to rather than debris from a crash they've
    /// long since moved on from.
    private static let adoptionWindow: TimeInterval = 15 * 60

    private init() {}

    /// Whether the user has Live Activities enabled for this app.
    private var isEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    /// Start (or restart) the Live Activity for a session.
    func start(sessionName: String, state: DrillActivityAttributes.ContentState) {
        guard isEnabled else { return }

        // Reuse a handle we can still write to — including one adopted at launch,
        // so resuming a crashed session drives the card already on the lock screen
        // instead of stacking a second one beside it. The attributes of an adopted
        // activity name the old session, which is harmless: every glyph the widget
        // draws comes from the content state, which is about to be replaced.
        if let activity, isWritable(activity) {
            isAdopted = false
            update(state)
            return
        }

        // A handle that has ended, or that the player swiped away, can never be
        // updated again. Dropping it here is what lets a fresh one be requested;
        // previously `start` saw a non-nil handle, bounced straight into `update`,
        // and the rest of the session ran with no Live Activity at all.
        activity = nil
        isAdopted = false

        let attributes = DrillActivityAttributes(sessionName: sessionName)
        do {
            let requested = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: staleDate(for: state)),
                pushType: nil
            )
            activity = requested
            // Sweep anything an earlier process left behind. Reconcile normally
            // gets there first, but it can't if Live Activities were switched on
            // mid-session, so never let the player end up with two drill timers.
            Task { await endActivities(excluding: requested.id) }
        } catch {
            activity = nil
        }
    }

    /// Push a new state to the running activity.
    func update(_ state: DrillActivityAttributes.ContentState) {
        guard let activity else { return }
        let content = ActivityContent(state: state, staleDate: staleDate(for: state))
        Task {
            await activity.update(content)
        }
    }

    /// End and dismiss the activity immediately.
    func end() {
        activity = nil
        isAdopted = false
        // Ends every drill activity the system knows about, not just the handle
        // this process happens to hold. The in-memory handle dies with the
        // process while the activity does not, so "the one I started" is not a
        // complete answer to "what is on the lock screen right now".
        Task { await endActivities(excluding: nil) }
    }

    /// Settle ActivityKit's view of the world against ours.
    ///
    /// An activity started before a crash, a jetsam kill, or a force quit is
    /// still on the lock screen when the app comes back, counting down against an
    /// `endDate` that passed long ago, and the system will keep it there for
    /// hours. Nothing used to look for one, because `activity` is only an
    /// in-memory handle and dies with the process that made it.
    ///
    /// An activity survives this pass only when something here is actually
    /// driving it, or is about to: the handle for a timer running right now, or a
    /// session the player was in the middle of moments ago and can still resume.
    /// Everything else is debris and goes immediately.
    func reconcileOrphans() async {
        let live = Activity<DrillActivityAttributes>.activities
        guard !live.isEmpty else { return }

        // The player's own record of an unfinished session is the only evidence
        // this process has that a leftover card still means something. Note that
        // ResumeStore only records multi-drill runs — a single drill never
        // adopts, which is right: there is no resume affordance for it, so its
        // card would point at nothing.
        let interruptedAt = ResumeStore.shared.session?.savedAt
        let canAdopt = interruptedAt.map { Date().timeIntervalSince($0) <= Self.adoptionWindow } ?? false

        for candidate in live {
            let isMine = candidate.id == activity?.id

            if isWritable(candidate) {
                // A timer this process is running. Leave it entirely alone.
                if isMine && !isAdopted { continue }

                // A card adopted on an earlier pass, still backed by a session the
                // player can return to. Once that stops being true it falls
                // through below and goes.
                if isMine && canAdopt { continue }

                // Adopt at most one leftover: two simultaneous drill timers were
                // never legitimate, so anything past the first is debris.
                if !isMine && canAdopt && activity == nil {
                    adopt(candidate)
                    continue
                }
            }

            if isMine { forgetHandle() }

            // Already gone from the lock screen — ending it again would do
            // nothing. Anything else, including a card the system itself ended
            // and would otherwise leave sitting there for hours, is dismissed on
            // the spot rather than left for the player to find and wonder about.
            guard candidate.activityState != .dismissed else { continue }
            await candidate.end(nil, dismissalPolicy: .immediate)
        }
    }

    // MARK: - Internals

    /// Whether an activity can still be written to. `.stale` counts: the content
    /// is out of date but the card is live and an update refreshes it.
    private func isWritable(_ candidate: Activity<DrillActivityAttributes>) -> Bool {
        candidate.activityState == .active || candidate.activityState == .stale
    }

    private func forgetHandle() {
        activity = nil
        isAdopted = false
    }

    /// Take over a card left behind by the previous process and freeze it.
    ///
    /// Nothing is counting down any more, so the `endDate` it carries is in the
    /// past and the lock screen would show a timer stuck at zero. Pushing the
    /// paused presentation says what is actually true — the session stopped and
    /// is waiting on the player — and if they do take the resume card, `start()`
    /// finds this handle and writes through it.
    private func adopt(_ candidate: Activity<DrillActivityAttributes>) {
        activity = candidate
        isAdopted = true

        var frozen = candidate.content.state
        frozen.isPaused = true
        frozen.isResting = false
        frozen.phaseLabel = "Paused"
        // Keep the last remaining time we published rather than zeroing it: it is
        // where the drill genuinely stopped, and 0:00 reads as a broken card.
        frozen.pausedRemaining = max(0, frozen.pausedRemaining)
        frozen.endDate = Date()
        update(frozen)
    }

    private func endActivities(excluding keptID: String?) async {
        for other in Activity<DrillActivityAttributes>.activities
        where other.id != keptID && other.activityState != .dismissed {
            await other.end(nil, dismissalPolicy: .immediate)
        }
    }

    /// When the content on the lock screen stops being trustworthy.
    ///
    /// The old code passed `nil`, which means "never goes stale" — so a card
    /// abandoned by a crash stayed indistinguishable from a live one for as long
    /// as the system kept it. A stale date bounded by the phase we just published
    /// means even a card reconcile never reaches gives up pretending.
    private func staleDate(for state: DrillActivityAttributes.ContentState) -> Date {
        if state.isPaused {
            let remaining = TimeInterval(max(0, state.pausedRemaining))
            return Date().addingTimeInterval(remaining + Self.pausedStaleWindow)
        }
        return max(state.endDate, Date()).addingTimeInterval(Self.runningStaleSlack)
    }
}
