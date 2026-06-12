//
//  SessionPlayerView.swift
//  MFElite
//
//  The single full-screen container that runs a TrainingQueue. It owns the
//  queue and renders the per-drill player for the current drill, swapping the
//  view in place when advancing — never dismissing and re-presenting.
//

import SwiftUI

struct SessionPlayerView: View {
    @State private var queue: TrainingQueue
    @State private var showSummary = false

    /// When set, the final "Finish session" tap calls this instead of showing the
    /// built-in summary — lets a custom flow (e.g. Match Day) own its own finish.
    private let onComplete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    init(queue: TrainingQueue, onComplete: (() -> Void)? = nil) {
        _queue = State(initialValue: queue)
        self.onComplete = onComplete
    }

    var body: some View {
        ZStack {
            DS.Colors.Bg.base.ignoresSafeArea()

            if showSummary {
                SessionSummaryView(queue: queue) { dismiss() }
                    .transition(.opacity)
            } else if let context = queue.current {
                Group {
                    if context.drill.isMentalExercise {
                        MentalExercisePlayerView(
                            context: context,
                            queue: queue,
                            onAdvance: advance,
                            onExit: { dismiss() },
                            onSessionComplete: finishSession
                        )
                    } else {
                        DrillPlayerView(
                            context: context,
                            queue: queue,
                            onAdvance: advance,
                            onExit: { dismiss() },
                            onSessionComplete: finishSession
                        )
                    }
                }
                .id(queue.currentIndex)
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    )
                )
            }
        }
        .preferredColorScheme(.dark)
    }

    private func advance() {
        withAnimation(DS.Motion.standardSpring) {
            queue.advance()
        }
    }

    private func finishSession() {
        if let onComplete {
            onComplete()
        } else {
            withAnimation(DS.Motion.standardSpring) { showSummary = true }
        }
    }
}
