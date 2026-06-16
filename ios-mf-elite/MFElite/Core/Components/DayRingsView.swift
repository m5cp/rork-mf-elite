//
//  DayRingsView.swift
//  MFElite
//
//  Three concentric daily-training rings (Train / Drills / Mind) in a monochrome
//  weight stack — outer thickest. Reused at large size on the Progress header,
//  small in the 7-day strip and calendar cells.
//

import SwiftUI

struct DayRingsView: View {
    let rings: DailyRings
    var size: CGFloat = 90
    var showCheckmarks: Bool = true
    /// When true, the rings sweep from empty to their value once on appear.
    var animateOnAppear: Bool = false

    @State private var fill: Double = 1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Outer stroke width; inner rings step down slightly for visual weight.
    private var baseLine: CGFloat { max(2, size * 0.12) }
    private var gap: CGFloat { max(1.5, size * 0.05) }

    private var trainTint: Color { Color.white }
    private var drillTint: Color { Color.white.opacity(0.68) }
    private var mindTint: Color { Color.white.opacity(0.42) }

    var body: some View {
        ZStack {
            ringLayer(progress: rings.trainProgress, inset: 0, line: baseLine, tint: trainTint, closed: rings.trainClosed)
            ringLayer(progress: rings.drillProgress, inset: baseLine + gap, line: baseLine * 0.9, tint: drillTint, closed: rings.drillClosed)
            ringLayer(progress: rings.mindProgress, inset: (baseLine + gap) * 2, line: baseLine * 0.8, tint: mindTint, closed: rings.mindClosed)
        }
        .frame(width: size, height: size)
        .onAppear {
            guard animateOnAppear, !reduceMotion else { return }
            fill = 0
            withAnimation(.spring(response: 0.7, dampingFraction: 0.85).delay(0.15)) {
                fill = 1
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Daily rings")
        .accessibilityValue(
            "Train ring, \(rings.trainMinutes) of \(DailyRings.trainGoalMinutes) minutes. "
            + "Drills ring, \(rings.drillCount) of \(DailyRings.drillGoal) drills. "
            + "Mind ring, \(rings.mindCount) of \(DailyRings.mindGoal) exercise."
        )
    }

    private func ringLayer(progress: Double, inset: CGFloat, line: CGFloat, tint: Color, closed: Bool) -> some View {
        ZStack {
            Circle()
                .stroke(DS.Colors.Line.subtle, lineWidth: line)

            Circle()
                .trim(from: 0, to: max(0.0001, min(1, progress * fill)))
                .stroke(tint, style: StrokeStyle(lineWidth: line, lineCap: .round))
                .rotationEffect(.degrees(-90))

            if closed && showCheckmarks && size >= 64 {
                Circle()
                    .fill(tint)
                    .frame(width: line * 0.7, height: line * 0.7)
                    .offset(y: -(size / 2 - inset - line / 2))
            }
        }
        .padding(inset)
    }
}

#Preview {
    ZStack {
        DS.Colors.Bg.base.ignoresSafeArea()
        HStack(spacing: 24) {
            DayRingsView(rings: DailyRings(trainMinutes: 20, drillCount: 3, mindCount: 1), size: 90)
            DayRingsView(rings: DailyRings(trainMinutes: 8, drillCount: 1, mindCount: 0), size: 44)
            DayRingsView(rings: DailyRings(), size: 28)
        }
    }
}
