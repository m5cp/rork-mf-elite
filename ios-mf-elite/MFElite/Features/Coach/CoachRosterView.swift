//
//  CoachRosterView.swift
//  MFElite
//
//  Display-only squad roster for the coach workspace.
//

import SwiftUI

private struct RosterPlayer: Identifiable {
    let id = UUID()
    let name: String
    let initials: String
    let rank: String
}

struct CoachRosterView: View {
    private let players: [RosterPlayer] = [
        RosterPlayer(name: "Player One", initials: "P1", rank: "Rank II · Cadet"),
        RosterPlayer(name: "Marcus Bell", initials: "MB", rank: "Rank III · Prospect"),
        RosterPlayer(name: "Aiden Cole", initials: "AC", rank: "Rank I · Trialist"),
        RosterPlayer(name: "Diego Santos", initials: "DS", rank: "Rank IV · Starter"),
        RosterPlayer(name: "Theo Walsh", initials: "TW", rank: "Rank II · Cadet"),
        RosterPlayer(name: "Noah Reed", initials: "NR", rank: "Rank I · Trialist")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: DS.Spacing.s8) {
                    Eyebrow(text: "Squad")
                    Text("Roster")
                        .style(.hero)
                        .foregroundStyle(DS.Colors.Ink.primary)
                }
                .padding(.horizontal, DS.Spacing.s20)
                .padding(.top, DS.Spacing.s24)

                VStack(spacing: 0) {
                    ForEach(Array(players.enumerated()), id: \.element.id) { index, player in
                        playerRow(player)
                        if index != players.count - 1 { Hairline() }
                    }
                }
                .padding(.horizontal, DS.Spacing.s20)
                .padding(.top, DS.Spacing.s24)
            }
            .padding(.bottom, 120)
        }
        .background(DS.Colors.Bg.base)
        .scrollIndicators(.hidden)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func playerRow(_ player: RosterPlayer) -> some View {
        HStack(spacing: DS.Spacing.s16) {
            Avatar(size: 40, initials: player.initials)
            VStack(alignment: .leading, spacing: DS.Spacing.s4) {
                Text(player.name)
                    .style(.title3)
                    .foregroundStyle(DS.Colors.Ink.primary)
                Eyebrow(text: player.rank)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DS.Colors.Ink.quaternary)
        }
        .padding(.vertical, DS.Spacing.s16)
        .contentShape(Rectangle())
    }
}

#Preview {
    NavigationStack {
        CoachRosterView()
    }
    .preferredColorScheme(.dark)
}
