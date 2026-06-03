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
                    .fill(color(for: index))
                    .frame(height: 3)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func color(for index: Int) -> Color {
        if index <= done {
            return .white
        } else if index == current {
            return Color.white.opacity(0.45)
        } else {
            return DS.Colors.Line.subtle
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
