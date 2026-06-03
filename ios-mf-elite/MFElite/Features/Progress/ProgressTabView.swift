//
//  ProgressTabView.swift
//  MFElite
//

import SwiftUI

struct ProgressTabView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.s24) {
                VStack(alignment: .leading, spacing: DS.Spacing.s8) {
                    Eyebrow(text: "Tab 3 · Progress")
                    Text("Your Progress")
                        .style(.title1)
                        .foregroundStyle(DS.Colors.Ink.primary)
                    Text("Rank, certifications, streak, and development milestones. Coming in a later prompt.")
                        .style(.body)
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                }

                BigStat(label: "Academy XP", value: "3,620")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.top, DS.Spacing.s24)
            .padding(.bottom, 120)
        }
        .background(DS.Colors.Bg.base)
    }
}

#Preview {
    ProgressTabView()
        .preferredColorScheme(.dark)
}
