//
//  AcademyTodayView.swift
//  MFElite
//
//  Tab 1 — the daily dashboard: greeting, standard, goals, pathway, recommendations.
//

import SwiftUI
import SwiftData

struct AcademyTodayView: View {
    @Query(sort: \Discipline.sortIndex) private var disciplines: [Discipline]
    @Query private var players: [PlayerState]
    @Query private var progress: [DrillProgress]
    @Environment(SubscriptionService.self) private var subscription
    @State private var profile = PlayerProfileStore.shared
    @State private var announcements = AnnouncementStore.shared
    @State private var auth = AuthService.shared

    private var viewModel: AcademyTodayViewModel {
        AcademyTodayViewModel(
            disciplines: disciplines,
            xp: players.first?.xp ?? 0,
            streak: players.first?.streak ?? 0,
            progress: progress
        )
    }

    var body: some View {
        let vm = viewModel
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    topBar(vm)
                    if profile.shouldPromptProfileCompletion {
                        completeProfileBanner
                    }
                    salutation(vm)
                    announcementCards
                    dailyStandard(vm)
                    goalsCard(vm)
                    continuePathway(vm)
                    recommendedSection(vm)
                }
                .padding(.bottom, 120)
            }
            .background(DS.Colors.Bg.base)
            .scrollIndicators(.hidden)
            .navigationBarHidden(true)
            .task { await announcements.refresh() }
            .navigationDestination(for: LevelRoute.self) { route in
                LevelView(level: route.level, category: route.category, discipline: route.discipline)
            }
            .navigationDestination(for: DrillRoute.self) { route in
                DrillDetailView(drill: route.drill, level: route.level, category: route.category, discipline: route.discipline)
            }
            .navigationDestination(for: StreakRoute.self) { _ in
                StreakDetailView()
            }
            .navigationDestination(for: SettingsRoute.self) { _ in
                SettingsView()
            }
        }
    }

    // MARK: - Complete-profile banner (skipped onboarding)

    private var completeProfileBanner: some View {
        Card(padding: DS.Spacing.s16) {
            HStack(spacing: DS.Spacing.s12) {
                VStack(alignment: .leading, spacing: DS.Spacing.s4) {
                    Text("Complete your profile")
                        .style(.callout)
                        .foregroundStyle(DS.Colors.Ink.primary)
                    Text("Add your name, position and kit number.")
                        .style(.micro)
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                }
                Spacer(minLength: DS.Spacing.s8)
                NavigationLink(value: SettingsRoute()) {
                    Text("Set up")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(DS.Colors.Ground.primary)
                        .padding(.vertical, DS.Spacing.s8)
                        .padding(.horizontal, DS.Spacing.s16)
                        .background(Color.white)
                        .clipShape(Capsule())
                }
                .buttonStyle(PressableButtonStyle())
                Button {
                    withAnimation(DS.Motion.standardSpring) {
                        profile.profilePromptDismissed = true
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(DS.Colors.Ink.quaternary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel("Dismiss")
            }
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s16)
    }

    // MARK: - Coach announcements

    @ViewBuilder
    private var announcementCards: some View {
        if !announcements.visible.isEmpty {
            VStack(spacing: DS.Spacing.s12) {
                ForEach(announcements.visible) { item in
                    announcementCard(item)
                }
            }
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.top, DS.Spacing.s16)
        }
    }

    private func announcementCard(_ item: SupabaseAnnouncement) -> some View {
        Card(padding: DS.Spacing.s16) {
            VStack(alignment: .leading, spacing: DS.Spacing.s4) {
                HStack(alignment: .top) {
                    Eyebrow(text: "Coach Announcement")
                    Spacer(minLength: DS.Spacing.s8)
                    Button {
                        withAnimation(DS.Motion.standardSpring) {
                            announcements.dismiss(item.id)
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(DS.Colors.Ink.quaternary)
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(PressableButtonStyle())
                    .accessibilityLabel("Dismiss announcement")
                }
                Text(item.title)
                    .style(.title3)
                    .foregroundStyle(DS.Colors.Ink.primary)
                    .padding(.top, DS.Spacing.s4)
                if let body = item.body, !body.isEmpty {
                    Text(body)
                        .style(.body)
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                        .padding(.top, DS.Spacing.s4)
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(DS.Colors.Line.hairline, lineWidth: 1)
        )
    }

    // MARK: - 1. Top Bar

    private func topBar(_ vm: AcademyTodayViewModel) -> some View {
        HStack(spacing: DS.Spacing.s12) {
            Avatar(size: 36, initials: vm.playerInitials)

            Spacer()

            Image("mf-logo-white")
                .resizable()
                .scaledToFit()
                .frame(height: 20)
                .accessibilityLabel("MF Elite")

            Spacer()

            HStack(spacing: DS.Spacing.s8) {
                if auth.isCoach {
                    coachBadge
                } else if !subscription.hasFullAccess {
                    upgradeButton
                }

                NavigationLink(value: StreakRoute()) {
                    HStack(spacing: DS.Spacing.s4 + 2) {
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(DS.Colors.Ink.primary)
                        Text("\(vm.streak)")
                            .font(DS.Typography.num(size: 14))
                            .foregroundStyle(DS.Colors.Ink.primary)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, DS.Spacing.s12)
                    .background(DS.Colors.Bg.raised)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.pill))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.pill)
                            .stroke(DS.Colors.Line.hairline, lineWidth: 1)
                    )
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s12)
    }

    /// Subtle badge confirming the user is in coach mode (full access).
    private var coachBadge: some View {
        Text("COACH")
            .font(.system(size: 11, weight: .bold))
            .tracking(1.2)
            .foregroundStyle(DS.Colors.Ink.primary)
            .padding(.vertical, 6)
            .padding(.horizontal, DS.Spacing.s12)
            .background(DS.Colors.Bg.raised)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.pill))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.pill)
                    .stroke(DS.Colors.Line.hairline, lineWidth: 1)
            )
            .accessibilityLabel("Coach mode")
    }

    /// Always-visible upgrade entry point for free (Trialist) players.
    private var upgradeButton: some View {
        Button {
            subscription.presentPaywall()
        } label: {
            HStack(spacing: DS.Spacing.s4 + 1) {
                Text("UPGRADE")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.2)
                Image(systemName: "arrow.up.circle")
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundStyle(DS.Colors.Ground.primary)
            .padding(.vertical, 6)
            .padding(.horizontal, DS.Spacing.s12 + 2)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.pill))
            .pillLightElevation()
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel("Upgrade to Elite")
    }

    // MARK: - 2. Salutation

    private func salutation(_ vm: AcademyTodayViewModel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: vm.formattedDate)
            Text("\(vm.greeting)\n\(vm.playerName)")
                .style(.hero)
                .foregroundStyle(DS.Colors.Ink.primary)
                .lineSpacing(-6)
                .padding(.top, DS.Spacing.s12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s24)
    }

    // MARK: - 3. Today's Standard

    private func dailyStandard(_ vm: AcademyTodayViewModel) -> some View {
        VStack(spacing: 0) {
            SlashRule()

            Eyebrow(text: "Today's Standard")
                .padding(.top, DS.Spacing.s16)

            Text("\u{201C}\(vm.dailyQuote)\u{201D}")
                .font(.system(size: 27, weight: .medium).italic())
                .foregroundStyle(DS.Colors.Ink.primary)
                .lineSpacing(7)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, DS.Spacing.s16)

            SlashRule()
                .padding(.top, DS.Spacing.s16)
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s24 + 4)
    }

    // MARK: - 4. Daily Goals + Standing

    private func goalsCard(_ vm: AcademyTodayViewModel) -> some View {
        let rank = vm.currentRank
        return Card(padding: DS.Spacing.s20) {
            HStack(alignment: .top, spacing: DS.Spacing.s20) {
                PitchRing(
                    size: 90,
                    progress: Double(vm.dailyGoalsCompleted) / Double(max(1, vm.dailyGoalsTotal)),
                    strokeWidth: 7,
                    value: "\(vm.dailyGoalsCompleted)/\(vm.dailyGoalsTotal)",
                    label: "Goals"
                )

                VStack(alignment: .leading, spacing: DS.Spacing.s8) {
                    Eyebrow(text: "Rank \(rank.numeral)")
                    Text(rank.title)
                        .style(.title3)
                        .foregroundStyle(DS.Colors.Ink.primary)

                    HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.s4) {
                        Text(vm.xp.formatted())
                            .font(DS.Typography.num(size: 30))
                            .foregroundStyle(DS.Colors.Ink.primary)
                        Text("XP")
                            .style(.foot)
                            .foregroundStyle(DS.Colors.Ink.tertiary)
                    }

                    VStack(alignment: .leading, spacing: DS.Spacing.s8) {
                        ForEach(vm.goalStates) { goal in
                            goalRow(goal)
                        }
                    }
                    .padding(.top, DS.Spacing.s8 + 2)
                }
            }
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s24 + 4)
    }

    private func goalRow(_ goal: GoalState) -> some View {
        HStack(spacing: DS.Spacing.s8) {
            RoundedRectangle(cornerRadius: 4)
                .fill(goal.done ? Color.white : Color.clear)
                .frame(width: 18, height: 18)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(goal.done ? Color.clear : DS.Colors.Line.subtle, lineWidth: 1)
                )
                .overlay {
                    if goal.done {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(DS.Colors.Ground.primary)
                    }
                }

            Text(goal.label)
                .style(.foot)
                .foregroundStyle(goal.done ? DS.Colors.Ink.primary : DS.Colors.Ink.tertiary)
        }
    }

    // MARK: - 5. Continue Your Pathway

    @ViewBuilder
    private func continuePathway(_ vm: AcademyTodayViewModel) -> some View {
        if let focus = vm.currentFocus {
            VStack(alignment: .leading, spacing: 0) {
                Eyebrow(text: "Continue Your Pathway")
                    .padding(.horizontal, DS.Spacing.s20)

                pathwayCard(vm, focus: focus)
                    .padding(.horizontal, DS.Spacing.s20)
                    .padding(.top, DS.Spacing.s12)
            }
            .padding(.top, DS.Spacing.s24 + 4)
        }
    }

    private func pathwayCard(_ vm: AcademyTodayViewModel, focus: CurrentFocus) -> some View {
        let total = focus.level.drills.count
        let done = vm.masteredDrillCount(in: focus.level)
        return Card(padding: 0, raised: true) {
            VStack(alignment: .leading, spacing: 0) {
                PhotoPlaceholder(height: 140, label: focus.discipline.name)
                    .overlay(alignment: .topLeading) {
                        DisciplineMark(kind: focus.discipline.mark, size: 28)
                            .padding(DS.Spacing.s12)
                    }

                VStack(alignment: .leading, spacing: 0) {
                    Eyebrow(text: "\(focus.discipline.name) · \(focus.category.name)")
                    Eyebrow(text: "Level \(focus.level.number)")
                        .padding(.top, DS.Spacing.s4 + 2)
                    Text(focus.level.name)
                        .style(.display)
                        .foregroundStyle(DS.Colors.Ink.primary)
                        .padding(.top, DS.Spacing.s4 + 2)
                    Text("\(done)/\(total) drills")
                        .style(.micro)
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                        .padding(.top, DS.Spacing.s8)

                    NavigationLink(value: LevelRoute(
                        discipline: focus.discipline,
                        category: focus.category,
                        level: focus.level
                    )) {
                        resumeButtonLabel(started: done > 0)
                    }
                    .buttonStyle(PressableButtonStyle())
                    .padding(.top, DS.Spacing.s16)
                }
                .padding(DS.Spacing.s16)
            }
        }
    }

    /// Styled to match PrimaryButton (medium) but usable as a NavigationLink label.
    /// Reads "Start level" until the player has mastered at least one drill.
    private func resumeButtonLabel(started: Bool) -> some View {
        Text(started ? "Resume level" : "Start level")
            .font(.system(size: 17, weight: .bold))
            .tracking(0.1)
            .foregroundStyle(DS.Colors.Ground.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.pill))
            .pillLightElevation()
    }

    // MARK: - 6. Recommended For You

    private func recommendedSection(_ vm: AcademyTodayViewModel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Eyebrow(text: "Recommended For You")
                Spacer()
                Eyebrow(text: "From \(vm.totalDrills) Drills", color: DS.Colors.Ink.quaternary)
            }
            .padding(.horizontal, DS.Spacing.s20)

            VStack(spacing: 0) {
                let recs = vm.recommendations
                ForEach(Array(recs.enumerated()), id: \.element.id) { index, rec in
                    let locked = subscription.isLevelNumberLocked(rec.level.number)
                    if locked {
                        Button {
                            subscription.presentPaywall()
                        } label: {
                            recommendationRow(rec, isLocked: true, isLast: index == recs.count - 1)
                        }
                        .buttonStyle(PressableButtonStyle())
                    } else {
                        NavigationLink(value: DrillRoute(
                            discipline: rec.discipline,
                            category: rec.category,
                            level: rec.level,
                            drill: rec.drill
                        )) {
                            recommendationRow(rec, isLast: index == recs.count - 1)
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                }
            }
            .padding(.top, DS.Spacing.s12)
        }
        .padding(.top, DS.Spacing.s24 + 4)
    }

    private func recommendationRow(_ rec: Recommendation, isLocked: Bool = false, isLast: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: DS.Spacing.s16) {
                DisciplineMark(kind: rec.discipline.mark, size: 22)
                    .frame(width: 44, height: 44)
                    .background(DS.Colors.Bg.card)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(DS.Colors.Line.hairline, lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: DS.Spacing.s4) {
                    Text(rec.drill.title)
                        .style(.title3)
                        .foregroundStyle(DS.Colors.Ink.primary)
                    Text("\(rec.discipline.name) · \(rec.reason)")
                        .style(.micro)
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                }

                Spacer(minLength: DS.Spacing.s8)

                Image(systemName: isLocked ? "lock.fill" : "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DS.Colors.Ink.quaternary)
            }
            .opacity(isLocked ? 0.6 : 1)
            .padding(.vertical, DS.Spacing.s12 + 2)

            if !isLast {
                Hairline()
            }
        }
        .padding(.horizontal, DS.Spacing.s20)
        .contentShape(Rectangle())
    }
}

#Preview {
    AcademyTodayView()
        .preferredColorScheme(.dark)
        .environment(SubscriptionService.shared)
        .modelContainer(for: [
            Discipline.self, Category.self, MasteryLevel.self,
            Drill.self, DrillProgress.self, PlayerState.self
        ])
}
