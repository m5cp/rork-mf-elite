//
//  CoachRosterView.swift
//  MFElite
//
//  Squad roster for the coach workspace. Reads the real shareable roster from
//  Supabase (no PII) and shows a single clearly-marked example entry that never
//  appears in the player app. Coaches can add, edit, and reset players.
//

import SwiftUI

struct CoachRosterView: View {
    @State private var vm = CoachRosterViewModel()
    @State private var showAdd = false
    @State private var selected: PlayerProfileRow?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header

                if vm.players.isEmpty {
                    emptyState
                } else {
                    rosterSection
                }

                if !vm.pendingInvites.isEmpty {
                    invitesSection
                }
            }
            .padding(.bottom, 120)
        }
        .background(DS.Colors.Bg.base)
        .scrollIndicators(.hidden)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .bottom) { addBar }
        .sheet(isPresented: $showAdd) {
            CoachAddPlayerView(vm: vm)
        }
        .sheet(item: $selected) { player in
            CoachPlayerDetailView(vm: vm, player: player)
        }
        .task { await vm.load() }
        .refreshable { await vm.load() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s8) {
            Eyebrow(text: "Squad")
            Text("Roster")
                .style(.hero)
                .foregroundStyle(DS.Colors.Ink.primary)
            Text("Training info only · no personal or billing data")
                .style(.foot)
                .foregroundStyle(DS.Colors.Ink.tertiary)
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s24)
    }

    // MARK: - Roster

    private var rosterSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s8) {
            Eyebrow(text: "\(vm.players.count) Players")
            VStack(spacing: 0) {
                ForEach(Array(vm.players.enumerated()), id: \.element.id) { index, player in
                    Button { selected = player } label: {
                        playerRow(player, isExample: false)
                    }
                    .buttonStyle(PressableButtonStyle())
                    if index != vm.players.count - 1 { Hairline() }
                }
            }
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s32)
    }

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.s8) {
            Image(systemName: "person.3")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(DS.Colors.Ink.tertiary)
            Text("No players yet")
                .style(.title3)
                .foregroundStyle(DS.Colors.Ink.primary)
            Text("Add a player to generate an invite code they can redeem on sign-in.")
                .style(.foot)
                .foregroundStyle(DS.Colors.Ink.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.s48)
        .padding(.horizontal, DS.Spacing.s20)
    }

    private var invitesSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s8) {
            Eyebrow(text: "Pending Invites")
            VStack(spacing: 0) {
                ForEach(Array(vm.pendingInvites.enumerated()), id: \.element.id) { index, invite in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(invite.displayName ?? "New player")
                                .style(.foot)
                                .foregroundStyle(DS.Colors.Ink.primary)
                            Text(invite.code)
                                .font(.system(size: 15, weight: .bold, design: .monospaced))
                                .foregroundStyle(DS.Colors.Ink.secondary)
                        }
                        Spacer(minLength: 0)
                        Text("Awaiting claim")
                            .style(.microSm)
                            .foregroundStyle(DS.Colors.Ink.quaternary)
                    }
                    .padding(.vertical, DS.Spacing.s12)
                    if index != vm.pendingInvites.count - 1 { Hairline() }
                }
            }
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s32)
    }

    // MARK: - Add bar

    private var addBar: some View {
        PrimaryButton(label: "Add player") { showAdd = true }
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.bottom, DS.Spacing.s24)
    }

    // MARK: - Row

    private func playerRow(_ player: PlayerProfileRow, isExample: Bool) -> some View {
        HStack(spacing: DS.Spacing.s16) {
            Avatar(size: 40, initials: player.initials ?? "?")
            VStack(alignment: .leading, spacing: DS.Spacing.s4) {
                Text(player.displayName?.isEmpty == false ? (player.displayName ?? "") : "Unclaimed")
                    .style(.title3)
                    .foregroundStyle(DS.Colors.Ink.primary)
                Eyebrow(text: rosterMeta(player))
            }
            Spacer(minLength: 0)
            if !isExample {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DS.Colors.Ink.quaternary)
            }
        }
        .padding(.horizontal, isExample ? DS.Spacing.s16 : 0)
        .padding(.vertical, DS.Spacing.s16)
        .contentShape(Rectangle())
    }

    private func rosterMeta(_ player: PlayerProfileRow) -> String {
        var parts: [String] = []
        if let username = player.username, !username.isEmpty { parts.append("@\(username)") }
        if let kit = player.kitNumber, !kit.isEmpty { parts.append("No. \(kit)") }
        if let position = player.position, !position.isEmpty { parts.append(position) }
        return parts.isEmpty ? "Awaiting details" : parts.joined(separator: " · ")
    }
}

#Preview {
    NavigationStack {
        CoachRosterView()
    }
    .preferredColorScheme(.dark)
}
