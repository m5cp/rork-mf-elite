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

/// A curated routine spec: metadata plus the drill IDs it chains.
private struct Routine: Identifiable {
    let id: String
    let title: String
    let tag: String
    let blurb: String
    let drillIDs: [String]
}

/// A drill ID resolved to its full navigation context + title.
private struct ResolvedDrill: Identifiable {
    let drill: Drill
    let level: MasteryLevel
    let category: Category
    let discipline: Discipline
    var id: String { drill.id }
}

struct RoutinesView: View {
    @Query(sort: \Discipline.sortIndex) private var disciplines: [Discipline]
    @Query private var sessionLog: [SessionLogEntry]
    @Query(sort: \CustomWorkout.updatedAt, order: .reverse) private var workouts: [CustomWorkout]
    @Environment(SubscriptionService.self) private var subscription
    @Environment(\.modelContext) private var context

    @State private var expanded: Set<String> = []
    @State private var activeSession: TrainingQueue?
    @State private var showBuilder = false
    @State private var editingWorkout: CustomWorkout?
    @State private var workoutToDelete: CustomWorkout?

    /// Free players may keep a single custom workout; Elite is unlimited.
    private var canCreateWorkout: Bool {
        subscription.hasFullAccess || workouts.count < 1
    }

    private static let routines: [Routine] = [
        Routine(
            id: "daily-touch",
            title: "Daily Touch",
            tag: "QUICK SESSION",
            blurb: "A short ball mastery warm-up to start your day.",
            drillIDs: ["tech-a-1-1", "tech-a-1-2", "tech-a-1-3"]
        ),
        Routine(
            id: "full-technical",
            title: "Full Technical",
            tag: "TECHNICAL",
            blurb: "Touch, control, passing and finishing in one complete block.",
            drillIDs: ["tech-a-2-1", "tech-b-2-1", "tech-c-1-1", "tech-c-2-1", "tech-d-2-1", "tech-e-1-1"]
        ),
        Routine(
            id: "speed-agility",
            title: "Speed & Agility",
            tag: "PHYSICAL",
            blurb: "Explosive sprints and sharp change-of-direction work.",
            drillIDs: ["phys-a-1-1", "phys-a-1-2", "phys-b-1-1", "phys-b-1-2"]
        ),
        Routine(
            id: "game-day-prep",
            title: "Game Day Prep",
            tag: "MIXED",
            blurb: "Sharpen technique, fire the legs, and lock in the mind.",
            drillIDs: ["tech-a-1-1", "tech-c-1-2", "phys-a-1-1", "psy-a-1-1"]
        ),

        Routine(
            id: "first-touch-clinic",
            title: "First Touch Clinic",
            tag: "TECHNICAL",
            blurb: "Five drills focused purely on your first touch under pressure.",
            drillIDs: ["tech-b-1-1", "tech-b-1-2", "tech-b-1-3", "tech-b-1-4", "tech-b-2-1"]
        ),
        Routine(
            id: "finishing-school",
            title: "Finishing School",
            tag: "TECHNICAL",
            blurb: "Finishing drills — placement, power, and composure in front of goal.",
            drillIDs: ["tech-e-1-1", "tech-e-1-2", "tech-e-1-3", "tech-e-2-1", "tech-e-2-2"]
        ),
        Routine(
            id: "mental-edge",
            title: "Mental Edge",
            tag: "PSYCHOLOGICAL",
            blurb: "Build your mind. Self-talk, focus, and composure drills.",
            drillIDs: ["psy-a-1-1", "psy-b-1-1", "psy-d-1-1", "psy-e-1-1"]
        ),
        Routine(
            id: "dribbling-gauntlet",
            title: "Dribbling Gauntlet",
            tag: "TECHNICAL",
            blurb: "Take on defenders. Close control, feints, and 1v1 moves.",
            drillIDs: ["tech-d-1-1", "tech-d-1-2", "tech-d-1-3", "tech-d-2-1", "tech-d-2-2"]
        ),
        Routine(
            id: "conditioning-blast",
            title: "Conditioning Blast",
            tag: "PHYSICAL",
            blurb: "Endurance and conditioning to outlast every opponent.",
            drillIDs: ["phys-d-1-1", "phys-d-1-2", "phys-d-1-3", "phys-d-1-4"]
        ),
        Routine(
            id: "complete-player",
            title: "The Complete Player",
            tag: "MIXED",
            blurb: "Every discipline. One session. The full MF Elite experience.",
            drillIDs: ["tech-a-1-1", "tech-b-1-1", "tech-d-1-1", "phys-a-1-1", "phys-c-1-1", "tact-a-1-1", "tact-b-1-1", "psy-a-1-1", "psy-c-1-1"]
        )
    ]

    /// drillID → resolved navigation context, built once from the curriculum.
    private var drillIndex: [String: ResolvedDrill] {
        var index: [String: ResolvedDrill] = [:]
        for discipline in disciplines {
            for category in discipline.categories {
                for level in category.levels {
                    for drill in level.drills {
                        index[drill.id] = ResolvedDrill(
                            drill: drill, level: level, category: category, discipline: discipline
                        )
                    }
                }
            }
        }
        return index
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
                        onToggle: { toggle(workout.id.uuidString) },
                        onStart: { startIndex in start(name: workout.title, resolved: resolved, from: startIndex) },
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
            ForEach(Self.routines) { routine in
                let resolved = routine.drillIDs.compactMap { index[$0] }
                RoutineCard(
                    routine: routine,
                    resolved: resolved,
                    loggedToday: doneToday,
                    isExpanded: expanded.contains(routine.id),
                    onToggle: { toggle(routine.id) },
                    onStart: { startIndex in start(routine: routine, resolved: resolved, from: startIndex) }
                )
            }
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s20)
    }

    /// Build a TrainingQueue from a routine (optionally starting partway through)
    /// and present the session player.
    private func start(routine: Routine, resolved: [ResolvedDrill], from startIndex: Int) {
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

/// Estimated minutes for a sequence of drills: total drill time + 15s rest per
/// set gap, rounded to the nearest 5 minutes.
private func estimatedMinutes(_ resolved: [ResolvedDrill]) -> Int {
    let totalSec = resolved.reduce(0) { acc, r in
        acc + r.drill.durationSec + max(0, r.drill.sets - 1) * 15
    }
    let mins = Double(totalSec) / 60
    let rounded = (mins / 5).rounded() * 5
    return max(5, Int(rounded))
}

// MARK: - RoutineCard

private struct RoutineCard: View {
    let routine: Routine
    fileprivate let resolved: [ResolvedDrill]
    let loggedToday: Set<String>
    let isExpanded: Bool
    let onToggle: () -> Void
    /// Start the routine from the given drill index (0 = from the top).
    let onStart: (Int) -> Void

    private var isCompletedToday: Bool {
        !resolved.isEmpty && resolved.allSatisfy { loggedToday.contains($0.drill.id) }
    }

    private var eyebrowText: String {
        "\(routine.tag) · \(estimatedMinutes(resolved)) MIN"
    }

    var body: some View {
        Card(raised: true) {
            VStack(alignment: .leading, spacing: DS.Spacing.s12) {
                Button(action: { withAnimation(DS.Motion.standardSpring) { onToggle() } }) {
                    VStack(alignment: .leading, spacing: DS.Spacing.s8) {
                        HStack {
                            Eyebrow(text: eyebrowText)
                            Spacer()
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(DS.Colors.Ink.quaternary)
                        }

                        Text(routine.title)
                            .style(.title2)
                            .foregroundStyle(DS.Colors.Ink.primary)

                        Text(routine.blurb)
                            .style(.foot)
                            .foregroundStyle(DS.Colors.Ink.tertiary)

                        HStack(spacing: DS.Spacing.s8) {
                            Text("\(resolved.count) drills")
                                .style(.micro)
                                .foregroundStyle(DS.Colors.Ink.quaternary)
                            if isCompletedToday {
                                HStack(spacing: 3) {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 9, weight: .bold))
                                    Text("Completed today")
                                        .style(.micro)
                                }
                                .foregroundStyle(DS.Colors.Ink.primary)
                            }
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableButtonStyle())

                if isExpanded {
                    drillList
                }

                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onStart(0)
                } label: {
                    startLabel
                }
                .buttonStyle(PressableButtonStyle())
                .padding(.top, DS.Spacing.s4)
            }
        }
    }

    private var drillList: some View {
        VStack(spacing: 0) {
            ForEach(Array(resolved.enumerated()), id: \.element.id) { idx, item in
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onStart(idx)
                } label: {
                    HStack(spacing: DS.Spacing.s12) {
                        if loggedToday.contains(item.drill.id) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(DS.Colors.Ink.primary)
                                .frame(width: 18, alignment: .leading)
                        } else {
                            Text("\(idx + 1)")
                                .style(.micro)
                                .foregroundStyle(DS.Colors.Ink.quaternary)
                                .frame(width: 18, alignment: .leading)
                        }
                        DisciplineMark(kind: item.discipline.mark, size: 14)
                        Text(item.drill.title)
                            .style(.callout)
                            .foregroundStyle(DS.Colors.Ink.secondary)
                        Spacer(minLength: 0)
                        Image(systemName: "play.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(DS.Colors.Ink.quaternary)
                    }
                    .contentShape(Rectangle())
                    .padding(.vertical, DS.Spacing.s8)
                }
                .buttonStyle(PressableButtonStyle())

                if idx != resolved.count - 1 {
                    Hairline()
                }
            }
        }
        .padding(.vertical, DS.Spacing.s8)
        .padding(.horizontal, DS.Spacing.s12)
        .background(DS.Colors.Bg.elevated)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    /// White pill that mirrors PrimaryButton styling.
    private var startLabel: some View {
        Text(isCompletedToday ? "Train again" : "Start routine")
            .font(.system(size: 15, weight: .bold))
            .tracking(0.1)
            .foregroundStyle(DS.Colors.Ground.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.pill))
            .pillLightElevation()
    }
}

// MARK: - WorkoutCard

/// A saved custom workout card. Mirrors RoutineCard styling, with edit /
/// duplicate / delete actions in a menu.
private struct WorkoutCard: View {
    let title: String
    fileprivate let resolved: [ResolvedDrill]
    let loggedToday: Set<String>
    let isExpanded: Bool
    let onToggle: () -> Void
    let onStart: (Int) -> Void
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void

    private var isCompletedToday: Bool {
        !resolved.isEmpty && resolved.allSatisfy { loggedToday.contains($0.drill.id) }
    }

    private var eyebrowText: String {
        "WORKOUT · \(estimatedMinutes(resolved)) MIN"
    }

    var body: some View {
        Card(raised: true) {
            VStack(alignment: .leading, spacing: DS.Spacing.s12) {
                Button(action: { withAnimation(DS.Motion.standardSpring) { onToggle() } }) {
                    VStack(alignment: .leading, spacing: DS.Spacing.s8) {
                        HStack {
                            Eyebrow(text: eyebrowText)
                            Spacer()
                            Menu {
                                Button { onEdit() } label: { Label("Edit", systemImage: "pencil") }
                                Button { onDuplicate() } label: { Label("Duplicate", systemImage: "plus.square.on.square") }
                                Button(role: .destructive) { onDelete() } label: { Label("Delete", systemImage: "trash") }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(DS.Colors.Ink.quaternary)
                                    .frame(width: 28, height: 28)
                                    .contentShape(Rectangle())
                            }
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(DS.Colors.Ink.quaternary)
                        }

                        Text(title)
                            .style(.title2)
                            .foregroundStyle(DS.Colors.Ink.primary)

                        HStack(spacing: DS.Spacing.s8) {
                            Text("\(resolved.count) drills")
                                .style(.micro)
                                .foregroundStyle(DS.Colors.Ink.quaternary)
                            if isCompletedToday {
                                HStack(spacing: 3) {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 9, weight: .bold))
                                    Text("Completed today")
                                        .style(.micro)
                                }
                                .foregroundStyle(DS.Colors.Ink.primary)
                            }
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableButtonStyle())

                if isExpanded {
                    drillList
                }

                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onStart(0)
                } label: {
                    Text(isCompletedToday ? "Train again" : "Start workout")
                        .font(.system(size: 15, weight: .bold))
                        .tracking(0.1)
                        .foregroundStyle(DS.Colors.Ground.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.pill))
                        .pillLightElevation()
                }
                .buttonStyle(PressableButtonStyle())
                .padding(.top, DS.Spacing.s4)
            }
        }
    }

    private var drillList: some View {
        VStack(spacing: 0) {
            ForEach(Array(resolved.enumerated()), id: \.offset) { idx, item in
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onStart(idx)
                } label: {
                    HStack(spacing: DS.Spacing.s12) {
                        if loggedToday.contains(item.drill.id) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(DS.Colors.Ink.primary)
                                .frame(width: 18, alignment: .leading)
                        } else {
                            Text("\(idx + 1)")
                                .style(.micro)
                                .foregroundStyle(DS.Colors.Ink.quaternary)
                                .frame(width: 18, alignment: .leading)
                        }
                        DisciplineMark(kind: item.discipline.mark, size: 14)
                        Text(item.drill.title)
                            .style(.callout)
                            .foregroundStyle(DS.Colors.Ink.secondary)
                        Spacer(minLength: 0)
                        Image(systemName: "play.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(DS.Colors.Ink.quaternary)
                    }
                    .contentShape(Rectangle())
                    .padding(.vertical, DS.Spacing.s8)
                }
                .buttonStyle(PressableButtonStyle())

                if idx != resolved.count - 1 {
                    Hairline()
                }
            }
        }
        .padding(.vertical, DS.Spacing.s8)
        .padding(.horizontal, DS.Spacing.s12)
        .background(DS.Colors.Bg.elevated)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
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
