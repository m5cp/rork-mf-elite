//
//  CoachTeamSnapshotView.swift
//  MFElite
//
//  A one-glance weekly snapshot of the whole roster for the coach: how many
//  players need attention, average training minutes per player, active players
//  this week, and the most / least active athletes. Read-only, fails soft.
//

import SwiftUI

struct CoachTeamSnapshotRoute: Hashable {}

struct CoachTeamSnapshotView: View {
    @Bindable var model: CoachViewModel

    private var snap: TeamSnapshot { model.teamSnapshot }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.s24) {
                header

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DS.Spacing.s12) {
                    statCard(value: "\(snap.activeThisWeek)", label: "Active this week", tint: nil)
                    statCard(value: "\(snap.needsAttentionCount)", label: "Need attention",
                             tint: snap.needsAttentionCount > 0 ? Color(hex: "#FF453A") : nil)
                    statCard(value: CoachFormat.minutes(snap.avgMinutesPerPlayer), label: "Avg / player", tint: nil)
                    statCard(value: CoachFormat.minutes(snap.teamMinutesThisWeek), label: "Team minutes", tint: nil)
                }

                highlightsSection
                needsAttentionSection
            }
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.top, DS.Spacing.s16)
            .padding(.bottom, 120)
        }
        .background(DS.Colors.Bg.base)
        .scrollIndicators(.hidden)
        .navigationTitle("Team Snapshot")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s4) {
            Text("This Week")
                .style(.title1)
                .foregroundStyle(DS.Colors.Ink.primary)
            Text("\(snap.totalPlayers) \(snap.totalPlayers == 1 ? "player" : "players") on your roster")
                .style(.foot)
                .foregroundStyle(DS.Colors.Ink.tertiary)
        }
    }

    private func statCard(value: String, label: String, tint: Color?) -> some View {
        Card(padding: DS.Spacing.s16) {
            VStack(alignment: .leading, spacing: DS.Spacing.s4) {
                Text(value)
                    .style(.num(size: 30))
                    .foregroundStyle(tint ?? DS.Colors.Ink.primary)
                Text(label.uppercased())
                    .style(.micro)
                    .foregroundStyle(DS.Colors.Ink.quaternary)
            }
        }
    }

    @ViewBuilder
    private var highlightsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s12) {
            Eyebrow(text: "Highlights")
            Card(padding: DS.Spacing.s16) {
                VStack(spacing: 0) {
                    highlightRow(icon: "flame.fill", tint: DS.Colors.Gold.base,
                                 title: "Most active",
                                 detail: snap.mostActive.map { "\($0.name) · \(CoachFormat.minutes($0.minutes))" } ?? "No activity yet")
                    Hairline()
                    highlightRow(icon: "tortoise.fill", tint: DS.Colors.Ink.tertiary,
                                 title: "Least active",
                                 detail: snap.leastActive.map { "\($0.name) · \(CoachFormat.minutes($0.minutes))" } ?? "—")
                }
            }
        }
    }

    private func highlightRow(icon: String, tint: Color, title: String, detail: String) -> some View {
        HStack(spacing: DS.Spacing.s12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 24)
            Text(title)
                .style(.title3)
                .foregroundStyle(DS.Colors.Ink.primary)
            Spacer(minLength: DS.Spacing.s8)
            Text(detail)
                .style(.foot)
                .foregroundStyle(DS.Colors.Ink.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, DS.Spacing.s12)
    }

    @ViewBuilder
    private var needsAttentionSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s12) {
            Eyebrow(text: "Needs Attention")
            if model.needsAttention.isEmpty {
                Text("Everyone has trained this week.")
                    .style(.foot)
                    .foregroundStyle(DS.Colors.Ink.tertiary)
                    .padding(DS.Spacing.s16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DS.Colors.Bg.card)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                    .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(DS.Colors.Line.hairline, lineWidth: 1))
            } else {
                VStack(spacing: DS.Spacing.s8) {
                    ForEach(model.needsAttention) { player in
                        NavigationLink(value: player) {
                            CoachRosterRow(player: player)
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                }
            }
        }
    }
}
