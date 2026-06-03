//
//  Sep.swift
//  MFElite
//
//  A small centered dot separator used between inline stats.
//

import SwiftUI

struct Sep: View {
    var body: some View {
        Text("·")
            .style(.micro)
            .foregroundStyle(DS.Colors.Ink.quaternary)
    }
}

#Preview {
    ZStack {
        DS.Colors.Bg.base.ignoresSafeArea()
        HStack(spacing: DS.Spacing.s8) {
            Eyebrow(text: "3,620 XP")
            Sep()
            Eyebrow(text: "14-Day Streak")
        }
    }
}
