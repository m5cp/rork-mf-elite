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
    @State private var expanded: Set<String> = []
    @State private var activeSession: TrainingQueue?
    @State private var markCompleteTarget: MarkCompleteTarget?
    @State private var sharingWorkout: ShareableWorkout?
    @State private var lastLogResult: QuickLog.Result?

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

    private var favDrills: [ResolvedDrill] {
        let index = drillIndex
        return favorites.drillIDs.compactMap { index[$0] }
            .sorted { $0.drill.title.localizedCaseInsensitiveCompare($1.drill.title) == .orderedAscending }
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
                    if !favDrills.isEmpty {
                        drillsSection
                    }
                }
            }
            .padding(.bottom, 120)
        }
        .background(DS.Colors.Bg.base)
        .scrollIndicators(.hidden)
        .navigationTitle("Favorites")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $sharingWorkout) { workout in WorkoutShareView(workout: workout) }
        .fullScreenCover(item: $activeSession) { queue in
            SessionPlayerView(queue: queue)
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
                    isExpanded: expanded.contains(routine.id),
                    isFavorited: true,
                    onToggle: { toggle(routine.id) },
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
                    isExpanded: expanded.contains(workout.id.uuidString),
                    isFavorited: true,
                    onToggle: { toggle(workout.id.uuidString) },
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
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: "Drills")
                .padding(.horizontal, DS.Spacing.s20)
                .padding(.bottom, DS.Spacing.s4)
            ForEach(favDrills) { item in
                FavoriteDrillRow(
                    item: item,
                    isLast: item.id == favDrills.last?.id,
                    onUnfavorite: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(DS.Motion.standardSpring) { favorites.toggleDrill(item.drill.id) }
                    }
                )
            }
        }
        .padding(.top, DS.Spacing.s32)
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

    private func toggle(_ id: String) {
        if expanded.contains(id) { expanded.remove(id) } else { expanded.insert(id) }
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
