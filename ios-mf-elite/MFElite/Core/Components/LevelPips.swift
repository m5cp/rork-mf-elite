//
//  LevelPips.swift
//  MFElite
//
//  A horizontal segmented progress bar showing mastery level completion.
//

import SwiftUI

struct LevelPips: View {
    let total: Int
    let done: Int
    let current: Int

    var body: some View {
        HStack(spacing: DS.Spacing.s4) {
            ForEach(0..<max(0, total), id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(fill(for: index))
                    .frame(height: 3)
                    .frame(maxWidth: .infinity)
                    .shadow(color: index <= done ? DS.Colors.Gold.base.opacity(0.35) : .clear, radius: 4)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Level progress")
        .accessibilityValue("\(max(0, done)) of \(max(0, total)) complete")
    }

    private func fill(for index: Int) -> AnyShapeStyle {
        if index <= done {
            return AnyShapeStyle(DS.Colors.Gold.progressGradient)
        } else if index == current {
            return AnyShapeStyle(DS.Colors.Gold.base.opacity(0.42))
        } else {
            return AnyShapeStyle(DS.Colors.Line.subtle)
        }
    }
}

#Preview {
    ZStack {
        DS.Colors.Bg.base.ignoresSafeArea()
        LevelPips(total: 10, done: 4, current: 5)
            .padding(.horizontal, DS.Spacing.s20)
    }
}
