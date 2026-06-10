//
//  RoutinesView.swift
//  MFElite
//
//  Curated, prebuilt training sessions — sequences of drills the player can follow.
//

import SwiftUI
import SwiftData

/// Navigation route to the routines list.
struct RoutinesRoute: Hashable {}

struct RoutinesView: View {
    @Query(sort: \Discipline.sortIndex) private var disciplines: [Discipline]
    @Query private var sessionLog: [SessionLogEntry]
    @Query(sort: \CustomWorkout.updatedAt, order: .reverse) private var workouts: [CustomWorkout]
    @Environment(SubscriptionService.self) private var subscription
    @Environment(\.modelContext) private var context

    @State private var expanded: Set<String> = []
    @State private var indexCache = DrillIndexCache()
    @State private var activeSession: TrainingQueue?
    @State private var showBuilder = false
    @State private var editingWorkout: CustomWorkout?
    @State private var workoutToDelete: CustomWorkout?
    @State private var markCompleteTarget: MarkCompleteTarget?
    @State private var lastLogResult: QuickLog.Result?
    @State private var favorites = FavoritesStore.shared

    /// A routine/workout queued for one-tap, timer-free logging.
    private struct MarkCompleteTarget: Identifiable {
        let id = UUID()
        let name: String
        let source: SessionSource
        let contexts: [DrillContext]
    }

    /// Free players may keep a single custom workout; Elite is unlimited.
    private var canCreateWorkout: Bool {
        subscription.hasFullAccess || workouts.count < 1
    }

    /// drillID → resolved navigation context. Memoized via the shared helper.
    private var drillIndex: [String: ResolvedDrill] {
        buildDrillIndex(disciplines, cache: indexCache)
    }

    /// Drill IDs logged at least once today, for the "done" checkmarks.
    private var loggedTodayIDs: Set<String> {
        let cal = Calendar.current
        return Set(
            sessionLog
                .filter { cal.isDateInToday($0.completedAt) }
                .map(\.drillID)
        )
    }

    var body: some View {
        let index = drillIndex
        let doneToday = loggedTodayIDs
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                myWorkoutsSection(index, doneToday: doneToday)
                routineCards(index, doneToday: doneToday)
            }
            .padding(.bottom, 120)
        }
        .background(DS.Colors.Bg.base)
        .scrollIndicators(.hidden)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $activeSession) { queue in
            SessionPlayerView(queue: queue)
        }
        .sheet(isPresented: $showBuilder) {
            WorkoutBuilderView()
        }
        .sheet(item: $editingWorkout) { workout in
            WorkoutBuilderView(editing: workout)
        }
        .alert("Delete workout?", isPresented: deleteAlertBinding, presenting: workoutToDelete) { workout in
            Button("Delete", role: .destructive) { delete(workout) }
            Button("Cancel", role: .cancel) {}
        } message: { workout in
            Text("“\(workout.title)” will be removed permanently.")
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
                loggedToast(result)
                    .padding(.bottom, 110)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private var markCompleteBinding: Binding<Bool> {
        Binding(
            get: { markCompleteTarget != nil },
            set: { if !$0 { markCompleteTarget = nil } }
        )
    }

    /// Log every drill in a routine/workout at once, no timer.
    private func markComplete(_ target: MarkCompleteTarget) {
        let result = QuickLog.logDrills(
            target.contexts,
            source: target.source,
            sourceName: target.name,
            context: context
        )
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(DS.Motion.standardSpring) { lastLogResult = result }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            withAnimation(DS.Motion.standardSpring) { lastLogResult = nil }
        }
    }

    private func loggedToast(_ result: QuickLog.Result) -> some View {
        HStack(spacing: DS.Spacing.s12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(DS.Colors.Ground.primary)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(result.drillsLogged) drills logged")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(DS.Colors.Ground.primary)
                Text("+\(result.xpEarned) XP · \(result.newStreak)-day streak")
                    .style(.micro)
                    .foregroundStyle(Color.black.opacity(0.6))
            }
        }
        .padding(.vertical, DS.Spacing.s12)
        .padding(.horizontal, DS.Spacing.s20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.pill))
        .pillLightElevation()
        .padding(.horizontal, DS.Spacing.s20)
    }

    /// Resolve a routine/workout into full drill contexts for one-tap logging.
    private func contexts(from resolved: [ResolvedDrill]) -> [DrillContext] {
        resolved.map {
            DrillContext(drill: $0.drill, level: $0.level, category: $0.category, discipline: $0.discipline)
        }
    }

    private var deleteAlertBinding: Binding<Bool> {
        Binding(
            get: { workoutToDelete != nil },
            set: { if !$0 { workoutToDelete = nil } }
        )
    }

    // MARK: - My Workouts

    private func myWorkoutsSection(_ index: [String: ResolvedDrill], doneToday: Set<String>) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s12) {
            HStack {
                Eyebrow(text: "My Workouts")
                Spacer()
                if !workouts.isEmpty {
                    Button { startCreate() } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(DS.Colors.Ink.primary)
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }

            if workouts.isEmpty {
                emptyWorkoutsCard
            } else {
                ForEach(workouts) { workout in
                    let resolved = workout.drillIDs.compactMap { index[$0] }
                    WorkoutCard(
                        title: workout.title,
                        resolved: resolved,
                        loggedToday: doneToday,
                        isExpanded: expanded.contains(workout.id.uuidString),
                        isFavorited: favorites.isFavoriteWorkout(workout.id),
                        onToggle: { toggle(workout.id.uuidString) },
                        onStart: { startIndex in start(name: workout.title, resolved: resolved, from: startIndex) },
                        onMarkComplete: {
                            markCompleteTarget = MarkCompleteTarget(
                                name: workout.title, source: .workout, contexts: contexts(from: resolved)
                            )
                        },
                        onToggleFavorite: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            favorites.toggleWorkout(workout.id)
                        },
                        onEdit: { editingWorkout = workout },
                        onDuplicate: { duplicate(workout) },
                        onDelete: { workoutToDelete = workout }
                    )
                }
            }
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s24)
    }

    private var emptyWorkoutsCard: some View {
        Card(raised: true) {
            VStack(alignment: .leading, spacing: DS.Spacing.s12) {
                Text("Build your own session from any drill in the academy.")
                    .style(.foot)
                    .foregroundStyle(DS.Colors.Ink.secondary)
                Button { startCreate() } label: {
                    Text("Create workout")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(DS.Colors.Ground.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.pill))
                        .pillLightElevation()
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
    }

    private func startCreate() {
        guard canCreateWorkout else {
            subscription.presentPaywall()
            return
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        showBuilder = true
    }

    private func duplicate(_ workout: CustomWorkout) {
        guard canCreateWorkout else {
            subscription.presentPaywall()
            return
        }
        let copy = CustomWorkout(title: "\(workout.title) Copy", drillIDs: workout.drillIDs)
        context.insert(copy)
        try? context.save()
    }

    private func delete(_ workout: CustomWorkout) {
        favorites.removeWorkout(workout.id)
        context.delete(workout)
        try? context.save()
        workoutToDelete = nil
    }

    /// Build a TrainingQueue from a custom workout and present the player.
    private func start(name: String, resolved: [ResolvedDrill], from startIndex: Int) {
        let slice = Array(resolved.dropFirst(startIndex))
        guard !slice.isEmpty else { return }
        let items = slice.map {
            DrillContext(drill: $0.drill, level: $0.level, category: $0.category, discipline: $0.discipline)
        }
        activeSession = TrainingQueue(items: items, source: .workout, sourceName: name)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s8) {
            Eyebrow(text: "Routines")
            Text("Training Sessions")
                .style(.title1)
                .foregroundStyle(DS.Colors.Ink.primary)
            Text("Curated drill sequences to guide your training.")
                .style(.body)
                .foregroundStyle(DS.Colors.Ink.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s20)
    }

    // MARK: - Cards

    private func routineCards(_ index: [String: ResolvedDrill], doneToday: Set<String>) -> some View {
        VStack(spacing: DS.Spacing.s16) {
            ForEach(RoutineCatalog.all) { routine in
                let resolved = routine.drillIDs.compactMap { index[$0] }
                RoutineCard(
                    routine: routine,
                    resolved: resolved,
                    loggedToday: doneToday,
                    isExpanded: expanded.contains(routine.id),
                    isFavorited: favorites.isFavoriteRoutine(routine.id),
                    onToggle: { toggle(routine.id) },
                    onStart: { startIndex in start(routine: routine, resolved: resolved, from: startIndex) },
                    onMarkComplete: {
                        markCompleteTarget = MarkCompleteTarget(
                            name: routine.title, source: .routine, contexts: contexts(from: resolved)
                        )
                    },
                    onToggleFavorite: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        favorites.toggleRoutine(routine.id)
                    }
                )
            }
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s20)
    }

    /// Build a TrainingQueue from a routine (optionally starting partway through)
    /// and present the session player.
    private func start(routine: RoutineSpec, resolved: [ResolvedDrill], from startIndex: Int) {
        let slice = Array(resolved.dropFirst(startIndex))
        guard !slice.isEmpty else { return }
        let items = slice.map {
            DrillContext(drill: $0.drill, level: $0.level, category: $0.category, discipline: $0.discipline)
        }
        activeSession = TrainingQueue(items: items, source: .routine, sourceName: routine.title)
    }

    private func toggle(_ id: String) {
        if expanded.contains(id) {
            expanded.remove(id)
        } else {
            expanded.insert(id)
        }
    }
}

#Preview {
    NavigationStack {
        RoutinesView()
    }
    .preferredColorScheme(.dark)
    .modelContainer(for: [
        Discipline.self, Category.self, MasteryLevel.self,
        Drill.self, DrillProgress.self, PlayerState.self
    ])
}

