//
//  PitchRing.swift
//  MFElite
//
//  A clean stroked circular progress ring with centered stats.
//

import SwiftUI

struct PitchRing: View {
    var size: CGFloat = 110
    let progress: Double
    var strokeWidth: CGFloat = 8
    let value: String
    let label: String

    @State private var shown: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var clamped: Double { max(0, min(1, progress)) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(DS.Colors.Line.subtle, lineWidth: strokeWidth)

            Circle()
                .trim(from: 0, to: shown)
                .stroke(
                    Color.white,
                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .butt)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: DS.Spacing.s4) {
                Text(value)
                    .style(.num(size: size * 0.32))
                    .foregroundStyle(DS.Colors.Ink.primary)
                Eyebrow(text: label)
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            guard !reduceMotion else { shown = clamped; return }
            shown = 0
            withAnimation(.spring(response: 0.7, dampingFraction: 0.85).delay(0.15)) {
                shown = clamped
            }
        }
        .onChange(of: progress) { _, _ in
            withAnimation(reduceMotion ? nil : DS.Motion.standardSpring) { shown = clamped }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value)")
        .accessibilityValue("\(Int((clamped * 100).rounded())) percent")
    }
}

#Preview {
    ZStack {
        DS.Colors.Bg.base.ignoresSafeArea()
        PitchRing(progress: 0.68, value: "68", label: "Match Fit")
    }
}
