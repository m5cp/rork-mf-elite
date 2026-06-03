//
//  AcademyHubView.swift
//  MFElite
//
//  Tab 2 — the entry point to the entire curriculum.
//

import SwiftUI
import SwiftData

struct AcademyHubView: View {
    @Query(sort: \Discipline.sortIndex) private var disciplines: [Discipline]
    @Query private var players: [PlayerState]
    @Query private var progress: [DrillProgress]

    private let kitNumber = "09"

    private var masteredDrillIDs: Set<String> {
        Set(progress.filter { $0.isMastered }.map { $0.drillID })
    }

    private var viewModel: AcademyHubViewModel {
        AcademyHubViewModel(
            disciplines: disciplines,
            xp: players.first?.xp ?? 0,
            streak: players.first?.streak ?? 0,
            masteredDrillIDs: masteredDrillIDs
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    masthead
                    standingStrip(viewModel)
                    pathwaysSection(viewModel)
                    scalabilityFooter(viewModel)
                }
                .padding(.bottom, 120)
            }
            .background(DS.Colors.Bg.base)
            .scrollIndicators(.hidden)
            .navigationBarHidden(true)
            .navigationDestination(for: Discipline.self) { discipline in
                DisciplineView(discipline: discipline)
            }
            .navigationDestination(for: CategoryRoute.self) { route in
                CategoryView(category: route.category, discipline: route.discipline)
            }
            .navigationDestination(for: LevelRoute.self) { route in
                LevelView(level: route.level, category: route.category, discipline: route.discipline)
            }
            .navigationDestination(for: DrillRoute.self) { route in
                DrillDetailView(drill: route.drill, level: route.level, category: route.category, discipline: route.discipline)
            }
            .navigationDestination(for: SearchRoute.self) { _ in
                CurriculumSearchView()
            }
        }
    }

    // MARK: - 1. Masthead

    private var masthead: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: DS.Spacing.s12) {
                Eyebrow(text: "Season 25 — 26")
                Spacer()
                Eyebrow(text: "MF · Academy")
                NavigationLink(value: SearchRoute()) {
                    searchIcon
                }
                .buttonStyle(PressableButtonStyle())
            }

            SlashRule()
                .padding(.top, DS.Spacing.s12 + 2)

            Text("The\nCurriculum")
                .style(.hero)
                .foregroundStyle(DS.Colors.Ink.primary)
                .lineSpacing(-6)
                .padding(.top, DS.Spacing.s20)

            Text("Four development pathways. Train through mastery levels, earn certifications, and rise through the academy — month after month.")
                .style(.body)
                .foregroundStyle(DS.Colors.Ink.secondary)
                .frame(maxWidth: 330, alignment: .leading)
                .padding(.top, DS.Spacing.s12)

            SlashRule()
                .padding(.top, DS.Spacing.s20)
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s64)
    }

    private var searchIcon: some View {
        Image(systemName: "magnifyingglass")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(DS.Colors.Ink.primary)
            .frame(width: 36, height: 36)
            .background(DS.Colors.Bg.raised)
            .clipShape(Circle())
            .overlay(
                Circle().stroke(DS.Colors.Line.hairline, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.30), radius: 2, y: 1)
    }

    // MARK: - 2. Academy Standing Strip

    private func standingStrip(_ vm: AcademyHubViewModel) -> some View {
        let rank = vm.currentRank
        return HStack(spacing: DS.Spacing.s16) {
            Monogram(size: 56, initials: rank.numeral, kit: kitNumber)

            VStack(alignment: .leading, spacing: DS.Spacing.s4) {
                Eyebrow(text: "Academy Rank · \(rank.numeral)")
                Text(rank.title)
                    .style(.title3)
                    .foregroundStyle(DS.Colors.Ink.primary)
                HStack(spacing: DS.Spacing.s8) {
                    Text("\(vm.xp.formatted()) XP")
                        .style(.micro)
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                    Sep()
                    Text("\(vm.streak)-Day Streak")
                        .style(.micro)
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                }
            }

            Spacer(minLength: DS.Spacing.s8)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DS.Colors.Ink.quaternary)
        }
        .padding(.vertical, DS.Spacing.s16)
        .padding(.horizontal, 18)
        .background(DS.Colors.Bg.elevated)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(DS.Colors.Line.hairline, lineWidth: 1)
        )
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s20)
    }

    // MARK: - 3. Development Pathways

    private func pathwaysSection(_ vm: AcademyHubViewModel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Eyebrow(text: "Development Pathways")
                Spacer()
                Eyebrow(text: "04")
            }
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.bottom, DS.Spacing.s4 + 2)

            ForEach(Array(vm.disciplines.enumerated()), id: \.element.id) { index, discipline in
                NavigationLink(value: discipline) {
                    PathwayRow(
                        discipline: discipline,
                        drillCount: vm.drillCount(for: discipline),
                        certified: vm.certifiedCount(for: discipline),
                        isLast: index == vm.disciplines.count - 1
                    )
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
        .padding(.top, DS.Spacing.s32)
    }

    // MARK: - 5. Scalability Footer

    private func scalabilityFooter(_ vm: AcademyHubViewModel) -> some View {
        VStack(spacing: DS.Spacing.s16) {
            VStack(spacing: 0) {
                Hairline()
                HStack(spacing: 0) {
                    footerCell("04", "Pathways")
                    footerDivider
                    footerCell("\(vm.totalCategories)", "Categories")
                    footerDivider
                    footerCell("\(vm.totalLevels)", "Levels")
                    footerDivider
                    footerCell("\(vm.totalDrills)", "Drills")
                }
                Hairline()
            }

            Text("New drills added by your coach every week.")
                .style(.foot)
                .foregroundStyle(DS.Colors.Ink.tertiary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s24 + 2)
    }

    private func footerCell(_ value: String, _ label: String) -> some View {
        VStack(spacing: DS.Spacing.s4) {
            Text(value)
                .font(DS.Typography.num(size: 22))
                .tracking(-1)
                .foregroundStyle(DS.Colors.Ink.primary)
            Text(label)
                .style(.microSm)
                .foregroundStyle(DS.Colors.Ink.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
    }

    private var footerDivider: some View {
        Rectangle()
            .fill(DS.Colors.Line.hairline)
            .frame(width: 1, height: 36)
    }
}

// MARK: - PathwayRow

private struct PathwayRow: View {
    let discipline: Discipline
    let drillCount: Int
    let certified: Int
    let isLast: Bool

    private var categoryCount: Int { discipline.categories.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: DS.Spacing.s16) {
                Text(discipline.number)
                    .font(.system(size: 36, weight: .heavy).italic())
                    .foregroundStyle(Color.white.opacity(0.72))
                    .frame(width: 44, alignment: .leading)

                VStack(alignment: .leading, spacing: DS.Spacing.s8) {
                    HStack(spacing: DS.Spacing.s8) {
                        DisciplineMark(kind: discipline.mark, size: 22)
                        Text(discipline.name)
                            .style(.title2)
                            .foregroundStyle(DS.Colors.Ink.primary)
                        if discipline.media == "video" {
                            Text("FILM")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .tracking(1.2)
                                .foregroundStyle(DS.Colors.Ink.tertiary)
                                .padding(.vertical, 3)
                                .padding(.horizontal, 7)
                                .overlay(
                                    RoundedRectangle(cornerRadius: DS.Radius.pill)
                                        .stroke(DS.Colors.Line.subtle, lineWidth: 1)
                                )
                        }
                    }

                    Text(discipline.tagline)
                        .style(.foot)
                        .foregroundStyle(DS.Colors.Ink.tertiary)

                    Text("\(categoryCount) Categories · \(drillCount) Drills")
                        .style(.micro)
                        .foregroundStyle(DS.Colors.Ink.quaternary)

                    LevelPips(total: categoryCount, done: certified - 1, current: certified)
                        .padding(.top, DS.Spacing.s4)

                    HStack {
                        Spacer()
                        Text("\(certified) / \(categoryCount) Cert")
                            .style(.micro)
                            .foregroundStyle(DS.Colors.Ink.tertiary)
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DS.Colors.Ink.quaternary)
                    .padding(.top, DS.Spacing.s4)
            }
            .padding(.vertical, DS.Spacing.s20)

            if !isLast {
                Hairline()
            }
        }
        .padding(.horizontal, DS.Spacing.s20)
        .contentShape(Rectangle())
    }
}

#Preview {
    AcademyHubView()
        .preferredColorScheme(.dark)
        .modelContainer(for: [
            Discipline.self, Category.self, MasteryLevel.self,
            Drill.self, DrillProgress.self, PlayerState.self
        ])
}
