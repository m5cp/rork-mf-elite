//
//  CategoryView.swift
//  MFElite
//
//  Mastery levels inside one skill category.
//

import SwiftUI
import SwiftData

struct CategoryView: View {
    let category: Category
    let discipline: Discipline

    @Environment(\.dismiss) private var dismiss
    @Query private var progress: [DrillProgress]

    private var masteredDrillIDs: Set<String> {
        Set(progress.filter { $0.isMastered }.map { $0.drillID })
    }

    private var viewModel: CategoryViewModel {
        CategoryViewModel(category: category, discipline: discipline, masteredDrillIDs: masteredDrillIDs)
    }

    var body: some View {
        let vm = viewModel
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                breadcrumb
                header
                certificationBanner(vm)
                levelLadder(vm)
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
                Text(discipline.name)
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
            Eyebrow(text: "Category \(category.letter)")

            Text(category.name)
                .style(.hero)
                .foregroundStyle(DS.Colors.Ink.primary)
                .padding(.top, DS.Spacing.s8)

            Text(category.focus)
                .style(.body)
                .foregroundStyle(DS.Colors.Ink.secondary)
                .padding(.top, DS.Spacing.s8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s20)
        .overlay(alignment: .topTrailing) {
            Text(category.letter)
                .font(.system(size: 80, weight: .heavy).italic())
                .foregroundStyle(Color.white.opacity(0.08))
                .padding(.trailing, DS.Spacing.s20)
                .allowsHitTesting(false)
        }
    }

    // MARK: - 3. Certification Banner

    private func certificationBanner(_ vm: CategoryViewModel) -> some View {
        Card {
            HStack(alignment: .top, spacing: DS.Spacing.s16) {
                CertSeal(size: 48, earned: vm.isCategoryCertified)

                VStack(alignment: .leading, spacing: DS.Spacing.s8) {
                    Text(category.certName)
                        .style(.title3)
                        .foregroundStyle(DS.Colors.Ink.primary)

                    Text("\(vm.masteredLevelCount)/\(vm.levels.count) levels mastered")
                        .style(.foot)
                        .foregroundStyle(DS.Colors.Ink.tertiary)

                    ProgressBar(value: vm.levels.isEmpty ? 0 : Double(vm.masteredLevelCount) / Double(vm.levels.count))
                        .padding(.top, DS.Spacing.s4)

                    Text("+\(ProgressionRules.xpCategoryCert) XP and a coach signature")
                        .style(.micro)
                        .foregroundStyle(DS.Colors.Ink.quaternary)
                        .padding(.top, DS.Spacing.s4)
                }
            }
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s24)
    }

    // MARK: - 4. Mastery Level Ladder

    private func levelLadder(_ vm: CategoryViewModel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Eyebrow(text: "Mastery Levels")
                Spacer()
                Eyebrow(text: String(format: "%02d", vm.levels.count))
            }
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.bottom, DS.Spacing.s8)

            ForEach(Array(vm.levels.enumerated()), id: \.element.id) { index, level in
                NavigationLink(value: level) {
                    LevelLadderRow(
                        level: level,
                        state: vm.levelState(level),
                        masteredDrills: vm.masteredDrillCount(level),
                        isFirst: index == 0,
                        isLast: index == vm.levels.count - 1
                    )
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
        .padding(.top, DS.Spacing.s24)
    }
}

// MARK: - LevelLadderRow

private struct LevelLadderRow: View {
    let level: MasteryLevel
    let state: LevelState
    let masteredDrills: Int
    let isFirst: Bool
    let isLast: Bool

    private var drillCount: Int { level.drills.count }
    private var isFree: Bool { level.number <= ProgressionRules.freeLevels }

    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.s16) {
            nodeColumn

            VStack(alignment: .leading, spacing: DS.Spacing.s4) {
                HStack(spacing: DS.Spacing.s8) {
                    Eyebrow(text: "Level \(level.number)")
                    stateChip
                }

                Text(level.name)
                    .style(.title3)
                    .foregroundStyle(DS.Colors.Ink.primary)
                    .padding(.top, DS.Spacing.s4)

                Text("\(drillCount) Drills · +\(ProgressionRules.xpLevelBonus) XP")
                    .style(.micro)
                    .foregroundStyle(DS.Colors.Ink.quaternary)

                if state == .inProgress {
                    ProgressBar(value: drillCount == 0 ? 0 : Double(masteredDrills) / Double(drillCount))
                        .padding(.top, DS.Spacing.s4 + 2)
                }
            }

            Spacer(minLength: DS.Spacing.s8)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DS.Colors.Ink.quaternary)
        }
        .padding(.vertical, DS.Spacing.s16)
        .padding(.horizontal, DS.Spacing.s20)
        .contentShape(Rectangle())
    }

    // MARK: Node + connector

    private var nodeColumn: some View {
        ZStack(alignment: .top) {
            // Connecting line below this node
            if !isLast {
                Rectangle()
                    .fill(DS.Colors.Line.hairline)
                    .frame(width: 1)
                    .frame(maxHeight: .infinity)
                    .padding(.top, 22)
            }
            node
        }
        .frame(width: 44)
    }

    @ViewBuilder
    private var node: some View {
        switch state {
        case .mastered:
            Circle()
                .fill(Color.white)
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(DS.Colors.Ground.primary)
                )
        case .inProgress:
            Circle()
                .stroke(Color.white, lineWidth: 1.5)
                .frame(width: 44, height: 44)
                .overlay(
                    Text("\(level.number)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(DS.Colors.Ink.primary)
                )
        case .upcoming, .locked:
            Circle()
                .stroke(DS.Colors.Line.subtle, lineWidth: 1.5)
                .frame(width: 44, height: 44)
                .overlay(
                    Text("\(level.number)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(DS.Colors.Ink.quaternary)
                )
        }
    }

    // MARK: State chip

    @ViewBuilder
    private var stateChip: some View {
        switch state {
        case .mastered:
            filledChip(text: "Mastered", icon: "checkmark")
        case .inProgress:
            filledChip(text: "In Progress", icon: nil)
        case .upcoming:
            if isFree {
                outlinedChip(text: "Free", icon: nil)
            } else {
                outlinedChip(text: "Members", icon: "lock.fill")
            }
        case .locked:
            outlinedChip(text: "Members", icon: "lock.fill")
        }
    }

    private func filledChip(text: String, icon: String?) -> some View {
        HStack(spacing: DS.Spacing.s4) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(DS.Colors.Ground.primary)
            }
            Text(text)
                .style(.microSm)
                .foregroundStyle(DS.Colors.Ground.primary)
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 8)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.pill))
    }

    private func outlinedChip(text: String, icon: String?) -> some View {
        HStack(spacing: DS.Spacing.s4) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(DS.Colors.Ink.tertiary)
            }
            Text(text)
                .style(.microSm)
                .foregroundStyle(DS.Colors.Ink.tertiary)
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 8)
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.pill)
                .stroke(DS.Colors.Line.subtle, lineWidth: 1)
        )
    }
}
