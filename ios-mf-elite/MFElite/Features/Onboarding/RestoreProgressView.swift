//
//  RestoreProgressView.swift
//  MFElite
//
//  Shown once, after sign-in on a fresh install, when the cloud holds more
//  progress than this device. Offers to pull the remote rank / XP / streak down
//  (Restore) or keep the clean local slate (Start fresh). Presented before the
//  Today tab is interacted with so restored data is in place.
//

import SwiftUI
import SwiftData

struct RestoreProgressView: View {
    @Environment(\.modelContext) private var modelContext

    let remote: RemotePlayerState

    private var rank: AcademyRank { AcademyRank.rank(for: remote.xp) }

    var body: some View {
        ZStack {
            DS.Colors.Bg.base.ignoresSafeArea()

            VStack(alignment: .leading, spacing: DS.Spacing.s16) {
                Spacer()

                Eyebrow(text: "Welcome back")

                Text("Restore your progress")
                    .style(.title1)
                    .foregroundStyle(DS.Colors.Ink.primary)

                Text("We found a saved profile in your account. Pick up right where you left off.")
                    .style(.body)
                    .foregroundStyle(DS.Colors.Ink.secondary)

                statCard
                    .padding(.top, DS.Spacing.s8)

                Spacer()

                PrimaryButton(label: "Restore my progress") {
                    SyncRestore.shared.restore()
                }

                GhostButton(label: "Start fresh") {
                    SyncRestore.shared.startFresh(context: modelContext)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.bottom, DS.Spacing.s24)
        }
        .preferredColorScheme(.dark)
    }

    private var statCard: some View {
        HStack(spacing: 0) {
            statColumn(value: "\(rank.numeral)", label: rank.title)
            divider
            statColumn(value: "\(remote.xp)", label: "XP")
            divider
            statColumn(value: "\(remote.streak)", label: remote.streak == 1 ? "day streak" : "day streak")
        }
        .padding(.vertical, DS.Spacing.s20)
        .frame(maxWidth: .infinity)
        .background(DS.Colors.Bg.elevated)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
    }

    private func statColumn(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(DS.Colors.Ink.primary)
            Text(label)
                .style(.foot)
                .foregroundStyle(DS.Colors.Ink.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle()
            .fill(DS.Colors.Ink.quaternary.opacity(0.3))
            .frame(width: 1, height: 28)
    }
}
