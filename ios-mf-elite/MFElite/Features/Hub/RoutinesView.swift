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

// MARK: - Future: Video/Film
// A "Film Study" routine (tactical demo films) plugs in here once coach video is
// shipped. Add a video-backed Routine entry and a player surface for it then.

/// A curated routine spec: metadata plus the drill IDs it chains.
private struct Routine: Identifiable {
    let id: String
    let title: String
    let duration: String
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

    @State private var expanded: Set<String> = []

    private static let routines: [Routine] = [
        Routine(
            id: "daily-touch",
            title: "Daily Touch",
            duration: "QUICK SESSION · 15 MIN",
            blurb: "A short ball mastery warm-up to start your day.",
            drillIDs: ["tech-a-1-1", "tech-a-1-2", "tech-a-1-3"]
        ),
        Routine(
            id: "full-technical",
            title: "Full Technical",
            duration: "TECHNICAL · 30 MIN",
            blurb: "Touch, control, passing and finishing in one complete block.",
            drillIDs: ["tech-a-2-1", "tech-b-2-1", "tech-c-1-1", "tech-c-2-1", "tech-d-2-1", "tech-e-1-1"]
        ),
        Routine(
            id: "speed-agility",
            title: "Speed & Agility",
            duration: "PHYSICAL · 20 MIN",
            blurb: "Explosive sprints and sharp change-of-direction work.",
            drillIDs: ["phys-a-1-1", "phys-a-1-2", "phys-b-1-1", "phys-b-1-2"]
        ),
        Routine(
            id: "game-day-prep",
            title: "Game Day Prep",
            duration: "MIXED · 25 MIN",
            blurb: "Sharpen technique, fire the legs, and lock in the mind.",
            drillIDs: ["tech-a-1-1", "tech-c-1-2", "phys-a-1-1", "psy-a-1-1"]
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

    var body: some View {
        let index = drillIndex
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                routineCards(index)
            }
            .padding(.bottom, 120)
        }
        .background(DS.Colors.Bg.base)
        .scrollIndicators(.hidden)
        .navigationBarTitleDisplayMode(.inline)
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

    private func routineCards(_ index: [String: ResolvedDrill]) -> some View {
        VStack(spacing: DS.Spacing.s16) {
            ForEach(Self.routines) { routine in
                let resolved = routine.drillIDs.compactMap { index[$0] }
                RoutineCard(
                    routine: routine,
                    resolved: resolved,
                    isExpanded: expanded.contains(routine.id),
                    onToggle: { toggle(routine.id) }
                )
            }
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s20)
    }

    private func toggle(_ id: String) {
        if expanded.contains(id) {
            expanded.remove(id)
        } else {
            expanded.insert(id)
        }
    }
}

// MARK: - RoutineCard

private struct RoutineCard: View {
    let routine: Routine
    fileprivate let resolved: [ResolvedDrill]
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        Card(raised: true) {
            VStack(alignment: .leading, spacing: DS.Spacing.s12) {
                Button(action: { withAnimation(DS.Motion.standardSpring) { onToggle() } }) {
                    VStack(alignment: .leading, spacing: DS.Spacing.s8) {
                        HStack {
                            Eyebrow(text: routine.duration)
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

                        Text("\(resolved.count) drills")
                            .style(.micro)
                            .foregroundStyle(DS.Colors.Ink.quaternary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableButtonStyle())

                if isExpanded {
                    drillList
                }

                if let first = resolved.first {
                    NavigationLink(value: DrillRoute(
                        discipline: first.discipline,
                        category: first.category,
                        level: first.level,
                        drill: first.drill
                    )) {
                        startLabel
                    }
                    .buttonStyle(PressableButtonStyle())
                    .padding(.top, DS.Spacing.s4)
                }
            }
        }
    }

    private var drillList: some View {
        VStack(spacing: 0) {
            ForEach(Array(resolved.enumerated()), id: \.element.id) { idx, item in
                HStack(spacing: DS.Spacing.s12) {
                    Text("\(idx + 1)")
                        .style(.micro)
                        .foregroundStyle(DS.Colors.Ink.quaternary)
                        .frame(width: 18, alignment: .leading)
                    DisciplineMark(kind: item.discipline.mark, size: 14)
                    Text(item.drill.title)
                        .style(.callout)
                        .foregroundStyle(DS.Colors.Ink.secondary)
                    Spacer(minLength: 0)
                }
                .padding(.vertical, DS.Spacing.s8)

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

    /// White pill that mirrors PrimaryButton styling but acts as a NavigationLink label.
    private var startLabel: some View {
        Text("Start routine")
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
