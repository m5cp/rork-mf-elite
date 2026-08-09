//
//  MyWorkoutsView.swift
//  MFElite
//
//  A dedicated home for every custom workout the player has built. Reached from
//  the home "See all" link and the academy hub. Each workout can be started,
//  marked complete without the timer, favorited, edited, duplicated or deleted.
//

import SwiftUI
import SwiftData

/// Navigation route to the dedicated My Workouts screen.
struct MyWorkoutsRoute: Hashable {}

struct MyWorkoutsView: View {
    @Query(sort: \Discipline.sortIndex) private var disciplines: [Discipline]
    @Query private var sessionLog: [SessionLogEntry]
    @Query(sort: \CustomWorkout.updatedAt, order: .reverse) private var workouts: [CustomWorkout]
    @Environment(SubscriptionService.self) private var subscription
    @Environment(\.modelContext) private var context

    @State private var indexCache = DrillIndexCache()
    @State private var activeSession: TrainingQueue?
    @State private var showBuilder = false
    @State private var editingWorkout: CustomWorkout?
    @State private var workoutToDelete: CustomWorkout?
    @State private var sharingWorkout: ShareableWorkout?
    @State private var showScanner = false
    @State private var scannedPayload: WorkoutShare.Payload?
    @State private var markCompleteTarget: MarkCompleteTarget?
    @State private var lastLogResult: QuickLog.Result?
    @State private var streakMilestone: StreakMilestone?
    @State private var favorites = FavoritesStore.shared

    private struct MarkCompleteTarget: Identifiable {
        let id = UUID()
        let name: String
        let contexts: [DrillContext]
    }

    private var canCreateWorkout: Bool {
        subscription.hasFullAccess || workouts.count < 1
    }

    private var drillIndex: [String: ResolvedDrill] {
        buildDrillIndex(disciplines, cache: indexCache)
    }

    private var loggedTodayIDs: Set<String> {
        let cal = Calendar.current
        return Set(sessionLog.filter { cal.isDateInToday($0.completedAt) }.map(\.drillID))
    }

    var body: some View {
        let index = drillIndex
        let doneToday = loggedTodayIDs
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.s16) {
                header
                scanButton
                if workouts.isEmpty {
                    emptyCard
                } else {
                    ForEach(workouts) { workout in
                        let resolved: [ResolvedDrill] = workout.drillIDs.compactMap { index[$0] }
                        WorkoutCard(
                            title: workout.title,
                            resolved: resolved,
                            loggedToday: doneToday,
                            isFavorited: favorites.isFavoriteWorkout(workout.id),
                            isShared: workout.isShared,
                            onStart: { startIndex in start(name: workout.title, resolved: resolved, from: startIndex) },
                            onMarkComplete: {
                                markCompleteTarget = MarkCompleteTarget(
                                    name: workout.title, contexts: resolved.map(\.context)
                                )
                            },
                            onToggleFavorite: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                favorites.toggleWorkout(workout.id)
                            },
                            onEdit: { editingWorkout = workout },
                            onDuplicate: { duplicate(workout) },
                            onDelete: { workoutToDelete = workout },
                            onShare: { share(workout, resolved: resolved) },
                            onMakePlan: { makePlan(workout) }
                        )
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.top, DS.Spacing.s16)
            .padding(.bottom, 120)
        }
        .background(DS.Colors.Bg.base)
        .scrollIndicators(.hidden)
        .navigationTitle("My Workouts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { startCreate() } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(DS.Colors.Ink.primary)
                }
            }
        }
        .fullScreenCover(item: $activeSession) { queue in
            SessionPlayerView(queue: queue)
        }
        .fullScreenCover(item: $streakMilestone) { milestone in
            StreakMilestoneView(days: milestone.days, onClose: {})
        }
        .sheet(isPresented: $showBuilder) { WorkoutBuilderView() }
        .sheet(item: $editingWorkout) { workout in WorkoutBuilderView(editing: workout) }
        .sheet(item: $sharingWorkout) { workout in WorkoutShareView(workout: workout) }
        .fullScreenCover(isPresented: $showScanner) {
            WorkoutScannerView { payload in scannedPayload = payload }
        }
        .sheet(item: $scannedPayload) { payload in WorkoutImportView(payload: payload) }
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
                QuickLogToast(result: result)
                    .padding(.bottom, 32)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s8) {
            ArtworkBanner(name: MFArtwork.workouts)
                .padding(.bottom, DS.Spacing.s12)

            Eyebrow(text: "My Workouts")
            Text("Your Sessions")
                .style(.title1)
                .foregroundStyle(DS.Colors.Ink.primary)
            Text(workouts.isEmpty
                 ? "Build your own session from any drill in the academy."
                 : "\(workouts.count) saved \(workouts.count == 1 ? "workout" : "workouts"). Start, edit, or favorite any of them.")
                .style(.body)
                .foregroundStyle(DS.Colors.Ink.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, DS.Spacing.s4)
    }

    private var scanButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            showScanner = true
        } label: {
            HStack(spacing: DS.Spacing.s12) {
                Image(systemName: "qrcode.viewfinder")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(DS.Colors.Ink.primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Scan a workout")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(DS.Colors.Ink.primary)
                    Text("Import a teammate's QR code")
                        .style(.micro)
                        .foregroundStyle(DS.Colors.Ink.quaternary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DS.Colors.Ink.quaternary)
            }
            .padding(DS.Spacing.s16)
            .frame(maxWidth: .infinity)
            .background(DS.Colors.Bg.card)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(DS.Colors.Line.hairline, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var emptyCard: some View {
        Card(raised: true) {
            VStack(alignment: .leading, spacing: DS.Spacing.s12) {
                Text("You haven't built a workout yet. Pick the drills you want to work on and they'll run back-to-back.")
                    .style(.foot)
                    .foregroundStyle(DS.Colors.Ink.secondary)
                    .fixedSize(horizontal: false, vertical: true)
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

    // MARK: - Actions

    private var deleteAlertBinding: Binding<Bool> {
        Binding(get: { workoutToDelete != nil }, set: { if !$0 { workoutToDelete = nil } })
    }

    private var markCompleteBinding: Binding<Bool> {
        Binding(get: { markCompleteTarget != nil }, set: { if !$0 { markCompleteTarget = nil } })
    }

    private func startCreate() {
        guard canCreateWorkout else { subscription.presentPaywall(); return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        showBuilder = true
    }

    private func share(_ workout: CustomWorkout, resolved: [ResolvedDrill]) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        sharingWorkout = ShareableWorkout(
            id: workout.id,
            title: workout.title,
            drillIDs: workout.drillIDs,
            drillCount: resolved.count,
            minutes: estimatedMinutes(resolved)
        )
    }

    private func duplicate(_ workout: CustomWorkout) {
        guard canCreateWorkout else { subscription.presentPaywall(); return }
        let copy = CustomWorkout(title: "\(workout.title) Copy", drillIDs: workout.drillIDs)
        context.insert(copy)
        try? context.save()
        SyncEngine.shared.enqueueCustomWorkout(copy)
    }

    private func delete(_ workout: CustomWorkout) {
        favorites.removeWorkout(workout.id)
        let id = workout.id
        context.delete(workout)
        try? context.save()
        SyncEngine.shared.enqueueCustomWorkoutDeletion(id: id)
        workoutToDelete = nil
    }

    private func start(name: String, resolved: [ResolvedDrill], from startIndex: Int) {
        let slice = Array(resolved.dropFirst(startIndex))
        guard !slice.isEmpty else { return }
        activeSession = TrainingQueue(items: slice.map(\.context), source: .workout, sourceName: name)
    }

    /// Commit a custom workout as the player's single active plan and return to
    /// Today, where the hero card now renders it.
    private func makePlan(_ workout: CustomWorkout) {
        ActivePlan.commit(
            ActivePlan(kind: .customWorkout, referenceID: workout.id.uuidString, title: workout.title, sessions: [workout.drillIDs]),
            in: context
        )
        AppActionRouter.shared.pendingTab = .today
    }

    private func markComplete(_ target: MarkCompleteTarget) {
        let result = QuickLog.logDrills(
            target.contexts, source: .workout, sourceName: target.name, context: context
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
