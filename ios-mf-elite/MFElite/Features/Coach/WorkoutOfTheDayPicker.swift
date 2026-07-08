//
//  WorkoutOfTheDayPicker.swift
//  MFElite
//
//  Coach-only sheet for choosing the team's Workout of the Day. Lists the
//  coach's own published workouts plus the curated stock routines; selecting
//  one republishes it through the existing coach-workout publish flow (a new
//  row with createdAt = now becomes the latest, and therefore the players'
//  WOD via the Today fallback chain).
//

import SwiftUI

struct WorkoutOfTheDayPicker: View {
    /// The coach's previously published workouts, newest first.
    let coachWorkouts: [CoachPublishedWorkout]
    /// drillID → resolved drill, for drill counts and minutes estimates.
    let drillIndex: [String: ResolvedDrill]
    /// Publishes the selection: (title, note, drillIDs).
    let onSelect: (String, String, [String]) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.s24) {
                    if !coachWorkouts.isEmpty {
                        section(title: "Your Workouts") {
                            ForEach(coachWorkouts) { workout in
                                pickRow(
                                    title: workout.title,
                                    drillIDs: workout.drillIDs,
                                    detail: workout.note
                                ) {
                                    select(title: workout.title, note: workout.note, drillIDs: workout.drillIDs)
                                }
                            }
                        }
                    }

                    section(title: "Stock Routines") {
                        ForEach(RoutineCatalog.all) { routine in
                            pickRow(
                                title: routine.title,
                                drillIDs: routine.drillIDs,
                                detail: routine.blurb
                            ) {
                                select(title: routine.title, note: routine.blurb, drillIDs: routine.drillIDs)
                            }
                        }
                    }
                }
                .padding(.horizontal, DS.Spacing.s20)
                .padding(.top, DS.Spacing.s16)
                .padding(.bottom, DS.Spacing.s48)
            }
            .background(DS.Colors.Bg.base)
            .scrollIndicators(.hidden)
            .navigationTitle("Set Workout of the Day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(DS.Colors.Ink.secondary)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func select(title: String, note: String, drillIDs: [String]) {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        onSelect(title, note, drillIDs)
        dismiss()
    }

    private func section(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s12) {
            Eyebrow(text: title)
            VStack(spacing: DS.Spacing.s8) {
                content()
            }
        }
    }

    private func pickRow(
        title: String,
        drillIDs: [String],
        detail: String,
        action: @escaping () -> Void
    ) -> some View {
        let resolved = drillIDs.compactMap { drillIndex[$0] }
        return Button(action: action) {
            HStack(spacing: DS.Spacing.s12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .style(.title3)
                        .foregroundStyle(DS.Colors.Ink.primary)
                        .lineLimit(1)
                    Text("\(resolved.count) \(resolved.count == 1 ? "drill" : "drills") · \(estimatedMinutes(resolved)) min")
                        .style(.micro)
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                    if !detail.isEmpty {
                        Text(detail)
                            .style(.micro)
                            .foregroundStyle(DS.Colors.Ink.quaternary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: DS.Spacing.s8)
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(DS.Colors.Ink.primary)
            }
            .padding(DS.Spacing.s12)
            .background(DS.Colors.Bg.card)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .stroke(DS.Colors.Line.hairline, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel("Set \(title) as Workout of the Day")
    }
}
