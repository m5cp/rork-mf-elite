//
//  ProfileTabView.swift
//  MFElite
//
//  Tab 4 — the player card and the gateway to progression, certs, streak, and settings.
//

import SwiftUI
import SwiftData

/// Lightweight route to a not-yet-built profile destination.
struct ProfilePlaceholderRoute: Hashable {
    let title: String
    let note: String
}

struct ProfileTabView: View {
    @Query private var players: [PlayerState]
    @Environment(SubscriptionService.self) private var subscription

    private var currentRank: AcademyRank {
        AcademyRank.rank(for: players.first?.xp ?? 0)
    }

    private var xp: Int { players.first?.xp ?? 0 }

    private var profile = PlayerProfileStore.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    playerCard
                    menu
                }
                .padding(.bottom, 120)
            }
            .background(DS.Colors.Bg.base)
            .scrollIndicators(.hidden)
            .navigationBarHidden(true)
            .navigationDestination(for: ProgressionRoute.self) { _ in
                AcademyProgressionView()
            }
            .navigationDestination(for: CertificationsRoute.self) { _ in
                CertificationsView()
            }
            .navigationDestination(for: RankDetailRoute.self) { _ in
                RankDetailView()
            }
            .navigationDestination(for: BadgesRoute.self) { _ in
                BadgesLockerView()
            }
            .navigationDestination(for: StreakRoute.self) { _ in
                StreakDetailView()
            }
            .navigationDestination(for: FamilyRoute.self) { _ in
                FamilyManagementView()
            }
            .navigationDestination(for: ParentReportRoute.self) { _ in
                ParentReportView()
            }
            .navigationDestination(for: SettingsRoute.self) { _ in
                SettingsView()
            }
            .navigationDestination(for: ProfilePlaceholderRoute.self) { route in
                ProfilePlaceholder(title: route.title, note: route.note)
            }
        }
    }

    // MARK: - Player Card

    private var playerCard: some View {
        VStack(spacing: 0) {
            Monogram(size: 80, initials: profile.initials, kit: profile.kitNumber)

            Text(profile.displayName)
                .style(.title1)
                .foregroundStyle(DS.Colors.Ink.primary)
                .padding(.top, DS.Spacing.s12)

            Eyebrow(text: "Rank \(currentRank.numeral) · \(currentRank.title) · \(xp.formatted()) XP")
                .padding(.top, DS.Spacing.s8)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s16)
    }

    // MARK: - Menu

    private var menu: some View {
        VStack(spacing: 0) {
            if !subscription.isElite {
                upgradeRow
                Hairline()
            }
            menuRow(icon: "chart.line.uptrend.xyaxis", label: "Academy Progression",
                    route: ProgressionRoute())
            Hairline()
            menuRow(icon: "rosette", label: "Certifications",
                    route: CertificationsRoute())
            Hairline()
            menuRow(icon: "medal", label: "Rank & XP",
                    route: RankDetailRoute())
            Hairline()
            menuRow(icon: "shield.lefthalf.filled", label: "Badges",
                    route: BadgesRoute())
            Hairline()
            menuRow(icon: "flame", label: "Streak",
                    route: StreakRoute())
            Hairline()
            menuRow(icon: "person.2", label: "Family",
                    route: FamilyRoute())
            Hairline()
            menuRow(icon: "gearshape", label: "Settings",
                    route: SettingsRoute())
            Hairline()
            menuRow(icon: "doc.text", label: "Parent Report",
                    route: ParentReportRoute())
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s32)
    }

    /// Upgrade entry point shown only to free (Trialist) players.
    private var upgradeRow: some View {
        Button {
            subscription.presentPaywall()
        } label: {
            HStack(spacing: DS.Spacing.s16) {
                Image(systemName: "star.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DS.Colors.Ink.primary)
                    .frame(width: 36, height: 36)
                    .background(DS.Colors.Bg.raised)
                    .clipShape(Circle())

                Text("Upgrade to Elite")
                    .style(.title3)
                    .foregroundStyle(DS.Colors.Ink.primary)

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DS.Colors.Ink.quaternary)
            }
            .padding(.vertical, DS.Spacing.s16)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel("Upgrade to Elite")
    }

    private func menuRow<R: Hashable>(icon: String, label: String, route: R) -> some View {
        NavigationLink(value: route) {
            HStack(spacing: DS.Spacing.s16) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DS.Colors.Ink.primary)
                    .frame(width: 36, height: 36)
                    .background(DS.Colors.Bg.raised)
                    .clipShape(Circle())

                Text(label)
                    .style(.title3)
                    .foregroundStyle(DS.Colors.Ink.primary)

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DS.Colors.Ink.quaternary)
            }
            .padding(.vertical, DS.Spacing.s16)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
    }
}

// MARK: - Placeholder Destination

private struct ProfilePlaceholder: View {
    let title: String
    let note: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.s8) {
                Eyebrow(text: title)
                Text(title)
                    .style(.hero)
                    .foregroundStyle(DS.Colors.Ink.primary)
                Text(note)
                    .style(.body)
                    .foregroundStyle(DS.Colors.Ink.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.top, DS.Spacing.s24)
        }
        .background(DS.Colors.Bg.base)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    ProfileTabView()
        .preferredColorScheme(.dark)
        .modelContainer(for: [
            Discipline.self, Category.self, MasteryLevel.self,
            Drill.self, DrillProgress.self, PlayerState.self
        ])
}
