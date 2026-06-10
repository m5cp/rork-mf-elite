//
//  ProfileTabView.swift
//  MFElite
//
//  Tab 4 — the player card and the gateway to progression, certs, streak, and settings.
//

import SwiftUI
import SwiftData

struct ProfileTabView: View {
    @Query private var players: [PlayerState]
    @Environment(SubscriptionService.self) private var subscription

    private var currentRank: AcademyRank {
        AcademyRank.rank(for: players.first?.xp ?? 0)
    }

    private var xp: Int { players.first?.xp ?? 0 }

    private var profile = PlayerProfileStore.shared

    @State private var showAvatarPicker = false
    @State private var showEditProfile = false

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
            .navigationDestination(for: SettingsRoute.self) { _ in
                SettingsView()
            }
            .navigationDestination(for: PlayerCardRoute.self) { _ in
                PlayerCardView()
            }
            .sheet(isPresented: $showAvatarPicker) {
                AvatarPickerSheet()
            }
            .sheet(isPresented: $showEditProfile) {
                EditProfileSheet()
            }
        }
    }

    // MARK: - Player Card

    private var playerCard: some View {
        VStack(spacing: 0) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showAvatarPicker = true
            } label: {
                AvatarView(
                    selection: profile.avatar,
                    photo: profile.avatarPhoto,
                    initials: profile.initials,
                    kit: profile.kitNumber,
                    size: 104,
                    shape: .circle
                )
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 30, height: 30)
                        .background(Color.white)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(DS.Colors.Bg.base, lineWidth: 2))
                }
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel("Change avatar")

            Text(profile.displayName)
                .style(.display)
                .foregroundStyle(DS.Colors.Ink.primary)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .padding(.top, DS.Spacing.s16)
                .padding(.horizontal, DS.Spacing.s16)

            rankBadge
                .padding(.top, DS.Spacing.s12)

            statStrip
                .padding(.top, DS.Spacing.s24)

            HStack(spacing: DS.Spacing.s12) {
                NavigationLink(value: PlayerCardRoute()) {
                    HStack(spacing: DS.Spacing.s8) {
                        Image(systemName: "rectangle.portrait.on.rectangle.portrait.fill")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Player Card")
                            .style(.foot)
                    }
                    .foregroundStyle(DS.Colors.Ground.primary)
                    .padding(.vertical, DS.Spacing.s12)
                    .padding(.horizontal, DS.Spacing.s20)
                    .background(Color.white)
                    .clipShape(Capsule())
                }
                .buttonStyle(PressableButtonStyle())
                .simultaneousGesture(TapGesture().onEnded {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                })

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showEditProfile = true
                } label: {
                    HStack(spacing: DS.Spacing.s8) {
                        Image(systemName: "pencil")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Edit")
                            .style(.foot)
                    }
                    .foregroundStyle(DS.Colors.Ink.primary)
                    .padding(.vertical, DS.Spacing.s12)
                    .padding(.horizontal, DS.Spacing.s20)
                    .overlay(Capsule().stroke(DS.Colors.Line.subtle, lineWidth: 1))
                }
                .buttonStyle(PressableButtonStyle())
            }
            .padding(.top, DS.Spacing.s20)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s16)
    }

    private var rankBadge: some View {
        HStack(spacing: DS.Spacing.s8) {
            Text("RANK \(currentRank.numeral)")
                .style(.micro)
                .foregroundStyle(.black)
                .padding(.horizontal, DS.Spacing.s12)
                .padding(.vertical, 5)
                .background(Color.white)
                .clipShape(Capsule())
            Text(currentRank.title.uppercased())
                .style(.micro)
                .foregroundStyle(DS.Colors.Ink.tertiary)
        }
    }

    private var statStrip: some View {
        HStack(spacing: 0) {
            profileStat(value: xp.formatted(), label: "XP")
            statDivider
            profileStat(value: "\(players.first?.streak ?? 0)", label: "DAY STREAK")
            statDivider
            profileStat(value: currentRank.numeral, label: "RANK")
        }
        .padding(.vertical, DS.Spacing.s16)
        .background(DS.Colors.Bg.card)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.lg).stroke(DS.Colors.Line.hairline, lineWidth: 1))
    }

    private func profileStat(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .style(.num(size: 26))
                .foregroundStyle(DS.Colors.Ink.primary)
            Text(label)
                .style(.microSm)
                .foregroundStyle(DS.Colors.Ink.quaternary)
        }
        .frame(maxWidth: .infinity)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(DS.Colors.Line.hairline)
            .frame(width: 1, height: 32)
    }

    // MARK: - Menu

    private var menu: some View {
        VStack(spacing: 0) {
            if !subscription.hasFullAccess {
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
            menuRow(icon: "gearshape", label: "Settings",
                    route: SettingsRoute())
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

#Preview {
    ProfileTabView()
        .preferredColorScheme(.dark)
        .modelContainer(for: [
            Discipline.self, Category.self, MasteryLevel.self,
            Drill.self, DrillProgress.self, PlayerState.self
        ])
}
