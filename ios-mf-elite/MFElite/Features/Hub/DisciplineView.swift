//
//  DisciplineView.swift
//  MFElite
//
//  Categories inside one development pathway.
//

import SwiftUI
import SwiftData

/// Navigation route carrying a category plus its parent discipline for breadcrumb context.
struct CategoryRoute: Hashable {
    let discipline: Discipline
    let category: Category
}

struct DisciplineView: View {
    let discipline: Discipline

    @Environment(\.dismiss) private var dismiss
    @Query private var progress: [DrillProgress]

    private var masteredDrillIDs: Set<String> {
        Set(progress.filter { $0.isMastered }.map { $0.drillID })
    }

    /// Game IQ lessons live on the Tactical pathway only.
    private var isTactical: Bool {
        discipline.id == "d-tact" || discipline.name == "Tactical"
    }

    private var viewModel: DisciplineViewModel {
        DisciplineViewModel(discipline: discipline, masteredDrillIDs: masteredDrillIDs)
    }

    var body: some View {
        let vm = viewModel
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                breadcrumb
                header
                if isTactical {
                    GameIQSection()
                }
                diplomaCard(vm)
                categoriesList(vm)
            }
            .padding(.bottom, 120)
        }
        .background(DS.Colors.Bg.base)
        .scrollIndicators(.hidden)
        .navigationBarHidden(true)
    }

    // MARK: - 1. Breadcrumb

    private var breadcrumb: some View {
        Button {
            dismiss()
        } label: {
            HStack(spacing: DS.Spacing.s8) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DS.Colors.Ink.tertiary)
                Text("MF Hub")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DS.Colors.Ink.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s16)
    }

    // MARK: - 2. Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let art = MFArtwork.discipline(id: discipline.id, name: discipline.name) {
                // Photograph only — the pathway name and tagline are set in
                // type directly below, and repeating them in the image would
                // be saying the same thing twice.
                ArtworkBanner(name: art, height: MFArtwork.heroHeight)
                    .padding(.bottom, DS.Spacing.s20)
            }

            HStack(spacing: DS.Spacing.s12) {
                DisciplineMark(kind: discipline.mark, size: 32)
                Eyebrow(text: "Pathway \(discipline.number)")
            }

            Text(discipline.name)
                .style(.hero)
                .foregroundStyle(DS.Colors.Ink.primary)
                .padding(.top, DS.Spacing.s8)

            Text(discipline.blurb)
                .style(.body)
                .foregroundStyle(DS.Colors.Ink.secondary)
                .padding(.top, DS.Spacing.s12)
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s20)
    }

    // MARK: - 3. Diploma Progress Card

    private func diplomaCard(_ vm: DisciplineViewModel) -> some View {
        Card(raised: true) {
            VStack(alignment: .leading, spacing: DS.Spacing.s12) {
                HStack {
                    Eyebrow(text: "Discipline Diploma")
                    Spacer()
                    if vm.allCertified {
                        HStack(spacing: DS.Spacing.s4) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                            Eyebrow(text: "Diploma Earned", color: DS.Colors.Ink.primary)
                        }
                        .foregroundStyle(DS.Colors.Ink.primary)
                    }
                }

                ProgressBar(value: vm.totalCategories == 0 ? 0 : Double(vm.certifiedCount) / Double(vm.totalCategories))

                Text("\(vm.certifiedCount)/\(vm.totalCategories) categories certified · +\(ProgressionRules.xpDisciplineDiploma) XP")
                    .style(.foot)
                    .foregroundStyle(DS.Colors.Ink.tertiary)
            }
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s24)
    }

    // MARK: - 4. Categories List

    private func categoriesList(_ vm: DisciplineViewModel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Eyebrow(text: "Categories")
                Spacer()
                Eyebrow(text: String(format: "%02d", vm.totalCategories))
            }
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.bottom, DS.Spacing.s4 + 2)

            ForEach(Array(vm.categories.enumerated()), id: \.element.id) { index, category in
                NavigationLink(value: CategoryRoute(discipline: discipline, category: category)) {
                    CategoryRow(
                        category: category,
                        certified: vm.isCertified(category),
                        masteredLevels: vm.masteredLevelCount(category),
                        drillCount: vm.drillCount(category),
                        currentLevel: vm.currentLevelNumber(category),
                        percent: vm.completionPercent(category),
                        isLast: index == vm.categories.count - 1
                    )
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
        .padding(.top, DS.Spacing.s24)
    }
}

// MARK: - CategoryRow

private struct CategoryRow: View {
    let category: Category
    let certified: Bool
    let masteredLevels: Int
    let drillCount: Int
    let currentLevel: Int?
    let percent: Double
    let isLast: Bool

    private var levelCount: Int { category.levels.count }

    private var statusText: String {
        if certified { return "Mastered" }
        if masteredLevels == 0 && percent == 0 { return "Not Started" }
        return "\(Int((percent * 100).rounded()))%"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: DS.Spacing.s16) {
                letterTile

                VStack(alignment: .leading, spacing: DS.Spacing.s8) {
                    HStack(spacing: DS.Spacing.s8) {
                        Text(category.name)
                            .style(.title3)
                            .foregroundStyle(DS.Colors.Ink.primary)
                        if certified {
                            certifiedChip
                        }
                    }

                    Text(category.focus)
                        .style(.foot)
                        .foregroundStyle(DS.Colors.Ink.tertiary)

                    Text("\(levelCount) Levels · \(drillCount) Drills")
                        .style(.micro)
                        .foregroundStyle(DS.Colors.Ink.quaternary)

                    LevelPips(
                        total: levelCount,
                        done: masteredLevels - 1,
                        current: (currentLevel ?? 0) - 1
                    )
                    .padding(.top, DS.Spacing.s4)

                    HStack {
                        Spacer()
                        Text(statusText)
                            .style(.micro)
                            .foregroundStyle(DS.Colors.Ink.tertiary)
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DS.Colors.Ink.quaternary)
                    .padding(.top, DS.Spacing.s4)
            }
            .padding(.vertical, 18)

            if !isLast {
                Hairline()
            }
        }
        .padding(.horizontal, DS.Spacing.s20)
        .contentShape(Rectangle())
    }

    private var letterTile: some View {
        Text(category.letter)
            .style(.title3)
            .fontWeight(.bold)
            .foregroundStyle(certified ? DS.Colors.Ground.primary : DS.Colors.Ink.primary)
            .frame(width: 40, height: 40)
            .background(certified ? Color.white : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(certified ? Color.clear : DS.Colors.Line.subtle, lineWidth: 1)
            )
    }

    private var certifiedChip: some View {
        Text("Certified")
            .style(.micro)
            .foregroundStyle(DS.Colors.Ground.primary)
            .padding(.vertical, 4)
            .padding(.horizontal, 10)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.pill))
    }
}

// MARK: - ProgressBar

/// A thin white-fill progress bar over a subtle track.
struct ProgressBar: View {
    let value: Double // 0...1

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(DS.Colors.Line.subtle)
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white)
                    .frame(width: max(0, min(1, value)) * geo.size.width)
            }
        }
        .frame(height: 4)
    }
}
