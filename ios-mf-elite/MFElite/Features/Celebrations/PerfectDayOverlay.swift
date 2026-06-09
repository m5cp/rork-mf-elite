//
//  PerfectDayOverlay.swift
//  MFElite
//
//  A brief celebratory overlay shown the first time all three daily rings close.
//

import SwiftUI

struct PerfectDayOverlay: View {
    var onDismiss: () -> Void

    @State private var reveal = false

    private let closedRings = DailyRings(
        trainMinutes: DailyRings.trainGoalMinutes,
        drillCount: DailyRings.drillGoal,
        mindCount: DailyRings.mindGoal
    )

    var body: some View {
        ZStack {
            Color.black.opacity(0.78).ignoresSafeArea()

            VStack(spacing: DS.Spacing.s24) {
                DayRingsView(rings: closedRings, size: 150)
                    .scaleEffect(reveal ? 1 : 0.4)
                    .opacity(reveal ? 1 : 0)

                VStack(spacing: DS.Spacing.s8) {
                    Eyebrow(text: "All Rings Closed")
                    Text("Perfect Day")
                        .style(.title1)
                        .foregroundStyle(DS.Colors.Ink.primary)
                    Text("Train, drills and mind — all done today.")
                        .style(.body)
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                        .multilineTextAlignment(.center)
                }
                .opacity(reveal ? 1 : 0)
            }
            .padding(.horizontal, DS.Spacing.s40)
        }
        .contentShape(Rectangle())
        .onTapGesture { onDismiss() }
        .onAppear {
            withAnimation(DS.Motion.celebrationSpring.delay(0.1)) { reveal = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) { onDismiss() }
        }
    }
}
