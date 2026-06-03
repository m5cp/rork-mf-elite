//
//  CurriculumSearchView.swift
//  MFElite
//
//  Find any drill across the entire curriculum.
//

import SwiftUI
import SwiftData

/// Navigation marker that pushes the curriculum search screen.
struct SearchRoute: Hashable {}

struct CurriculumSearchView: View {
    @Query(sort: \Discipline.sortIndex) private var disciplines: [Discipline]
    @Query private var progress: [DrillProgress]
    @Environment(SubscriptionService.self) private var subscription

    @State private var searchText: String = ""
    @State private var selectedDisciplineID: String?

    private var selectedDiscipline: Discipline? {
        disciplines.first { $0.id == selectedDisciplineID }
    }

    private var viewModel: CurriculumSearchViewModel {
        CurriculumSearchViewModel(
            disciplines: disciplines,
            searchText: searchText,
            selectedDiscipline: selectedDiscipline
        )
    }

    var body: some View {
        let vm = viewModel
        let results = vm.hasQuery || selectedDiscipline != nil ? vm.searchDrills() : []

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                filterChips
                content(vm: vm, results: results)
            }
            .padding(.bottom, 120)
        }
        .background(DS.Colors.Bg.base)
        .scrollIndicators(.hidden)
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search drills, skills, categories..."
        )
    }

    // MARK: - Filter chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.s8) {
                Chip(label: "All", active: selectedDisciplineID == nil) {
                    selectedDisciplineID = nil
                }
                ForEach(disciplines) { discipline in
                    DisciplineChip(
                        discipline: discipline,
                        active: selectedDisciplineID == discipline.id
                    ) {
                        selectedDisciplineID = selectedDisciplineID == discipline.id ? nil : discipline.id
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.s20)
        }
        .padding(.top, DS.Spacing.s12)
    }

    // MARK: - Content router

    @ViewBuilder
    private func content(vm: CurriculumSearchViewModel, results: [SearchResult]) -> some View {
        if vm.hasQuery || selectedDiscipline != nil {
            if results.isEmpty {
                emptyState
            } else {
                resultsList(vm: vm, results: results)
            }
        } else {
            browseFallback(vm: vm)
        }
    }

    // MARK: - Results

    private func resultsList(vm: CurriculumSearchViewModel, results: [SearchResult]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if vm.hasQuery {
                Eyebrow(text: "\(results.count) Results · \"\(searchText)\"")
                    .padding(.horizontal, DS.Spacing.s20)
                    .padding(.top, DS.Spacing.s16)
                    .padding(.bottom, DS.Spacing.s4)
            }

            ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                let locked = subscription.isLevelNumberLocked(result.level.number)
                let row = ResultRow(result: result, isLocked: locked, isLast: index == results.count - 1)
                if locked {
                    Button {
                        subscription.presentPaywall()
                    } label: {
                        row
                    }
                    .buttonStyle(PressableButtonStyle())
                } else {
                    NavigationLink(
                        value: DrillRoute(
                            discipline: result.discipline,
                            category: result.category,
                            level: result.level,
                            drill: result.drill
                        )
                    ) {
                        row
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.s12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(DS.Colors.Ink.quaternary)
            Text("No drills found")
                .style(.title2)
                .foregroundStyle(DS.Colors.Ink.tertiary)
            Text("Try a different search term")
                .style(.body)
                .foregroundStyle(DS.Colors.Ink.quaternary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    // MARK: - Browse fallback

    private func browseFallback(vm: CurriculumSearchViewModel) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s12) {
            Eyebrow(text: "Or Browse By Pathway")
                .padding(.top, DS.Spacing.s24)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: DS.Spacing.s12),
                    GridItem(.flexible(), spacing: DS.Spacing.s12)
                ],
                spacing: DS.Spacing.s12
            ) {
                ForEach(disciplines) { discipline in
                    NavigationLink(value: discipline) {
                        BrowseCell(discipline: discipline, drillCount: vm.drillCount(for: discipline))
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
        }
        .padding(.horizontal, DS.Spacing.s20)
    }
}

// MARK: - DisciplineChip

private struct DisciplineChip: View {
    let discipline: Discipline
    let active: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.s4 + 2) {
                DisciplineMark(
                    kind: discipline.mark,
                    size: 14,
                    color: active ? DS.Colors.Ground.primary : DS.Colors.Ink.secondary
                )
                Text(discipline.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(active ? DS.Colors.Ground.primary : DS.Colors.Ink.secondary)
            }
            .padding(.vertical, 7)
            .padding(.horizontal, 14)
            .background(active ? Color.white : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.pill))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.pill)
                    .stroke(active ? Color.white : DS.Colors.Line.subtle, lineWidth: 1)
            )
        }
        .buttonStyle(PressableButtonStyle())
    }
}

// MARK: - ResultRow

private struct ResultRow: View {
    let result: SearchResult
    var isLocked: Bool = false
    let isLast: Bool

    private var breadcrumb: String {
        "\(result.discipline.name) · \(result.category.name) · LV\(result.level.number)".uppercased()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: DS.Spacing.s12) {
                tile

                VStack(alignment: .leading, spacing: DS.Spacing.s4) {
                    Text(result.drill.title)
                        .style(.title3)
                        .foregroundStyle(DS.Colors.Ink.primary)
                    Text(breadcrumb)
                        .style(.micro)
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: isLocked ? "lock.fill" : "chevron.right")
                    .font(.system(size: isLocked ? 14 : 13, weight: .semibold))
                    .foregroundStyle(DS.Colors.Ink.quaternary)
            }
            .padding(.vertical, DS.Spacing.s12 + 2)
            .padding(.horizontal, DS.Spacing.s20)
            .contentShape(Rectangle())

            if !isLast {
                Hairline()
                    .padding(.horizontal, DS.Spacing.s20)
            }
        }
    }

    private var tile: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(DS.Colors.Bg.card)
            .frame(width: 40, height: 40)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(DS.Colors.Line.hairline, lineWidth: 1)
            )
            .overlay {
                DisciplineMark(kind: result.discipline.mark, size: 20)
            }
            .overlay(alignment: .bottomTrailing) {
                if result.discipline.media == "video" {
                    Image(systemName: "play.fill")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.7))
                        .padding(3)
                }
            }
    }
}

// MARK: - BrowseCell

private struct BrowseCell: View {
    let discipline: Discipline
    let drillCount: Int

    var body: some View {
        Card {
            VStack(spacing: DS.Spacing.s8) {
                DisciplineMark(kind: discipline.mark, size: 40)
                    .padding(.bottom, DS.Spacing.s4)
                Text(discipline.name)
                    .style(.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(DS.Colors.Ink.primary)
                Text("\(drillCount) Drills")
                    .style(.micro)
                    .foregroundStyle(DS.Colors.Ink.tertiary)
            }
            .frame(maxWidth: .infinity)
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    NavigationStack {
        CurriculumSearchView()
    }
    .preferredColorScheme(.dark)
    .environment(SubscriptionService.shared)
    .modelContainer(for: [
        Discipline.self, Category.self, MasteryLevel.self,
        Drill.self, DrillProgress.self, PlayerState.self
    ])
}
