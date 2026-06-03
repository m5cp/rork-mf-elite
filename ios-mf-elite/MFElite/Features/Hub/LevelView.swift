//
//  LevelView.swift
//  MFElite
//
//  Drills inside one mastery level.
//

import SwiftUI
import SwiftData

/// Navigation route carrying a level plus its parents for breadcrumb context.
struct LevelRoute: Hashable {
    let discipline: Discipline
    let category: Category
    let level: MasteryLevel
}

struct LevelView: View {
    let level: MasteryLevel
    let category: Category
    let discipline: Discipline

    @Environment(\.dismiss) private var dismiss
    @Environment(SubscriptionService.self) private var subscription
    @Query private var progress: [DrillProgress]

    private var masteredDrillIDs: Set<String> {
        Set(progress.filter { $0.isMastered }.map { $0.drillID })
    }

    private var passesByDrill: [String: Int] {
        Dictionary(progress.map { ($0.drillID, $0.passesLogged) }, uniquingKeysWith: { a, _ in a })
    }

    private var viewModel: LevelViewModel {
        LevelViewModel(
            level: level,
            category: category,
            discipline: discipline,
            passesByDrill: passesByDrill,
            masteredDrillIDs: masteredDrillIDs
        )
    }

    var body: some View {
        let vm = viewModel
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                breadcrumb
                header
                statsStrip(vm)
                drillList(vm)
                footerCaption
            }
            .padding(.bottom, 120)
        }
        .background(DS.Colors.Bg.base)
        .scrollIndicators(.hidden)
        .navigationBarHidden(true)
        .onAppear {
            if subscription.isLevelLocked(level) {
                dismiss()
                subscription.presentPaywall()
            }
        }
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
                Text(category.name)
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
            Eyebrow(text: "Level \(level.number)")

            Text(level.name)
                .style(.hero)
                .foregroundStyle(DS.Colors.Ink.primary)
                .padding(.top, DS.Spacing.s8)

            Text("Log each drill \(ProgressionRules.masteryPasses)× to master the level.")
                .style(.body)
                .foregroundStyle(DS.Colors.Ink.secondary)
                .padding(.top, DS.Spacing.s8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s20)
        .overlay(alignment: .topTrailing) {
            Text("\(level.number)")
                .font(.system(size: 100, weight: .heavy).italic())
                .foregroundStyle(Color.white.opacity(0.08))
                .padding(.trailing, DS.Spacing.s20)
                .allowsHitTesting(false)
        }
    }

    // MARK: - 3. Stats Strip

    private func statsStrip(_ vm: LevelViewModel) -> some View {
        VStack(spacing: 0) {
            Hairline()
            HStack(spacing: 0) {
                statCell(label: "Drills", value: "\(vm.masteredDrillCount)/\(vm.drills.count)", isNum: true)
                statDivider
                statCell(label: "Theme", value: level.theme, isNum: false)
                statDivider
                statCell(label: "Earns", value: "+\(ProgressionRules.xpLevelBonus) XP", isNum: true)
            }
            Hairline()
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s20)
    }

    private func statCell(label: String, value: String, isNum: Bool) -> some View {
        VStack(spacing: DS.Spacing.s4) {
            Eyebrow(text: label)
            if isNum {
                Text(value)
                    .font(DS.Typography.num(size: 20))
                    .tracking(-1)
                    .foregroundStyle(DS.Colors.Ink.primary)
            } else {
                Text(value)
                    .style(.foot)
                    .foregroundStyle(DS.Colors.Ink.primary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.s16 - 2)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(DS.Colors.Line.hairline)
            .frame(width: 1, height: 40)
    }

    // MARK: - 4. Drill List

    private func drillList(_ vm: LevelViewModel) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(vm.drills.enumerated()), id: \.element.id) { index, drill in
                NavigationLink(value: drillRoute(drill)) {
                    DrillRow(
                        drill: drill,
                        passesLogged: vm.passesLogged(for: drill),
                        isMastered: vm.isMastered(drill),
                        isCurrent: vm.currentDrill?.id == drill.id,
                        isVideo: discipline.media == "video",
                        isLast: index == vm.drills.count - 1
                    )
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
        .padding(.top, DS.Spacing.s24)
    }

    private func drillRoute(_ drill: Drill) -> DrillRoute {
        DrillRoute(discipline: discipline, category: category, level: level, drill: drill)
    }

    // MARK: - 5. Footer caption

    private var footerCaption: some View {
        Text("Drills synced from Supabase · Coach can add more any time")
            .style(.microSm)
            .foregroundStyle(DS.Colors.Ink.quaternary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.top, DS.Spacing.s16)
    }
}

// MARK: - DrillRow

private struct DrillRow: View {
    let drill: Drill
    let passesLogged: Int
    let isMastered: Bool
    let isCurrent: Bool
    let isVideo: Bool
    let isLast: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: DS.Spacing.s16) {
                thumbnail

                VStack(alignment: .leading, spacing: DS.Spacing.s8) {
                    Text(drill.title)
                        .style(.title3)
                        .foregroundStyle(DS.Colors.Ink.primary)

                    Text(drill.focus)
                        .style(.micro)
                        .foregroundStyle(DS.Colors.Ink.quaternary)

                    HStack(spacing: DS.Spacing.s8) {
                        masteryDots
                        Text("\(passesLogged)/\(ProgressionRules.masteryPasses) Logged")
                            .style(.microSm)
                            .foregroundStyle(DS.Colors.Ink.tertiary)
                    }
                }

                Spacer(minLength: DS.Spacing.s8)

                trailingIndicator
            }
            .padding(.vertical, DS.Spacing.s12 + 2)
            .padding(.horizontal, isCurrent ? DS.Spacing.s12 : 0)
            .background(currentBackground)

            if !isLast {
                Hairline()
                    .padding(.horizontal, isCurrent ? DS.Spacing.s12 : 0)
            }
        }
        .padding(.horizontal, DS.Spacing.s20)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var currentBackground: some View {
        if isCurrent {
            RoundedRectangle(cornerRadius: 12)
                .fill(DS.Colors.Bg.elevated)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(DS.Colors.Line.hairline, lineWidth: 1)
                )
        }
    }

    private var thumbnail: some View {
        PhotoPlaceholder(height: 56, label: "")
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay {
                if isVideo {
                    Image(systemName: "play.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.60))
                }
            }
    }

    private var masteryDots: some View {
        HStack(spacing: DS.Spacing.s4) {
            ForEach(0..<ProgressionRules.masteryPasses, id: \.self) { index in
                Circle()
                    .fill(index < passesLogged ? Color.white : Color.clear)
                    .frame(width: 8, height: 8)
                    .overlay(
                        Circle()
                            .stroke(index < passesLogged ? Color.clear : DS.Colors.Line.subtle, lineWidth: 1)
                    )
            }
        }
    }

    @ViewBuilder
    private var trailingIndicator: some View {
        if isMastered {
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
