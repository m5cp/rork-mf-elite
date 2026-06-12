//
//  RoutineSupport.swift
//  MFElite
//
//  Shared building blocks for routines and custom workouts: the curated routine
//  catalog, a resolved-drill type, the duration estimate, and the reusable
//  RoutineCard / WorkoutCard. Used by RoutinesView, MyWorkoutsView and the
//  Favorites collection so all three stay visually and behaviorally consistent.
//

import SwiftUI

// MARK: - Routine catalog

/// A curated routine spec: metadata plus the drill IDs it chains.
struct RoutineSpec: Identifiable, Hashable {
    let id: String
    let title: String
    let tag: String
    let blurb: String
    let drillIDs: [String]
}

/// The fixed set of curated routines shipped with the app.
enum RoutineCatalog {
    static let all: [RoutineSpec] = [
        RoutineSpec(
            id: "daily-touch",
            title: "Daily Touch",
            tag: "QUICK SESSION",
            blurb: "A short ball mastery warm-up to start your day.",
            drillIDs: ["tech-a-1-1", "tech-a-1-2", "tech-a-1-3"]
        ),
        RoutineSpec(
            id: "full-technical",
            title: "Full Technical",
            tag: "TECHNICAL",
            blurb: "Touch, control, passing and finishing in one complete block.",
            drillIDs: ["tech-a-2-1", "tech-b-2-1", "tech-c-1-1", "tech-c-2-1", "tech-d-2-1", "tech-e-1-1"]
        ),
        RoutineSpec(
            id: "speed-agility",
            title: "Speed & Agility",
            tag: "PHYSICAL",
            blurb: "Explosive sprints and sharp change-of-direction work.",
            drillIDs: ["phys-a-1-1", "phys-a-1-2", "phys-b-1-1", "phys-b-1-2"]
        ),
        RoutineSpec(
            id: "game-day-prep",
            title: "Game Day Prep",
            tag: "MIXED",
            blurb: "Sharpen technique, fire the legs, and lock in the mind.",
            drillIDs: ["tech-a-1-1", "tech-c-1-2", "phys-a-1-1", "psy-a-1-1"]
        ),
        RoutineSpec(
            id: "first-touch-clinic",
            title: "First Touch Clinic",
            tag: "TECHNICAL",
            blurb: "Five drills focused purely on your first touch under pressure.",
            drillIDs: ["tech-b-1-1", "tech-b-1-2", "tech-b-1-3", "tech-b-1-4", "tech-b-2-1"]
        ),
        RoutineSpec(
            id: "finishing-school",
            title: "Finishing School",
            tag: "TECHNICAL",
            blurb: "Finishing drills — placement, power, and composure in front of goal.",
            drillIDs: ["tech-e-1-1", "tech-e-1-2", "tech-e-1-3", "tech-e-2-1", "tech-e-2-2"]
        ),
        RoutineSpec(
            id: "mental-edge",
            title: "Mental Edge",
            tag: "MENTAL",
            blurb: "Build your mind. Self-talk, focus, and composure drills.",
            drillIDs: ["psy-a-1-1", "psy-b-1-1", "psy-d-1-1", "psy-e-1-1"]
        ),
        RoutineSpec(
            id: "dribbling-gauntlet",
            title: "Dribbling Gauntlet",
            tag: "TECHNICAL",
            blurb: "Take on defenders. Close control, feints, and 1v1 moves.",
            drillIDs: ["tech-d-1-1", "tech-d-1-2", "tech-d-1-3", "tech-d-2-1", "tech-d-2-2"]
        ),
        RoutineSpec(
            id: "conditioning-blast",
            title: "Conditioning Blast",
            tag: "PHYSICAL",
            blurb: "Endurance and conditioning to outlast every opponent.",
            drillIDs: ["phys-d-1-1", "phys-d-1-2", "phys-d-1-3", "phys-d-1-4"]
        ),
        RoutineSpec(
            id: "complete-player",
            title: "The Complete Player",
            tag: "MIXED",
            blurb: "Every discipline. One session. The full MF Elite experience.",
            drillIDs: ["tech-a-1-1", "tech-b-1-1", "tech-d-1-1", "phys-a-1-1", "phys-c-1-1", "tact-a-1-1", "tact-b-1-1", "psy-a-1-1", "psy-c-1-1"]
        )
    ]

    static func routine(id: String) -> RoutineSpec? {
        all.first { $0.id == id }
    }
}

// MARK: - Resolved drill

/// A drill ID resolved to its full navigation context + title.
struct ResolvedDrill: Identifiable {
    let drill: Drill
    let level: MasteryLevel
    let category: Category
    let discipline: Discipline
    var id: String { drill.id }

    var context: DrillContext {
        DrillContext(drill: drill, level: level, category: category, discipline: discipline)
    }
}

/// Reference-type memo so the drillID→context map is built once and reused across
/// body evaluations, rebuilding only when the curriculum graph changes.
final class DrillIndexCache {
    var signature: Int = -1
    var index: [String: ResolvedDrill] = [:]
}

/// Build a drillID → resolved-drill index from the discipline graph.
func buildDrillIndex(_ disciplines: [Discipline], cache: DrillIndexCache) -> [String: ResolvedDrill] {
    let signature = disciplines.map { ObjectIdentifier($0) }.hashValue
    if cache.signature != signature {
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
        cache.index = index
        cache.signature = signature
    }
    return cache.index
}

/// Estimated minutes for a sequence of drills: total drill time + 15s rest per
/// set gap, rounded to the nearest 5 minutes.
func estimatedMinutes(_ resolved: [ResolvedDrill]) -> Int {
    let totalSec = resolved.reduce(0) { acc, r in
        acc + r.drill.durationSec + max(0, r.drill.sets - 1) * 15
    }
    let mins = Double(totalSec) / 60
    let rounded = (mins / 5).rounded() * 5
    return max(5, Int(rounded))
}

// MARK: - Quick-log toast

/// White confirmation pill shown after a timer-free "mark complete" log.
struct QuickLogToast: View {
    let result: QuickLog.Result

    var body: some View {
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
}

// MARK: - Favorite heart

/// Small circular heart toggle used on routine and workout cards.
struct FavoriteHeartButton: View {
    let isFavorited: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isFavorited ? "heart.fill" : "heart")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isFavorited ? DS.Colors.Ink.primary : DS.Colors.Ink.quaternary)
                .frame(width: 36, height: 36)
                .background(DS.Colors.Bg.raised)
                .clipShape(Circle())
                .overlay(Circle().stroke(DS.Colors.Line.hairline, lineWidth: 1))
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(isFavorited ? "Remove from favorites" : "Add to favorites")
    }
}

// MARK: - RoutineCard

struct RoutineCard: View {
    let routine: RoutineSpec
    let resolved: [ResolvedDrill]
    let loggedToday: Set<String>
    let isExpanded: Bool
    let isFavorited: Bool
    let onToggle: () -> Void
    /// Start the routine from the given drill index (0 = from the top).
    let onStart: (Int) -> Void
    /// Log every drill in the routine at once, no timer.
    let onMarkComplete: () -> Void
    let onToggleFavorite: () -> Void

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
                            FavoriteHeartButton(isFavorited: isFavorited, action: onToggleFavorite)
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
                    DrillSequenceList(resolved: resolved, loggedToday: loggedToday, onStart: onStart)
                }

                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onStart(0)
                } label: {
                    startLabel
                }
                .buttonStyle(PressableButtonStyle())
                .padding(.top, DS.Spacing.s4)

                Button(action: onMarkComplete) {
                    Label("Mark complete — no timer", systemImage: "checkmark.circle")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
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
struct WorkoutCard: View {
    let title: String
    let resolved: [ResolvedDrill]
    let loggedToday: Set<String>
    let isExpanded: Bool
    let isFavorited: Bool
    var isShared: Bool = false
    let onToggle: () -> Void
    let onStart: (Int) -> Void
    let onMarkComplete: () -> Void
    let onToggleFavorite: () -> Void
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void
    let onShare: () -> Void

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
                            FavoriteHeartButton(isFavorited: isFavorited, action: onToggleFavorite)
                            Menu {
                                Button { onEdit() } label: { Label("Edit", systemImage: "pencil") }
                                Button { onDuplicate() } label: { Label("Duplicate", systemImage: "plus.square.on.square") }
                                Button { onShare() } label: { Label("Share", systemImage: "qrcode") }
                                Button(role: .destructive) { onDelete() } label: { Label("Delete", systemImage: "trash") }
                                Button { onMarkComplete() } label: { Label("Mark complete", systemImage: "checkmark.circle") }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(DS.Colors.Ink.quaternary)
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                                    .accessibilityLabel("Workout options")
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
                            if isShared {
                                Text("SHARED")
                                    .style(.micro)
                                    .foregroundStyle(DS.Colors.Ground.primary)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 2)
                                    .background(Color.white, in: Capsule())
                            }
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
                    DrillSequenceList(resolved: resolved, loggedToday: loggedToday, onStart: onStart)
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

                Button(action: onMarkComplete) {
                    Label("Mark complete — no timer", systemImage: "checkmark.circle")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
    }
}

// MARK: - Drill sequence list

/// The expandable list of drills inside a routine or workout card. Each row is
/// tappable to start the session partway through.
struct DrillSequenceList: View {
    let resolved: [ResolvedDrill]
    let loggedToday: Set<String>
    let onStart: (Int) -> Void

    var body: some View {
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
