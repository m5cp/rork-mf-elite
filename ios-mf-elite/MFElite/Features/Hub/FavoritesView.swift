//
//  FavoritesView.swift
//  MFElite
//
//  Everything the player has hearted — drills, routines and custom workouts —
//  grouped by type. Drills open their detail; routines and workouts can be
//  started or marked complete right here. Reached from the Favorites hero card
//  on the home page and the academy hub.
//

import SwiftUI
import SwiftData

/// Navigation route to the Favorites collection.
struct FavoritesRoute: Hashable {}

struct FavoritesView: View {
    @Query(sort: \Discipline.sortIndex) private var disciplines: [Discipline]
    @Query private var sessionLog: [SessionLogEntry]
    @Query(sort: \CustomWorkout.updatedAt, order: .reverse) private var workouts: [CustomWorkout]
    @Environment(\.modelContext) private var context

    @State private var indexCache = DrillIndexCache()
    @State private var favorites = FavoritesStore.shared
    @State private var activeSession: TrainingQueue?
    @State private var markCompleteTarget: MarkCompleteTarget?
    @State private var sharingWorkout: ShareableWorkout?
    @State private var lastLogResult: QuickLog.Result?
    @State private var streakMilestone: StreakMilestone?
    @State private var drillSearch = ""
    @State private var drillDisciplineID: String?

    private struct MarkCompleteTarget: Identifiable {
        let id = UUID()
        let name: String
        let source: SessionSource
        let contexts: [DrillContext]
    }

    private var drillIndex: [String: ResolvedDrill] {
        buildDrillIndex(disciplines, cache: indexCache)
    }

    private var loggedTodayIDs: Set<String> {
        let cal = Calendar.current
        return Set(sessionLog.filter { cal.isDateInToday($0.completedAt) }.map(\.drillID))
    }

    private var favRoutines: [RoutineSpec] {
        RoutineCatalog.all.filter { favorites.isFavoriteRoutine($0.id) }
    }

    private var favWorkouts: [CustomWorkout] {
        workouts.filter { favorites.isFavoriteWorkout($0.id) }
    }

    /// Every favourited drill, resolved. Can reach the full 226-drill
    /// curriculum, since any drill can be hearted.
    private var allFavDrills: [ResolvedDrill] {
        let index = drillIndex
        return favorites.drillIDs.compactMap { index[$0] }
    }

    /// Disciplines that actually appear in the player's favourites, so the
    /// filter row only offers chips that will return something.
    private var favDisciplines: [Discipline] {
        let present = Set(allFavDrills.map { $0.discipline.id })
        return disciplines.filter { present.contains($0.id) }
    }

    /// Favourited drills after the search and discipline filter, ordered by
    /// curriculum position rather than alphabetically — a flat A-Z list of up
    /// to 226 drills ignored the structure the rest of the app is organised by.
    private var favDrills: [ResolvedDrill] {
        let query = drillSearch.trimmingCharacters(in: .whitespaces).lowercased()
        var result = allFavDrills

        if let drillDisciplineID {
            result = result.filter { $0.discipline.id == drillDisciplineID }
        }
        if !query.isEmpty {
            result = result.filter {
                $0.drill.title.lowercased().contains(query)
                    || $0.drill.focus.lowercased().contains(query)
                    || $0.category.name.lowercased().contains(query)
            }
        }
        return result.sorted {
            ($0.discipline.sortIndex, $0.category.sortIndex, $0.level.number, $0.drill.sortIndex)
                < ($1.discipline.sortIndex, $1.category.sortIndex, $1.level.number, $1.drill.sortIndex)
        }
    }

    var body: some View {
        let index = drillIndex
        let doneToday = loggedTodayIDs
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                if favorites.isEmpty {
                    emptyState
                } else {
                    if !favRoutines.isEmpty {
                        routinesSection(index, doneToday: doneToday)
                    }
                    if !favWorkouts.isEmpty {
                        workoutsSection(index, doneToday: doneToday)
                    }
                    if !allFavDrills.isEmpty {
                        drillsSection
                    }
                }
            }
            .padding(.bottom, DS.tabBarClearance + DS.Spacing.s24)
        }
        .background(DS.Colors.Bg.base)
        .scrollIndicators(.hidden)
        .searchable(text: $drillSearch, prompt: "Search your saved drills")
        .navigationTitle("Favorites")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $sharingWorkout) { workout in WorkoutShareView(workout: workout) }
        .fullScreenCover(item: $activeSession) { queue in
            SessionPlayerView(queue: queue)
        }
        .fullScreenCover(item: $streakMilestone) { milestone in
            StreakMilestoneView(days: milestone.days, onClose: {})
        }
        .confirmationDialog(
            "Mark complete?",
            isPresented: markCompleteBinding,
            presenting: markCompleteTarget
        ) { target in
            Button("Log \(target.contexts.count) drills as done") { markComplete(target) }
            Button("Cancel", role: .cancel) {}
        } message: { target in
            Text("Logs every drill in “\(target.name)” without the timer — XP, streak and rings all count.")
        }
        .overlay(alignment: .bottom) {
            if let result = lastLogResult {
                QuickLogToast(result: result)
                    .padding(.bottom, 32)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s8) {
            Eyebrow(text: "Favorites")
            Text("Your Saved Work")
                .style(.title1)
                .foregroundStyle(DS.Colors.Ink.primary)
            Text("Every drill, routine and workout you've hearted, in one place.")
                .style(.body)
                .foregroundStyle(DS.Colors.Ink.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s20)
    }

    // MARK: - Sections

    private func routinesSection(_ index: [String: ResolvedDrill], doneToday: Set<String>) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s16) {
            Eyebrow(text: "Routines")
                .padding(.horizontal, DS.Spacing.s20)
            ForEach(favRoutines) { routine in
                let resolved = routine.drillIDs.compactMap { index[$0] }
                RoutineCard(
                    routine: routine,
                    resolved: resolved,
                    loggedToday: doneToday,
                    isFavorited: true,
                    onStart: { startIndex in start(name: routine.title, source: .routine, resolved: resolved, from: startIndex) },
                    onMarkComplete: {
                        markCompleteTarget = MarkCompleteTarget(name: routine.title, source: .routine, contexts: resolved.map(\.context))
                    },
                    onToggleFavorite: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(DS.Motion.standardSpring) { favorites.toggleRoutine(routine.id) }
                    }
                )
                .padding(.horizontal, DS.Spacing.s20)
            }
        }
        .padding(.top, DS.Spacing.s32)
    }

    private func workoutsSection(_ index: [String: ResolvedDrill], doneToday: Set<String>) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s16) {
            Eyebrow(text: "Workouts")
                .padding(.horizontal, DS.Spacing.s20)
            ForEach(favWorkouts) { workout in
                let resolved = workout.drillIDs.compactMap { index[$0] }
                WorkoutCard(
                    title: workout.title,
                    resolved: resolved,
                    loggedToday: doneToday,
                    isFavorited: true,
                    onStart: { startIndex in start(name: workout.title, source: .workout, resolved: resolved, from: startIndex) },
                    onMarkComplete: {
                        markCompleteTarget = MarkCompleteTarget(name: workout.title, source: .workout, contexts: resolved.map(\.context))
                    },
                    onToggleFavorite: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(DS.Motion.standardSpring) { favorites.toggleWorkout(workout.id) }
                    },
                    onEdit: {},
                    onDuplicate: {},
                    onDelete: {
                        withAnimation(DS.Motion.standardSpring) { favorites.toggleWorkout(workout.id) }
                    },
                    onShare: { shareWorkout(workout, resolved: resolved) }
                )
                .padding(.horizontal, DS.Spacing.s20)
            }
        }
        .padding(.top, DS.Spacing.s32)
    }

    private var drillsSection: some View {
        let shown = favDrills
        return LazyVStack(alignment: .leading, spacing: 0) {
            HStack {
                Eyebrow(text: "Drills")
                Spacer(minLength: DS.Spacing.s8)
                Text("\(shown.count) of \(allFavDrills.count)")
                    .style(.micro)
                    .foregroundStyle(DS.Colors.Ink.quaternary)
            }
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.bottom, DS.Spacing.s8)

            // Only worth a filter row once the list is long enough to scroll.
            if favDisciplines.count > 1, allFavDrills.count > 6 {
                disciplineFilterRow
                    .padding(.bottom, DS.Spacing.s8)
            }

            if shown.isEmpty {
                Text("No saved drills match. Try clearing the filter or the search.")
                    .style(.body)
                    .foregroundStyle(DS.Colors.Ink.quaternary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, DS.Spacing.s20)
                    .padding(.top, DS.Spacing.s24)
            }

            ForEach(shown) { item in
                FavoriteDrillRow(
                    item: item,
                    isLast: item.id == shown.last?.id,
                    onUnfavorite: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(DS.Motion.standardSpring) { favorites.toggleDrill(item.drill.id) }
                    }
                )
            }
        }
        .padding(.top, DS.Spacing.s32)
    }

    private var disciplineFilterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.s8) {
                filterChip(label: "All", selected: drillDisciplineID == nil) {
                    drillDisciplineID = nil
                }
                ForEach(favDisciplines) { discipline in
                    filterChip(
                        label: discipline.name,
                        selected: drillDisciplineID == discipline.id
                    ) {
                        drillDisciplineID = (drillDisciplineID == discipline.id) ? nil : discipline.id
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.s20)
        }
    }

    private func filterChip(
        label: String,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(DS.Motion.standardSpring) { action() }
        } label: {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(selected ? DS.Colors.Ground.primary : DS.Colors.Ink.secondary)
                .padding(.vertical, 7)
                .padding(.horizontal, 14)
                .background(selected ? Color.white : DS.Colors.Bg.raised)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(DS.Colors.Line.hairline, lineWidth: 1))
                .contentShape(Capsule())
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.s16) {
            Image(systemName: "heart")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(DS.Colors.Ink.quaternary)
            Text("No favorites yet")
                .style(.title3)
                .foregroundStyle(DS.Colors.Ink.primary)
            Text("Tap the heart on any drill, routine or workout to save it here for quick access.")
                .style(.body)
                .foregroundStyle(DS.Colors.Ink.tertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, DS.Spacing.s32)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    // MARK: - Actions

    private var markCompleteBinding: Binding<Bool> {
        Binding(get: { markCompleteTarget != nil }, set: { if !$0 { markCompleteTarget = nil } })
    }

    private func start(name: String, source: SessionSource, resolved: [ResolvedDrill], from startIndex: Int) {
        let slice = Array(resolved.dropFirst(startIndex))
        guard !slice.isEmpty else { return }
        activeSession = TrainingQueue(items: slice.map(\.context), source: source, sourceName: name)
    }

    private func shareWorkout(_ workout: CustomWorkout, resolved: [ResolvedDrill]) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        sharingWorkout = ShareableWorkout(
            id: workout.id,
            title: workout.title,
            drillIDs: workout.drillIDs,
            drillCount: resolved.count,
            minutes: estimatedMinutes(resolved)
        )
    }

    private func markComplete(_ target: MarkCompleteTarget) {
        let result = QuickLog.logDrills(
            target.contexts, source: target.source, sourceName: target.name, context: context
        )
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(DS.Motion.standardSpring) { lastLogResult = result }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            withAnimation(DS.Motion.standardSpring) { lastLogResult = nil }
        }
        celebrateStreakMilestoneIfCrossed(result.newStreak)
    }

    /// Presents the once-only streak milestone celebration after the logged toast.
    private func celebrateStreakMilestoneIfCrossed(_ streak: Int) {
        guard StreakMilestones.pending(for: streak) else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if let days = StreakMilestones.claim(for: streak) {
                streakMilestone = StreakMilestone(days: days)
            }
        }
    }
}

// MARK: - Favorite drill row

private struct FavoriteDrillRow: View {
    let item: ResolvedDrill
    let isLast: Bool
    let onUnfavorite: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: DS.Spacing.s16) {
                NavigationLink(value: DrillRoute(
                    discipline: item.discipline,
                    category: item.category,
                    level: item.level,
                    drill: item.drill
                )) {
                    HStack(spacing: DS.Spacing.s12) {
                        DisciplineMark(kind: item.discipline.mark, size: 20)
                            .frame(width: 40, height: 40)
                            .background(DS.Colors.Bg.card)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(DS.Colors.Line.hairline, lineWidth: 1))

                        VStack(alignment: .leading, spacing: DS.Spacing.s4) {
                            Text(item.drill.title)
                                .style(.title3)
                                .foregroundStyle(DS.Colors.Ink.primary)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("\(item.discipline.name) · \(item.category.name)")
                                .style(.micro)
                                .foregroundStyle(DS.Colors.Ink.tertiary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableButtonStyle())

                FavoriteHeartButton(isFavorited: true, action: onUnfavorite)
            }
            .padding(.vertical, DS.Spacing.s12)

            if !isLast { Hairline() }
        }
        .padding(.horizontal, DS.Spacing.s20)
    }
}
