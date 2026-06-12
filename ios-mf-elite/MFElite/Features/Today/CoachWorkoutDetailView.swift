//
//  CoachWorkoutDetailView.swift
//  MFElite
//
//  Player-facing detail for a coach-published "Workout of the Day": the note,
//  the resolved drill list, "Start workout" (runs it as a chained queue), and
//  "Save to My Workouts" (keeps a copy after the 7-day window). Read-only over
//  the coach's content — nothing here alters the player's own custom workouts.
//

import SwiftUI

struct CoachWorkoutDetailView: View {
    let workout: CoachWorkout
    let items: [DrillContext]
    let onStart: () -> Void
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var didSave = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.s16) {
                    header
                    if !workout.note.isEmpty {
                        Text(workout.note)
                            .style(.body)
                            .foregroundStyle(DS.Colors.Ink.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    drillList
                }
                .padding(.horizontal, DS.Spacing.s20)
                .padding(.top, DS.Spacing.s8)
                .padding(.bottom, 140)
            }
            .background(DS.Colors.Bg.base)
            .scrollIndicators(.hidden)
            .navigationTitle("Coach's Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(DS.Colors.Ink.secondary)
                }
            }
            .safeAreaInset(edge: .bottom) { bottomBar }
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s8) {
            Eyebrow(text: "From Coach \(workout.coachName.uppercased())")
            Text(workout.title)
                .style(.title1)
                .foregroundStyle(DS.Colors.Ink.primary)
                .fixedSize(horizontal: false, vertical: true)
            Text("\(items.count) \(items.count == 1 ? "drill" : "drills") · \(estimatedSessionMinutes(forDrills: items.map(\.drill))) min")
                .style(.micro)
                .foregroundStyle(DS.Colors.Ink.quaternary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, DS.Spacing.s8)
    }

    private var drillList: some View {
        VStack(spacing: DS.Spacing.s8) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, ctx in
                HStack(spacing: DS.Spacing.s12) {
                    Text("\(index + 1)")
                        .style(.foot)
                        .fontWeight(.bold)
                        .foregroundStyle(DS.Colors.Ink.primary)
                        .frame(width: 28, height: 28)
                        .background(DS.Colors.Bg.raised)
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ctx.drill.title)
                            .style(.callout)
                            .foregroundStyle(DS.Colors.Ink.primary)
                            .lineLimit(2)
                        Text("\(ctx.discipline.name) · \(ctx.drill.focus)")
                            .style(.micro)
                            .foregroundStyle(DS.Colors.Ink.tertiary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    DisciplineMark(kind: ctx.discipline.mark, size: 16)
                }
                .padding(DS.Spacing.s12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DS.Colors.Bg.card)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.md)
                        .stroke(DS.Colors.Line.hairline, lineWidth: 1)
                )
            }
        }
    }

    private var bottomBar: some View {
        VStack(spacing: DS.Spacing.s12) {
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onStart()
            } label: {
                Text("Start workout")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(DS.Colors.Ground.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.pill))
                    .pillLightElevation()
            }
            .buttonStyle(PressableButtonStyle())
            .disabled(items.isEmpty)

            Button {
                guard !didSave else { return }
                onSave()
                withAnimation(DS.Motion.standardSpring) { didSave = true }
            } label: {
                HStack(spacing: DS.Spacing.s8) {
                    Image(systemName: didSave ? "checkmark.circle.fill" : "bookmark")
                        .font(.system(size: 15, weight: .semibold))
                    Text(didSave ? "Saved to My Workouts" : "Save to My Workouts")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(DS.Colors.Ink.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(DS.Colors.Bg.raised)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.pill))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.pill)
                        .stroke(DS.Colors.Line.hairline, lineWidth: 1)
                )
            }
            .buttonStyle(PressableButtonStyle())
            .disabled(didSave || items.isEmpty)
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.vertical, DS.Spacing.s12)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Hairline() }
    }
}
