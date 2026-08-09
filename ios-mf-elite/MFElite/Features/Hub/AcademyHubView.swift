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

    private var kitNumber: String { PlayerProfileStore.shared.kitNumber }

    private var currentSeasonLabel: String {
        let year = Calendar.current.component(.year, from: Date())
        let shortYear = year % 100
        let nextShort = (year + 1) % 100
        return "\(shortYear) — \(nextShort)"
    }

    private var masteredDrillIDs: Set<String> {
        Set(progress.filter { $0.isMastered }.map { $0.drillID })
    }

    private var viewModel: AcademyHubViewModel {
        AcademyHubViewModel(
            disciplines: disciplines,
            xp: players.first?.xp ?? 0,
            rankXP: players.first?.rankXP ?? 0,
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
                    CoachsChoiceSection()
                        .padding(.top, DS.Spacing.s24)
                    trainingSection
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
            .navigationDestination(for: DrillLibraryRoute.self) { _ in
                DrillLibraryView()
            }
            .navigationDestination(for: RoutinesRoute.self) { _ in
                RoutinesView()
            }
            .navigationDestination(for: MyWorkoutsRoute.self) { _ in
                MyWorkoutsView()
            }
            .navigationDestination(for: FavoritesRoute.self) { _ in
                FavoritesView()
            }
            .navigationDestination(for: RankDetailRoute.self) { _ in
                RankDetailView()
            }
        }
    }

    // MARK: - 1. Masthead

    private var masthead: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: DS.Spacing.s12) {
                Eyebrow(text: "Season \(currentSeasonLabel)")
                Spacer()
                Eyebrow(text: "MF · Academy")
                NavigationLink(value: SearchRoute()) {
                    searchIcon
                }
                .buttonStyle(PressableButtonStyle())
            }

            SlashRule()
                .padding(.top, DS.Spacing.s12 + 2)

            Text("MF\nHub")
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
        return NavigationLink(value: RankDetailRoute()) {
            HStack(spacing: DS.Spacing.s16) {
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
        }
        .buttonStyle(PressableButtonStyle())
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s20)
    }

    // MARK: - 3. Development Pathways

    private func pathwaysSection(_ vm: AcademyHubViewModel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Eyebrow(text: "Development Pathways")
                Spacer()
                Eyebrow(text: String(format: "%02d", vm.disciplines.count))
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

    // MARK: - Train (Routines, Workouts, Library)

    private var trainingSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: "Train")
                .padding(.horizontal, DS.Spacing.s20)
                .padding(.bottom, DS.Spacing.s4 + 2)

            NavigationLink(value: RoutinesRoute()) {
                MoreRow(icon: "figure.run", label: "Routines", detail: "Ready-made training sessions", isLast: false)
            }
            .buttonStyle(PressableButtonStyle())

            NavigationLink(value: MyWorkoutsRoute()) {
                MoreRow(icon: "hammer", label: "My Workouts", detail: "Build and manage your own sessions", isLast: false)
            }
            .buttonStyle(PressableButtonStyle())

            NavigationLink(value: FavoritesRoute()) {
                MoreRow(icon: "heart", label: "Favorites", detail: "Your saved drills, routines & workouts", isLast: false)
            }
            .buttonStyle(PressableButtonStyle())

            NavigationLink(value: DrillLibraryRoute()) {
                MoreRow(icon: "list.bullet", label: "Drill Library", detail: "Every drill, by category", isLast: true)
            }
            .buttonStyle(PressableButtonStyle())
        }
        .padding(.top, DS.Spacing.s24)
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

            Text("Train through every drill. Master every level.")
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
                if let art = MFArtwork.disciplineThumb(id: discipline.id, name: discipline.name) {
                    ArtworkThumb(name: art)
                        .padding(.top, 2)
                }

                VStack(alignment: .leading, spacing: DS.Spacing.s8) {
                    HStack(spacing: DS.Spacing.s8) {
                        DisciplineMark(kind: discipline.mark, size: 22)
                        Text(discipline.name)
                            .style(.title2)
                            .foregroundStyle(DS.Colors.Ink.primary)
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

// MARK: - MoreRow

struct MoreRow: View {
    let icon: String
    let label: String
    let detail: String
    let isLast: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: DS.Spacing.s16) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .metallicSymbol(.gold)
                    .frame(width: 40, height: 40)
                    .background(DS.Colors.Bg.raised)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: DS.Spacing.s4) {
                    Text(label)
                        .style(.title3)
                        .foregroundStyle(DS.Colors.Ink.primary)
                    Text(detail)
                        .style(.micro)
                        .foregroundStyle(DS.Colors.Ink.quaternary)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DS.Colors.Ink.quaternary)
            }
            .padding(.vertical, DS.Spacing.s16)

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
