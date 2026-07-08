//
//  CoachsChoiceSection.swift
//  MFElite
//
//  "Coach's Choice" — surfaces up to five of the synced coach workouts as
//  compact rows, most recent first. Tapping a row opens the existing
//  CoachWorkoutDetailView (start the session or save it to My Workouts).
//  Self-contained: queries the feed, resolves drills, and owns its sheet +
//  session presentation so it can be dropped into any screen. Hidden entirely
//  when there are no resolvable coach workouts.
//

import SwiftUI
import SwiftData

struct CoachsChoiceSection: View {
    @Query(sort: \Discipline.sortIndex) private var disciplines: [Discipline]
    @Query(sort: \CoachWorkout.createdAt, order: .reverse) private var coachWorkouts: [CoachWorkout]
    @Environment(\.modelContext) private var modelContext

    @State private var indexCache = DrillIndexCache()
    @State private var sheetWorkout: CoachWorkout?
    @State private var activeSession: TrainingQueue?

    /// Most recent coach workouts whose drills still resolve in this build.
    private var visibleWorkouts: [CoachWorkout] {
        let index = buildDrillIndex(disciplines, cache: indexCache)
        return coachWorkouts
            .filter { !$0.drillIDs.compactMap { index[$0] }.isEmpty }
            .prefix(5)
            .map { $0 }
    }

    private func resolvedItems(_ workout: CoachWorkout) -> [DrillContext] {
        let index = buildDrillIndex(disciplines, cache: indexCache)
        return workout.drillIDs.compactMap { index[$0]?.context }
    }

    var body: some View {
        let workouts = visibleWorkouts
        if !workouts.isEmpty {
            VStack(alignment: .leading, spacing: DS.Spacing.s12) {
                Eyebrow(text: "Coach's Choice")
                    .padding(.horizontal, DS.Spacing.s20)

                VStack(spacing: DS.Spacing.s8) {
                    ForEach(workouts) { workout in
                        coachRow(workout)
                    }
                }
                .padding(.horizontal, DS.Spacing.s20)
            }
            .padding(.top, DS.Spacing.s24 + 4)
            .sheet(item: $sheetWorkout) { workout in
                let items = resolvedItems(workout)
                CoachWorkoutDetailView(
                    workout: workout,
                    items: items,
                    onStart: {
                        sheetWorkout = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            activeSession = TrainingQueue(items: items, source: .workout, sourceName: workout.title)
                        }
                    },
                    onSave: { saveToMine(workout, items: items) },
                    onMakePlan: { makePlan(workout) }
                )
                .presentationDetents([.medium, .large])
                .presentationBackground(DS.Colors.Bg.base)
            }
            .fullScreenCover(item: $activeSession) { queue in
                SessionPlayerView(queue: queue)
            }
        }
    }

    private func coachRow(_ workout: CoachWorkout) -> some View {
        let items = resolvedItems(workout)
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            sheetWorkout = workout
        } label: {
            HStack(spacing: DS.Spacing.s12) {
                Image(systemName: "figure.soccer")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(DS.Colors.Ink.primary)
                    .frame(width: 44, height: 44)
                    .background(DS.Colors.Bg.raised)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                    .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(DS.Colors.Line.hairline, lineWidth: 1))

                VStack(alignment: .leading, spacing: DS.Spacing.s4) {
                    Eyebrow(text: "From Coach \(workout.coachName.uppercased())")
                    Text(workout.title)
                        .style(.callout)
                        .fontWeight(.semibold)
                        .foregroundStyle(DS.Colors.Ink.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(workout.createdAt.formatted(.dateTime.month().day())) · \(items.count) \(items.count == 1 ? "drill" : "drills") · \(estimatedSessionMinutes(forDrills: items.map(\.drill))) min")
                        .style(.micro)
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DS.Colors.Ink.quaternary)
            }
            .padding(DS.Spacing.s16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DS.Colors.Bg.elevated)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.lg).stroke(DS.Colors.Line.hairline, lineWidth: 1))
        }
        .buttonStyle(PressableButtonStyle())
    }

    /// Commit a coach workout as the player's single active plan, close the
    /// sheet, and return to Today where the hero card now renders it.
    private func makePlan(_ workout: CoachWorkout) {
        ActivePlan.commit(
            ActivePlan(kind: .coachWorkout, referenceID: workout.id.uuidString, title: workout.title, sessions: [workout.drillIDs]),
            in: modelContext
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            sheetWorkout = nil
            AppActionRouter.shared.pendingTab = .today
        }
    }

    /// Copy a coach workout into the player's own custom workouts (tagged as a
    /// coach import) so they keep it after the sync window. Their existing
    /// custom workouts are never altered.
    private func saveToMine(_ workout: CoachWorkout, items: [DrillContext]) {
        guard !items.isEmpty else { return }
        let copy = CustomWorkout(
            title: workout.title,
            drillIDs: items.map(\.drill.id),
            isShared: true
        )
        modelContext.insert(copy)
        try? modelContext.save()
        SyncEngine.shared.enqueueCustomWorkout(copy)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
