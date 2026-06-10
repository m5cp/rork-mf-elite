//
//  AcademyTodayView.swift
//  MFElite
//
//  Tab 1 — the daily dashboard: greeting, standard, goals, pathway, recommendations.
//

import SwiftUI
import SwiftData

/// Reference-type memo so the drillID→context map is built once and reused
/// across body evaluations, rebuilding only when the curriculum graph changes.
private final class TodayWorkoutIndexCache {
    var signature: Int = -1
    var index: [String: DrillContext] = [:]
}

struct AcademyTodayView: View {
    @Query(sort: \Discipline.sortIndex) private var disciplines: [Discipline]
    @Query private var players: [PlayerState]
    @Query private var progress: [DrillProgress]
    @Query private var sessions: [SessionLogEntry]
    @Query(sort: \CustomWorkout.updatedAt, order: .reverse) private var workouts: [CustomWorkout]
    @Environment(SubscriptionService.self) private var subscription
    @State private var profile = PlayerProfileStore.shared
    @State private var favorites = FavoritesStore.shared
    @State private var workoutIndexCache = TodayWorkoutIndexCache()
    @State private var activeSession: TrainingQueue?
    @State private var showBuilder = false

    /// Most recent workouts shown inline on the home strip before "See all".
    private let homeWorkoutLimit = 6

    /// Free players may keep a single custom workout; Elite is unlimited.
    private var canCreateWorkout: Bool {
        subscription.hasFullAccess || workouts.count < 1
    }

    /// drillID → resolved context, rebuilt only when the curriculum graph changes.
    private var drillIndex: [String: DrillContext] {
        let signature = disciplines.map { ObjectIdentifier($0) }.hashValue
        if workoutIndexCache.signature != signature {
            var map: [String: DrillContext] = [:]
            for discipline in disciplines {
                for category in discipline.categories {
                    for level in category.levels {
                        for drill in level.drills {
                            map[drill.id] = DrillContext(
                                drill: drill, level: level, category: category, discipline: discipline
                            )
                        }
                    }
                }
            }
            workoutIndexCache.index = map
            workoutIndexCache.signature = signature
        }
        return workoutIndexCache.index
    }

    private var viewModel: AcademyTodayViewModel {
        AcademyTodayViewModel(
            disciplines: disciplines,
            xp: players.first?.xp ?? 0,
            streak: players.first?.streak ?? 0,
            progress: progress,
            sessions: sessions,
            positionCode: profile.positionCode
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
                    dailyStandard(vm)
                    goalsCard(vm)
                    todaysFocusCard(vm)
                    myWorkoutsSection
                    favoritesCard
                    continuePathway(vm)
                    recommendedSection(vm)
                }
                .padding(.bottom, 120)
            }
            .background(DS.Colors.Bg.base)
            .scrollIndicators(.hidden)
            .navigationBarHidden(true)
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
            .navigationDestination(for: RoutinesRoute.self) { _ in
                RoutinesView()
            }
            .navigationDestination(for: DrillLibraryRoute.self) { _ in
                DrillLibraryView()
            }
            .navigationDestination(for: MyWorkoutsRoute.self) { _ in
                MyWorkoutsView()
            }
            .navigationDestination(for: FavoritesRoute.self) { _ in
                FavoritesView()
            }
        }
        .fullScreenCover(item: $activeSession) { queue in
            SessionPlayerView(queue: queue)
        }
        .sheet(isPresented: $showBuilder) {
            WorkoutBuilderView()
        }
    }

    // MARK: - My Workouts strip

    private var myWorkoutsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s12) {
            HStack {
                Eyebrow(text: "My Workouts")
                Spacer()
                if !workouts.isEmpty {
                    NavigationLink(value: MyWorkoutsRoute()) {
                        HStack(spacing: 3) {
                            Text("See all")
                                .style(.micro)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
            .padding(.horizontal, DS.Spacing.s20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.s12) {
                    ForEach(workouts.prefix(homeWorkoutLimit)) { workout in
                        workoutChip(workout)
                    }
                    buildChip
                }
                .padding(.horizontal, DS.Spacing.s20)
            }
        }
        .padding(.top, DS.Spacing.s24 + 4)
    }

    private func workoutChip(_ workout: CustomWorkout) -> some View {
        let resolved = workout.drillIDs.compactMap { drillIndex[$0] }
        return Button {
            guard !resolved.isEmpty else { return }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            activeSession = TrainingQueue(items: resolved, source: .workout, sourceName: workout.title)
        } label: {
            VStack(alignment: .leading, spacing: DS.Spacing.s8) {
                Image(systemName: "figure.run")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(DS.Colors.Ink.primary)
                Spacer(minLength: 0)
                Text(workout.title)
                    .style(.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(DS.Colors.Ink.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(resolved.count) drills · \(estimatedSessionMinutes(forDrills: resolved.map(\.drill))) min")
                    .style(.micro)
                    .foregroundStyle(DS.Colors.Ink.tertiary)
            }
            .padding(DS.Spacing.s16)
            .frame(width: 168, height: 132, alignment: .leading)
            .background(DS.Colors.Bg.elevated)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .stroke(DS.Colors.Line.hairline, lineWidth: 1)
            )
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityHint("Start workout")
    }

    private var buildChip: some View {
        Button {
            if canCreateWorkout {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                showBuilder = true
            } else {
                subscription.presentPaywall()
            }
        } label: {
            VStack(spacing: DS.Spacing.s8) {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .bold))
                Text("Build a workout")
                    .style(.micro)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(DS.Colors.Ink.secondary)
            .frame(width: 132, height: 132)
            .background(DS.Colors.Bg.raised)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                    .foregroundStyle(DS.Colors.Line.subtle)
            )
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - Favorites hero card

    private var favoritesCard: some View {
        NavigationLink(value: FavoritesRoute()) {
            HStack(spacing: DS.Spacing.s16) {
                Image(systemName: favorites.isEmpty ? "heart" : "heart.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(DS.Colors.Ink.primary)
                    .frame(width: 52, height: 52)
                    .background(DS.Colors.Bg.raised)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                    .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(DS.Colors.Line.hairline, lineWidth: 1))

                VStack(alignment: .leading, spacing: DS.Spacing.s4) {
                    Text("Favorites")
                        .style(.title3)
                        .foregroundStyle(DS.Colors.Ink.primary)
                    Text(favorites.isEmpty
                         ? "Heart any drill, routine or workout to save it"
                         : "\(favorites.totalCount) saved · drills, routines & workouts")
                        .style(.micro)
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DS.Colors.Ink.quaternary)
            }
            .padding(DS.Spacing.s16)
            .background(DS.Colors.Bg.elevated)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.lg).stroke(DS.Colors.Line.hairline, lineWidth: 1))
        }
        .buttonStyle(PressableButtonStyle())
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s24 + 4)
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
                if !subscription.hasFullAccess {
                    upgradeButton
                }

                NavigationLink(value: StreakRoute()) {
                    HStack(spacing: DS.Spacing.s4 + 2) {
                        Image(systemName: "flame.fill")
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
                            if let route = goal.drillRoute {
                                NavigationLink(value: route) {
                                    goalRow(goal)
                                }
                                .buttonStyle(PressableButtonStyle())
                            } else if let levelRoute = goal.levelRoute {
                                NavigationLink(value: levelRoute) {
                                    goalRow(goal)
                                }
                                .buttonStyle(PressableButtonStyle())
                            } else {
                                goalRow(goal)
                            }
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

            Spacer(minLength: DS.Spacing.s4)

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DS.Colors.Ink.quaternary)
        }
        .contentShape(Rectangle())
    }

    // MARK: - 4b. Today's Focus (adaptive)

    @ViewBuilder
    private func todaysFocusCard(_ vm: AcademyTodayViewModel) -> some View {
        if let focus = vm.todaysFocus {
            let locked = subscription.isLevelNumberLocked(focus.level.number)
            VStack(alignment: .leading, spacing: 0) {
                Eyebrow(text: "Today's Focus")
                    .padding(.horizontal, DS.Spacing.s20)

                Group {
                    if locked {
                        Button { subscription.presentPaywall() } label: {
                            focusCardBody(focus, locked: true)
                        }
                        .buttonStyle(PressableButtonStyle())
                    } else {
                        NavigationLink(value: DrillRoute(
                            discipline: focus.discipline,
                            category: focus.category,
                            level: focus.level,
                            drill: focus.drill
                        )) {
                            focusCardBody(focus, locked: false)
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                }
                .padding(.horizontal, DS.Spacing.s20)
                .padding(.top, DS.Spacing.s12)
            }
            .padding(.top, DS.Spacing.s24 + 4)
        }
    }

    private func focusCardBody(_ focus: PlanFocus, locked: Bool) -> some View {
        Card(padding: DS.Spacing.s20, raised: true) {
            VStack(alignment: .leading, spacing: DS.Spacing.s12) {
                HStack(spacing: DS.Spacing.s12) {
                    DisciplineMark(kind: focus.discipline.mark, size: 22)
                        .frame(width: 44, height: 44)
                        .background(DS.Colors.Bg.card)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(DS.Colors.Line.hairline, lineWidth: 1)
                        )
                    VStack(alignment: .leading, spacing: DS.Spacing.s4) {
                        Eyebrow(text: focus.headline)
                        Text(focus.drill.title)
                            .style(.title3)
                            .foregroundStyle(DS.Colors.Ink.primary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: DS.Spacing.s4)
                    Image(systemName: locked ? "lock.fill" : "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DS.Colors.Ink.quaternary)
                }

                Text(focus.reason)
                    .style(.foot)
                    .foregroundStyle(DS.Colors.Ink.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .opacity(locked ? 0.7 : 1)
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
                DisciplineHero(height: 140, disciplineName: focus.discipline.name, label: focus.discipline.name)
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
