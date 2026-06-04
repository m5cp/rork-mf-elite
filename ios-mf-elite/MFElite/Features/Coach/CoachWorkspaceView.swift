//
//  CoachWorkspaceView.swift
//  MFElite
//
//  The coach admin hub — curriculum manager and squad tools.
//

import SwiftUI
import SwiftData

private struct CoachRosterRoute: Hashable {}
private struct CoachBuildRoute: Hashable {}

/// Sheets the workspace can present for content management.
private enum WorkspaceSheet: Identifiable {
    case addDrill(levelID: String, sortIndex: Int)
    case editDrill(Drill, levelID: String)
    case quotes
    case announcements
    case parentReport
    case progressionRules
    case manageCoaches

    var id: String {
        switch self {
        case .addDrill(let levelID, _): return "add-\(levelID)"
        case .editDrill(let drill, _): return "edit-\(drill.id)"
        case .quotes: return "quotes"
        case .announcements: return "announcements"
        case .parentReport: return "parentReport"
        case .progressionRules: return "rules"
        case .manageCoaches: return "coaches"
        }
    }
}

struct CoachWorkspaceView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Discipline.sortIndex) private var disciplines: [Discipline]

    @State private var awardCerts = true
    @State private var isPublishing = false
    @State private var activeSheet: WorkspaceSheet?
    @State private var toast: String?
    @State private var auth = AuthService.shared

    private var viewModel: CoachWorkspaceViewModel {
        CoachWorkspaceViewModel(disciplines: disciplines)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                adminBar
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        header
                        liveCounts(viewModel)
                        curriculumTree(viewModel)
                        toolsSection
                        if auth.isHeadCoach {
                            manageCoachesSection
                        }
                        progressionRules
                        certificationsSection
                        dashboardContent
                        bottomCTAs
                    }
                    .padding(.bottom, 120)
                }
                .scrollIndicators(.hidden)
            }
            .background(DS.Colors.Bg.base)
            .navigationBarHidden(true)
            .overlay(alignment: .bottom) { toastView }
            .navigationDestination(for: CoachRosterRoute.self) { _ in
                CoachRosterView()
            }
            .navigationDestination(for: CoachBuildRoute.self) { _ in
                CoachBuildSessionView()
            }
            .sheet(item: $activeSheet) { sheet in
                sheetContent(sheet)
            }
        }
    }

    @ViewBuilder
    private func sheetContent(_ sheet: WorkspaceSheet) -> some View {
        switch sheet {
        case .addDrill(let levelID, let sortIndex):
            CoachDrillEditorView(levelID: levelID, existing: nil, defaultSortIndex: sortIndex) {
                showToast("Drill added")
                resync()
            }
        case .editDrill(let drill, let levelID):
            CoachDrillEditorView(levelID: levelID, existing: drill) {
                showToast("Drill updated")
                resync()
            }
        case .quotes:
            CoachQuotesView()
        case .announcements:
            CoachAnnouncementsView()
        case .parentReport:
            CoachParentReportView()
        case .progressionRules:
            CoachProgressionRulesView()
        case .manageCoaches:
            CoachManageCoachesView()
        }
    }

    // MARK: - Toast

    @ViewBuilder
    private var toastView: some View {
        if let toast {
            Text(toast)
                .style(.foot)
                .foregroundStyle(DS.Colors.Ground.primary)
                .padding(.vertical, DS.Spacing.s12)
                .padding(.horizontal, DS.Spacing.s20)
                .background(Color.white)
                .clipShape(Capsule())
                .pillLightElevation()
                .padding(.bottom, DS.Spacing.s32)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func showToast(_ message: String) {
        withAnimation(DS.Motion.standardSpring) { toast = message }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation(DS.Motion.standardSpring) { toast = nil }
        }
    }

    private func resync() {
        Task {
            await CurriculumSyncService.shared.syncCurriculum(context: modelContext, force: true)
        }
    }

    // MARK: - Admin Bar

    private var adminBar: some View {
        HStack {
            Eyebrow(text: "Admin · Coach Access", color: DS.Colors.Ground.primary)
            Spacer()
            Button {
                dismiss()
            } label: {
                Text("Exit")
                    .style(.foot)
                    .foregroundStyle(DS.Colors.Ground.primary)
            }
            .buttonStyle(PressableButtonStyle())
        }
        .padding(.horizontal, DS.Spacing.s20)
        .frame(height: 44)
        .frame(maxWidth: .infinity)
        .background(Color.white)
    }

    // MARK: - Header

    private var header: some View {
        Text("Curriculum")
            .style(.hero)
            .foregroundStyle(DS.Colors.Ink.primary)
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.top, DS.Spacing.s20)
    }

    // MARK: - Live Counts

    private func liveCounts(_ vm: CoachWorkspaceViewModel) -> some View {
        Card {
            HStack(spacing: 0) {
                countCell(String(format: "%02d", vm.pathwayCount), "Pathways")
                countDivider
                countCell("\(vm.totalCategories)", "Categories")
                countDivider
                countCell("\(vm.totalLevels)", "Levels")
                countDivider
                countCell("\(vm.totalDrills)", "Drills")
            }
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s20)
    }

    private func countCell(_ value: String, _ label: String) -> some View {
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
    }

    private var countDivider: some View {
        Rectangle()
            .fill(DS.Colors.Line.hairline)
            .frame(width: 1, height: 36)
    }

    // MARK: - Curriculum Tree

    private func curriculumTree(_ vm: CoachWorkspaceViewModel) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s12) {
            Eyebrow(text: "Content Tree")

            VStack(spacing: 0) {
                ForEach(vm.disciplines, id: \.id) { discipline in
                    DisciplineTreeRow(
                        discipline: discipline,
                        vm: vm,
                        onAddDrill: { levelID, sortIndex in
                            activeSheet = .addDrill(levelID: levelID, sortIndex: sortIndex)
                        },
                        onEditDrill: { drill, levelID in
                            activeSheet = .editDrill(drill, levelID: levelID)
                        }
                    )
                }
            }
            .background(DS.Colors.Bg.elevated)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .stroke(DS.Colors.Line.hairline, lineWidth: 1)
            )

            Eyebrow(text: "Tap a level to add a drill · tap a drill to edit", color: DS.Colors.Ink.quaternary)
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s32)
    }

    // MARK: - Tools (roster + builder)

    private var toolsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s12) {
            Eyebrow(text: "Squad Tools")
            VStack(spacing: 0) {
                navRow(icon: "person.3", label: "Squad roster", route: CoachRosterRoute())
                Hairline()
                navRow(icon: "square.and.pencil", label: "Build session", route: CoachBuildRoute())
                Hairline()
                buttonRow(icon: "doc.text", label: "Player report") { activeSheet = .parentReport }
            }
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s32)
    }

    private func buttonRow(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.s16) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DS.Colors.Ink.primary)
                    .frame(width: 36, height: 36)
                    .background(DS.Colors.Bg.raised)
                    .clipShape(Circle())
                Text(label)
                    .style(.title3)
                    .foregroundStyle(DS.Colors.Ink.primary)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DS.Colors.Ink.quaternary)
            }
            .padding(.vertical, DS.Spacing.s12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
    }

    private func navRow<R: Hashable>(icon: String, label: String, route: R) -> some View {
        NavigationLink(value: route) {
            HStack(spacing: DS.Spacing.s16) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DS.Colors.Ink.primary)
                    .frame(width: 36, height: 36)
                    .background(DS.Colors.Bg.raised)
                    .clipShape(Circle())
                Text(label)
                    .style(.title3)
                    .foregroundStyle(DS.Colors.Ink.primary)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DS.Colors.Ink.quaternary)
            }
            .padding(.vertical, DS.Spacing.s12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - Manage Coaches (head coach only)

    private var manageCoachesSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s12) {
            Eyebrow(text: "Team")
            VStack(spacing: 0) {
                buttonRow(icon: "person.badge.shield.checkmark", label: "Manage coaches") {
                    activeSheet = .manageCoaches
                }
            }
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s32)
    }

    // MARK: - Progression Rules

    private var progressionRules: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s12) {
            HStack {
                Eyebrow(text: "Progression Rules")
                Spacer()
                Button {
                    activeSheet = .progressionRules
                } label: {
                    Text("Edit")
                        .style(.foot)
                        .foregroundStyle(DS.Colors.Ink.primary)
                }
                .buttonStyle(PressableButtonStyle())
            }
            VStack(spacing: DS.Spacing.s8) {
                ruleField("XP per drill", ProgressionRules.xpPerDrill)
                ruleField("Level bonus", ProgressionRules.xpLevelBonus)
                ruleField("Certification bonus", ProgressionRules.xpCategoryCert)
                ruleField("Mastery passes", ProgressionRules.masteryPasses)
                ruleField("Free tier levels", ProgressionRules.freeLevels)
            }
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s32)
    }

    private func ruleField(_ label: String, _ value: Int) -> some View {
        HStack {
            Text(label)
                .style(.callout)
                .foregroundStyle(DS.Colors.Ink.primary)
            Spacer()
            Text("\(value)")
                .font(DS.Typography.num(size: 18))
                .foregroundStyle(DS.Colors.Ink.primary)
        }
        .padding(.vertical, DS.Spacing.s12)
        .padding(.horizontal, DS.Spacing.s16)
        .background(DS.Colors.Bg.elevated)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
    }

    // MARK: - Certifications

    private var certificationsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s8) {
            Eyebrow(text: "Certifications")
            Toggle(isOn: $awardCerts) {
                Text("Award certifications")
                    .style(.title3)
                    .foregroundStyle(DS.Colors.Ink.primary)
            }
            .tint(.white)
            Text("When enabled, players earn certifications for mastering all levels in a category.")
                .style(.foot)
                .foregroundStyle(DS.Colors.Ink.tertiary)
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s32)
    }

    // MARK: - Dashboard Content

    private var dashboardContent: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s12) {
            Eyebrow(text: "Dashboard Content")
            VStack(spacing: 0) {
                contentRow(label: "Daily motivation quotes") { activeSheet = .quotes }
                Hairline()
                contentRow(label: "Announcements") { activeSheet = .announcements }
            }
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s32)
    }

    private func contentRow(label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.s12) {
                Text(label)
                    .style(.callout)
                    .foregroundStyle(DS.Colors.Ink.primary)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DS.Colors.Ink.quaternary)
            }
            .padding(.vertical, DS.Spacing.s12 + 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - Bottom CTAs

    private var bottomCTAs: some View {
        VStack(spacing: DS.Spacing.s12) {
            PrimaryButton(label: "Preview as player") {
                dismiss()
            }
            SecondaryButton(label: isPublishing ? "Publishing…" : "Publish changes") {
                guard !isPublishing else { return }
                isPublishing = true
                Task {
                    await CoachContentService.shared.publishChanges()
                    await CurriculumSyncService.shared.syncCurriculum(context: modelContext, force: true)
                    await CurriculumSyncService.shared.syncProgressionRules()
                    isPublishing = false
                    showToast("Changes published")
                }
            }
            Text("Stored in Supabase · RLS-secured · No App Store update needed")
                .style(.microSm)
                .foregroundStyle(DS.Colors.Ink.quaternary)
                .multilineTextAlignment(.center)
                .padding(.top, DS.Spacing.s4)
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s32)
    }
}

// MARK: - Discipline Tree Row

private struct DisciplineTreeRow: View {
    let discipline: Discipline
    let vm: CoachWorkspaceViewModel
    let onAddDrill: (_ levelID: String, _ sortIndex: Int) -> Void
    let onEditDrill: (_ drill: Drill, _ levelID: String) -> Void

    @State private var expanded = false

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(DS.Motion.standardSpring) { expanded.toggle() }
            } label: {
                HStack(spacing: DS.Spacing.s12) {
                    DisciplineMark(kind: discipline.mark, size: 18)
                    Text(discipline.name)
                        .style(.title3)
                        .foregroundStyle(DS.Colors.Ink.primary)
                    Spacer(minLength: 0)
                    Text("\(vm.drillCount(for: discipline)) Drills")
                        .style(.micro)
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(DS.Colors.Ink.quaternary)
                        .rotationEffect(.degrees(expanded ? 0 : -90))
                }
                .padding(.vertical, DS.Spacing.s12 + 2)
                .padding(.horizontal, DS.Spacing.s16)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableButtonStyle())

            if expanded {
                VStack(spacing: 0) {
                    ForEach(vm.sortedCategories(for: discipline), id: \.id) { category in
                        CategoryTreeRow(category: category, vm: vm, onAddDrill: onAddDrill, onEditDrill: onEditDrill)
                    }
                }
                .padding(.bottom, DS.Spacing.s8)
            }
        }
    }
}

// MARK: - Category Tree Row

private struct CategoryTreeRow: View {
    let category: Category
    let vm: CoachWorkspaceViewModel
    let onAddDrill: (_ levelID: String, _ sortIndex: Int) -> Void
    let onEditDrill: (_ drill: Drill, _ levelID: String) -> Void

    @State private var expanded = false

    private var sortedLevels: [MasteryLevel] {
        category.levels.sorted { $0.number < $1.number }
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(DS.Motion.standardSpring) { expanded.toggle() }
            } label: {
                HStack(spacing: DS.Spacing.s12) {
                    Text(category.letter)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                        .frame(width: 18)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(category.name)
                            .style(.foot)
                            .foregroundStyle(DS.Colors.Ink.primary)
                        Text("\(vm.levelCount(for: category)) Levels · \(vm.drillCount(for: category)) Drills")
                            .style(.microSm)
                            .foregroundStyle(DS.Colors.Ink.quaternary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(DS.Colors.Ink.quaternary)
                        .rotationEffect(.degrees(expanded ? 0 : -90))
                }
                .padding(.vertical, DS.Spacing.s8)
                .padding(.leading, DS.Spacing.s32)
                .padding(.trailing, DS.Spacing.s16)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableButtonStyle())

            if expanded {
                ForEach(sortedLevels, id: \.id) { level in
                    levelBlock(level)
                }
            }
        }
    }

    private func levelBlock(_ level: MasteryLevel) -> some View {
        let drills = level.drills.sorted { $0.sortIndex < $1.sortIndex }
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Level \(level.number) · \(level.name)")
                    .style(.microSm)
                    .foregroundStyle(DS.Colors.Ink.tertiary)
                Spacer(minLength: 0)
                Button {
                    onAddDrill(level.id, drills.count)
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "plus")
                            .font(.system(size: 9, weight: .bold))
                        Text("Add drill")
                            .style(.microSm)
                    }
                    .foregroundStyle(DS.Colors.Ink.primary)
                }
                .buttonStyle(PressableButtonStyle())
            }
            .padding(.vertical, DS.Spacing.s8)
            .padding(.leading, DS.Spacing.s48)
            .padding(.trailing, DS.Spacing.s16)

            ForEach(drills, id: \.id) { drill in
                Button {
                    onEditDrill(drill, level.id)
                } label: {
                    HStack(spacing: DS.Spacing.s8) {
                        Circle()
                            .fill(DS.Colors.Ink.disabled)
                            .frame(width: 4, height: 4)
                        Text(drill.title)
                            .style(.foot)
                            .foregroundStyle(DS.Colors.Ink.secondary)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        Image(systemName: "pencil")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(DS.Colors.Ink.quaternary)
                    }
                    .padding(.vertical, DS.Spacing.s8)
                    .padding(.leading, DS.Spacing.s48 + DS.Spacing.s8)
                    .padding(.trailing, DS.Spacing.s16)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
    }
}

#Preview {
    CoachWorkspaceView()
        .preferredColorScheme(.dark)
        .modelContainer(for: [
            Discipline.self, Category.self, MasteryLevel.self,
            Drill.self, DrillProgress.self, PlayerState.self
        ])
}
