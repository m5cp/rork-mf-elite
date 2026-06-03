//
//  ProgressTabView.swift
//  MFElite
//

import SwiftUI

struct ProgressTabView: View {
    var body: some View {
        NavigationStack {
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

                    NavigationLink(value: StreakRoute()) {
                        streakEntry
                    }
                    .buttonStyle(PressableButtonStyle())
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DS.Spacing.s20)
                .padding(.top, DS.Spacing.s24)
                .padding(.bottom, 120)
            }
            .background(DS.Colors.Bg.base)
            .navigationBarHidden(true)
            .navigationDestination(for: StreakRoute.self) { _ in
                StreakDetailView()
            }
        }
    }

    private var streakEntry: some View {
        Card(raised: true) {
            HStack(spacing: DS.Spacing.s16) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(DS.Colors.Ink.primary)
                    .frame(width: 44, height: 44)
                    .background(DS.Colors.Bg.raised)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: DS.Spacing.s4) {
                    Eyebrow(text: "Streak")
                    Text("View your streak")
                        .style(.title3)
                        .foregroundStyle(DS.Colors.Ink.primary)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DS.Colors.Ink.quaternary)
            }
        }
    }
}

#Preview {
    ProgressTabView()
        .preferredColorScheme(.dark)
}
