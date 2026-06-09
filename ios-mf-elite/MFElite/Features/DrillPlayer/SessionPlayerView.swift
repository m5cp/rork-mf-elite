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

    @Environment(\.dismiss) private var dismiss

    init(queue: TrainingQueue) {
        _queue = State(initialValue: queue)
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
                            onSessionComplete: {
                                withAnimation(DS.Motion.standardSpring) { showSummary = true }
                            }
                        )
                    } else {
                        DrillPlayerView(
                            context: context,
                            queue: queue,
                            onAdvance: advance,
                            onExit: { dismiss() },
                            onSessionComplete: {
                                withAnimation(DS.Motion.standardSpring) { showSummary = true }
                            }
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
}
