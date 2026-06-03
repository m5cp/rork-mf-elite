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

    var body: some View {
        ZStack {
            Circle()
                .stroke(DS.Colors.Line.subtle, lineWidth: strokeWidth)

            Circle()
                .trim(from: 0, to: max(0, min(1, progress)))
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value)")
        .accessibilityValue("\(Int((max(0, min(1, progress)) * 100).rounded())) percent")
    }
}

#Preview {
    ZStack {
        DS.Colors.Bg.base.ignoresSafeArea()
        PitchRing(progress: 0.68, value: "68", label: "Match Fit")
    }
}
