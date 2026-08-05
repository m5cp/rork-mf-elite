//
//  DrillLibraryView.swift
//  MFElite
//
//  Browse every drill in the curriculum by category. The root shows a hero
//  card per category (grouped by discipline) with progress at a glance; tapping
//  one drills into that category's drill list, where each drill opens its full
//  detail. A mastery filter is scoped inside each category.
//

import SwiftUI
import SwiftData

/// Navigation route to the drill library.
struct DrillLibraryRoute: Hashable {}

/// Pushes the drill list for one category inside the library.
private struct LibraryCategoryRoute: Hashable {
    let category: Category
    let discipline: Discipline
}

struct DrillLibraryView: View {
    @Query(sort: \Discipline.sortIndex) private var disciplines: [Discipline]
    @Query private var progress: [DrillProgress]

    private var passesByDrill: [String: Int] {
        Dictionary(progress.map { ($0.drillID, $0.passesLogged) }, uniquingKeysWith: { a, _ in a })
    }

    private var masteredIDs: Set<String> {
        Set(progress.filter { $0.isMastered }.map { $0.drillID })
    }

    private var sortedDisciplines: [Discipline] {
        disciplines.sorted(by: { $0.sortIndex < $1.sortIndex })
    }

    private var totalDrills: Int {
        disciplines.reduce(0) { acc, d in
            acc + d.categories.reduce(0) { $0 + $1.levels.reduce(0) { $0 + $1.drills.count } }
        }
    }

    private var totalCategories: Int {
        disciplines.reduce(0) { $0 + $1.categories.count }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                header
                ForEach(sortedDisciplines) { discipline in
                    disciplineSection(discipline)
                }
            }
            .padding(.bottom, 120)
        }
        .background(DS.Colors.Bg.base)
        .scrollIndicators(.hidden)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: LibraryCategoryRoute.self) { route in
            LibraryCategoryView(
                category: route.category,
                discipline: route.discipline,
                passesByDrill: passesByDrill,
                masteredIDs: masteredIDs
            )
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s8) {
            Eyebrow(text: "Drill Library")
            Text("All Drills")
                .style(.title1)
                .foregroundStyle(DS.Colors.Ink.primary)
            Text("\(totalDrills) drills across \(totalCategories) categories")
                .style(.foot)
                .foregroundStyle(DS.Colors.Ink.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s20)
    }

    // MARK: - Discipline section

    private func disciplineSection(_ discipline: Discipline) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: DS.Spacing.s8) {
                DisciplineMark(kind: discipline.mark, size: 16)
                Text(discipline.name)
                    .style(.title3)
                    .foregroundStyle(DS.Colors.Ink.primary)
            }
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.top, DS.Spacing.s24)
            .padding(.bottom, DS.Spacing.s12)

            ForEach(discipline.categories.sorted(by: { $0.sortIndex < $1.sortIndex })) { category in
                let drills = drills(in: category)
                if !drills.isEmpty {
                    let mastered = drills.filter { masteredIDs.contains($0.id) }.count
                    NavigationLink(value: LibraryCategoryRoute(category: category, discipline: discipline)) {
                        LibraryCategoryCard(
                            category: category,
                            drillCount: drills.count,
                            masteredCount: mastered
                        )
                    }
                    .buttonStyle(PressableButtonStyle())
                    .padding(.horizontal, DS.Spacing.s20)
                    .padding(.bottom, DS.Spacing.s12)
                }
            }
        }
    }

    private func drills(in category: Category) -> [Drill] {
        category.levels
            .sorted(by: { $0.sortIndex < $1.sortIndex })
            .flatMap { $0.drills.sorted(by: { $0.sortIndex < $1.sortIndex }) }
    }
}

// MARK: - Category hero card

/// A large, tappable card representing one category, showing how many of its
/// drills are mastered.
private struct LibraryCategoryCard: View {
    let category: Category
    let drillCount: Int
    let masteredCount: Int

    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.s16) {
            Text(category.letter)
                .font(DS.Typography.num(size: 24))
                .foregroundStyle(DS.Colors.Ink.primary)
                .frame(width: 48, height: 48)
                .background(DS.Colors.Bg.raised)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.md)
                        .stroke(DS.Colors.Line.hairline, lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: DS.Spacing.s4) {
                Text(category.name)
                    .style(.title3)
                    .foregroundStyle(DS.Colors.Ink.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(category.focus)
                    .style(.micro)
                    .foregroundStyle(DS.Colors.Ink.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(masteredCount > 0
                     ? "\(masteredCount) of \(drillCount) mastered"
                     : "\(drillCount) \(drillCount == 1 ? "drill" : "drills")")
                    .style(.microSm)
                    .foregroundStyle(DS.Colors.Ink.quaternary)
                    .padding(.top, DS.Spacing.s4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DS.Colors.Ink.quaternary)
                .padding(.top, DS.Spacing.s16)
        }
        .padding(DS.Spacing.s16)
        .background(DS.Colors.Bg.card)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .stroke(DS.Colors.Line.hairline, lineWidth: 1)
        )
        .contentShape(Rectangle())
    }
}

// MARK: - Category drill list (pushed)

/// Mastery filter applied within a single category.
private enum CategoryMasteryFilter: Hashable {
    case all, mastered, inProgress, notStarted
}

/// Lists every drill inside one category, with a scoped mastery filter. Each
/// row navigates to the full drill detail; an option to back out is provided by
/// the navigation bar.
private struct LibraryCategoryView: View {
    let category: Category
    let discipline: Discipline
    let passesByDrill: [String: Int]
    let masteredIDs: Set<String>

    @Environment(SubscriptionService.self) private var subscription
    @State private var filter: CategoryMasteryFilter = .all

    private struct Row: Identifiable {
        let drill: Drill
        let level: MasteryLevel
        let passes: Int
        let isMastered: Bool
        var id: String { drill.id }
        var isInProgress: Bool { passes > 0 && !isMastered }
        var isNotStarted: Bool { passes == 0 && !isMastered }
    }

    private var allRows: [Row] {
        category.levels
            .sorted(by: { $0.sortIndex < $1.sortIndex })
            .flatMap { level in
                level.drills.sorted(by: { $0.sortIndex < $1.sortIndex }).map { drill in
                    Row(
                        drill: drill,
                        level: level,
                        passes: passesByDrill[drill.id] ?? 0,
                        isMastered: masteredIDs.contains(drill.id)
                    )
                }
            }
    }

    private var rows: [Row] {
        switch filter {
        case .all:        return allRows
        case .mastered:   return allRows.filter { $0.isMastered }
        case .inProgress: return allRows.filter { $0.isInProgress }
        case .notStarted: return allRows.filter { $0.isNotStarted }
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                header
                filterBar
                if rows.isEmpty {
                    Text("No drills match this filter yet.")
                        .style(.body)
                        .foregroundStyle(DS.Colors.Ink.quaternary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.horizontal, DS.Spacing.s20)
                        .padding(.top, DS.Spacing.s48)
                } else {
                    ForEach(rows) { row in
                        // Locked rows still open the drill page (it reads as a
                        // teaser and the page itself gates training), but they
                        // now look locked here instead of looking free.
                        let locked = subscription.isLevelNumberLocked(row.level.number)
                        NavigationLink(value: DrillRoute(
                            discipline: discipline,
                            category: category,
                            level: row.level,
                            drill: row.drill
                        )) {
                            LibraryDrillRow(
                                drill: row.drill,
                                passes: row.passes,
                                isMastered: row.isMastered,
                                isLocked: locked,
                                isLast: row.id == rows.last?.id
                            )
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                }
            }
            .padding(.bottom, 120)
        }
        .background(DS.Colors.Bg.base)
        .scrollIndicators(.hidden)
        .navigationTitle(category.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s8) {
            HStack(spacing: DS.Spacing.s8) {
                DisciplineMark(kind: discipline.mark, size: 14)
                Text("\(discipline.name) · \(category.letter)")
                    .style(.micro)
                    .foregroundStyle(DS.Colors.Ink.tertiary)
            }
            Text(category.focus)
                .style(.body)
                .foregroundStyle(DS.Colors.Ink.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s16)
        .padding(.bottom, DS.Spacing.s8)
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.s8) {
                Chip(label: "All", active: filter == .all) { filter = .all }
                Chip(label: "Mastered", active: filter == .mastered) { filter = .mastered }
                Chip(label: "In Progress", active: filter == .inProgress) { filter = .inProgress }
                Chip(label: "Not Started", active: filter == .notStarted) { filter = .notStarted }
            }
            .padding(.horizontal, DS.Spacing.s20)
        }
        .padding(.top, DS.Spacing.s12)
        .padding(.bottom, DS.Spacing.s4)
    }
}

// MARK: - Library drill row

private struct LibraryDrillRow: View {
    let drill: Drill
    let passes: Int
    let isMastered: Bool
    var isLocked: Bool = false
    let isLast: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: DS.Spacing.s16) {
                VStack(alignment: .leading, spacing: DS.Spacing.s8) {
                    Text(drill.title)
                        .style(.title3)
                        .foregroundStyle(DS.Colors.Ink.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("\(drill.focus) · \(drill.durationSec / 60) min")
                        .style(.micro)
                        .foregroundStyle(DS.Colors.Ink.quaternary)

                    masteryDots
                }

                Spacer(minLength: DS.Spacing.s8)

                trailingIndicator
            }
            .padding(.vertical, DS.Spacing.s12 + 2)

            if !isLast {
                Hairline()
            }
        }
        .padding(.horizontal, DS.Spacing.s20)
        .contentShape(Rectangle())
    }

    private var masteryDots: some View {
        HStack(spacing: DS.Spacing.s4) {
            ForEach(0..<ProgressionRules.masteryPasses, id: \.self) { index in
                Circle()
                    .fill(index < passes ? Color.white : Color.clear)
                    .frame(width: 8, height: 8)
                    .overlay(
                        Circle()
                            .stroke(index < passes ? Color.clear : DS.Colors.Line.subtle, lineWidth: 1)
                    )
            }
        }
    }

    @ViewBuilder
    private var trailingIndicator: some View {
        if isLocked {
            LockBadge()
        } else if isMastered {
            Circle()
                .fill(Color.white)
                .frame(width: 20, height: 20)
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(DS.Colors.Ground.primary)
                )
        } else {
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DS.Colors.Ink.quaternary)
        }
    }
}

#Preview {
    NavigationStack {
        DrillLibraryView()
    }
    .preferredColorScheme(.dark)
    .modelContainer(for: [
        Discipline.self, Category.self, MasteryLevel.self,
        Drill.self, DrillProgress.self, PlayerState.self
    ])
}
