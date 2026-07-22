//
//  ControlCenterView.swift
//  MFElite
//
//  Head-coach-only surfaces: rename any content name or the award title live
//  (published instantly to every player), grant/adjust a player's support
//  ledger with a required reason, and review every action in the audit log.
//  Renaming touches CONTENT names only — interface labels stay fixed.
//

import SwiftUI
import SwiftData

/// True only for the head coach — every Control Center surface is gated on this.
private var isHeadCoach: Bool {
    SubscriptionService.shared.coachRole == "head_coach"
}

struct ControlCenterRoute: Hashable {}

// MARK: - Entry

struct ControlCenterView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.s24) {
                VStack(alignment: .leading, spacing: DS.Spacing.s8) {
                    Eyebrow(text: "Head Coach")
                    Text("Control Center")
                        .style(.title1)
                        .foregroundStyle(DS.Colors.Ink.primary)
                    Text("Rename content, support a player directly, and review every action taken.")
                        .style(.foot)
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: DS.Spacing.s8) {
                    controlRow(
                        icon: "pencil.and.list.clipboard",
                        title: "Renaming",
                        detail: "Rename disciplines, categories, levels, drills, ranks & the award",
                        route: ControlCenterRenameRoute()
                    )
                    controlRow(
                        icon: "person.text.rectangle",
                        title: "Player Support",
                        detail: "Grant XP, streaks, shields, boosters & badges with a reason",
                        route: ControlCenterSupportRoute()
                    )
                    controlRow(
                        icon: "list.bullet.clipboard",
                        title: "Audit Log",
                        detail: "Every rename and support grant, newest first",
                        route: ControlCenterAuditRoute()
                    )
                }
            }
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.top, DS.Spacing.s24)
            .padding(.bottom, 120)
        }
        .background(DS.Colors.Bg.base)
        .scrollIndicators(.hidden)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: ControlCenterRenameRoute.self) { _ in RenameBrowserView() }
        .navigationDestination(for: ControlCenterSupportRoute.self) { _ in PlayerSupportView() }
        .navigationDestination(for: ControlCenterAuditRoute.self) { _ in AdminAuditView() }
        .preferredColorScheme(.dark)
    }

    private func controlRow<R: Hashable>(icon: String, title: String, detail: String, route: R) -> some View {
        NavigationLink(value: route) {
            HStack(spacing: DS.Spacing.s12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(DS.Colors.Gold.base)
                    .frame(width: 40, height: 40)
                    .background(DS.Colors.Gold.soft, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .style(.title3)
                        .foregroundStyle(DS.Colors.Ink.primary)
                    Text(detail)
                        .style(.micro)
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DS.Colors.Ink.quaternary)
            }
            .padding(DS.Spacing.s16)
            .frame(maxWidth: .infinity)
            .background(DS.Colors.Bg.card)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(DS.Colors.Line.hairline, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
    }
}

struct ControlCenterRenameRoute: Hashable {}
struct ControlCenterSupportRoute: Hashable {}
struct ControlCenterAuditRoute: Hashable {}

/// The Coach dashboard section that opens the Control Center. Visible ONLY to
/// head coaches — everyone else (regular coaches, players) sees nothing here.
struct ControlCenterEntrySection: View {
    var body: some View {
        if isHeadCoach {
            VStack(alignment: .leading, spacing: DS.Spacing.s12) {
                Eyebrow(text: "Control Center")
                NavigationLink(value: ControlCenterRoute()) {
                    HStack(spacing: DS.Spacing.s12) {
                        Image(systemName: "gearshape.2.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(DS.Colors.Gold.base)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Head Coach Control Center")
                                .style(.title3)
                                .foregroundStyle(DS.Colors.Ink.primary)
                            Text("Renaming, player support, and the audit log")
                                .style(.micro)
                                .foregroundStyle(DS.Colors.Ink.tertiary)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(DS.Colors.Ink.quaternary)
                    }
                    .padding(DS.Spacing.s16)
                    .frame(maxWidth: .infinity)
                    .background(DS.Colors.Gold.soft)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                    .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(DS.Colors.Gold.line, lineWidth: 1))
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
    }
}

// MARK: - Renaming

/// One editable name row: the built-in default plus the current display name,
/// with Save (publishes immediately) and Revert (when an override exists).
private struct RenameRow: View {
    let kind: String
    let targetID: String
    let builtInName: String

    @State private var store = AppConfigStore.shared
    @State private var text: String = ""
    @State private var showPublishConfirm = false
    @State private var isSaving = false

    private var overrideName: String? { store.overrideName(kind: kind, id: targetID) }
    private var hasOverride: Bool { overrideName != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s8) {
            Text(builtInName)
                .style(.micro)
                .foregroundStyle(DS.Colors.Ink.quaternary)
            HStack(spacing: DS.Spacing.s8) {
                TextField("", text: $text, prompt: Text(builtInName).foregroundColor(DS.Colors.Ink.quaternary))
                    .style(.body)
                    .foregroundStyle(DS.Colors.Ink.primary)
                    .padding(.horizontal, DS.Spacing.s12)
                    .frame(height: 40)
                    .background(DS.Colors.Bg.raised)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                Button {
                    guard !isSaving, isMeaningfulChange else { return }
                    showPublishConfirm = true
                } label: {
                    Text(isSaving ? "…" : "Save")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(isMeaningfulChange ? DS.Colors.Ground.primary : DS.Colors.Ink.quaternary)
                        .padding(.horizontal, DS.Spacing.s12)
                        .frame(height: 40)
                        .background(isMeaningfulChange ? Color.white : DS.Colors.Bg.raised)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                }
                .buttonStyle(PressableButtonStyle())
                .disabled(!isMeaningfulChange || isSaving)
                if hasOverride {
                    Button {
                        Task {
                            await store.clearOverride(kind: kind, targetID: targetID)
                            text = builtInName
                        }
                    } label: {
                        Text("Revert")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(DS.Colors.Ink.tertiary)
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
        }
        .padding(DS.Spacing.s12)
        .background(DS.Colors.Bg.card)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(DS.Colors.Line.hairline, lineWidth: 1))
        .onAppear { text = overrideName ?? builtInName }
        .alert("Publish this rename?", isPresented: $showPublishConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Publish") {
                Task {
                    isSaving = true
                    await store.saveOverride(kind: kind, targetID: targetID, name: text)
                    isSaving = false
                }
            }
        } message: {
            Text("This renames it for every player immediately. Publish?")
        }
    }

    private var isMeaningfulChange: Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed != (overrideName ?? builtInName)
    }
}

struct RenameBrowserView: View {
    @Query(sort: \Discipline.sortIndex) private var disciplines: [Discipline]
    @Query(sort: \CombineTest.sortIndex) private var combineTests: [CombineTest]
    @State private var store = AppConfigStore.shared
    @State private var awardText = ""
    @State private var showAwardConfirm = false
    @State private var searchText = ""

    private var allDrills: [(discipline: Discipline, category: Category, level: MasteryLevel, drill: Drill)] {
        var result: [(discipline: Discipline, category: Category, level: MasteryLevel, drill: Drill)] = []
        for discipline in disciplines {
            for category in discipline.categories {
                for level in category.levels.sorted(by: { $0.sortIndex < $1.sortIndex }) {
                    for drill in level.drills.sorted(by: { $0.sortIndex < $1.sortIndex }) {
                        result.append((discipline, category, level, drill))
                    }
                }
            }
        }
        return result
    }

    private var filteredDrills: [(discipline: Discipline, category: Category, level: MasteryLevel, drill: Drill)] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return allDrills }
        return allDrills.filter { $0.drill.title.lowercased().contains(query) || $0.drill.id.lowercased().contains(query) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.s24) {
                awardSection
                ranksSection
                disciplinesSection
                categoriesSection
                levelsSection
                drillsSection
                combineSection
                certificationsSection
            }
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.top, DS.Spacing.s16)
            .padding(.bottom, 120)
        }
        .background(DS.Colors.Bg.base)
        .scrollIndicators(.hidden)
        .navigationTitle("Renaming")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { awardText = store.awardTitle }
    }

    private func section<Content: View>(_ title: String, note: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s12) {
            Eyebrow(text: title)
            if let note {
                Text(note)
                    .style(.micro)
                    .foregroundStyle(DS.Colors.Ink.quaternary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            content()
        }
    }

    private var awardSection: some View {
        section("Award Title", note: "Shown everywhere the award appears \u{2014} celebration, coach approvals, and the paywall.") {
            VStack(alignment: .leading, spacing: DS.Spacing.s8) {
                Text("Default: MF Elite MVP")
                    .style(.micro)
                    .foregroundStyle(DS.Colors.Ink.quaternary)
                HStack(spacing: DS.Spacing.s8) {
                    TextField("", text: $awardText, prompt: Text("MF Elite MVP").foregroundColor(DS.Colors.Ink.quaternary))
                        .style(.body)
                        .foregroundStyle(DS.Colors.Ink.primary)
                        .padding(.horizontal, DS.Spacing.s12)
                        .frame(height: 40)
                        .background(DS.Colors.Bg.raised)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                    Button {
                        showAwardConfirm = true
                    } label: {
                        Text("Save")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(DS.Colors.Ground.primary)
                            .padding(.horizontal, DS.Spacing.s12)
                            .frame(height: 40)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                    }
                    .buttonStyle(PressableButtonStyle())
                    .disabled(awardText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(DS.Spacing.s12)
            .background(DS.Colors.Bg.card)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(DS.Colors.Line.hairline, lineWidth: 1))
            .alert("Publish this rename?", isPresented: $showAwardConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Publish") {
                    Task { await store.saveConfig(key: "award_title", value: awardText) }
                }
            } message: {
                Text("This renames it for every player immediately. Publish?")
            }
        }
    }

    private var ranksSection: some View {
        section("Ranks") {
            VStack(spacing: DS.Spacing.s8) {
                ForEach(AcademyRank.allCases, id: \.self) { rank in
                    RenameRow(kind: "rank", targetID: "\(rank.rawValue)", builtInName: rank.title)
                }
            }
        }
    }

    private var disciplinesSection: some View {
        section("Disciplines") {
            VStack(spacing: DS.Spacing.s8) {
                ForEach(disciplines) { discipline in
                    RenameRow(kind: "discipline", targetID: discipline.id, builtInName: discipline.name)
                }
            }
        }
    }

    private var categoriesSection: some View {
        section("Categories") {
            VStack(spacing: DS.Spacing.s8) {
                ForEach(disciplines) { discipline in
                    ForEach(discipline.categories.sorted(by: { $0.sortIndex < $1.sortIndex })) { category in
                        RenameRow(kind: "category", targetID: category.id, builtInName: category.name)
                    }
                }
            }
        }
    }

    private var levelsSection: some View {
        section("Levels") {
            VStack(spacing: DS.Spacing.s8) {
                ForEach(disciplines) { discipline in
                    ForEach(discipline.categories.sorted(by: { $0.sortIndex < $1.sortIndex })) { category in
                        ForEach(category.levels.sorted(by: { $0.sortIndex < $1.sortIndex })) { level in
                            RenameRow(kind: "level", targetID: level.id, builtInName: level.name)
                        }
                    }
                }
            }
        }
    }

    private var drillsSection: some View {
        section("Drills") {
            VStack(alignment: .leading, spacing: DS.Spacing.s12) {
                HStack(spacing: DS.Spacing.s8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DS.Colors.Ink.quaternary)
                    TextField("", text: $searchText, prompt: Text("Search drills").foregroundColor(DS.Colors.Ink.quaternary))
                        .style(.body)
                        .foregroundStyle(DS.Colors.Ink.primary)
                }
                .padding(.horizontal, DS.Spacing.s12)
                .frame(height: 40)
                .background(DS.Colors.Bg.raised)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))

                VStack(spacing: DS.Spacing.s8) {
                    ForEach(filteredDrills, id: \.drill.id) { entry in
                        RenameRow(kind: "drill", targetID: entry.drill.id, builtInName: entry.drill.title)
                    }
                }
            }
        }
    }

    private var combineSection: some View {
        section("Combine Tests") {
            VStack(spacing: DS.Spacing.s8) {
                ForEach(combineTests) { test in
                    RenameRow(kind: "combine_test", targetID: test.id, builtInName: test.name)
                }
            }
        }
    }

    private var certificationsSection: some View {
        section("Certifications") {
            VStack(spacing: DS.Spacing.s8) {
                ForEach(disciplines) { discipline in
                    ForEach(discipline.categories.sorted(by: { $0.sortIndex < $1.sortIndex })) { category in
                        RenameRow(kind: "certification", targetID: category.id, builtInName: category.certName)
                    }
                }
            }
        }
    }
}

// MARK: - Player Support

/// One support action's amount + required reason, confirmed before it writes.
private struct SupportActionSheet: View {
    let title: String
    let detail: String
    /// Whether an amount field is shown (badge/force-resync actions omit it).
    var showsAmount: Bool = true
    var amountLabel: String = "Amount"
    var defaultAmount: Int = 0
    let onConfirm: (Int, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var amountText: String = ""
    @State private var reason: String = ""

    private var reasonValid: Bool { reason.trimmingCharacters(in: .whitespacesAndNewlines).count >= 5 }
    private var amount: Int { Int(amountText) ?? defaultAmount }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: DS.Spacing.s16) {
                VStack(alignment: .leading, spacing: DS.Spacing.s4) {
                    Text(title)
                        .style(.title3)
                        .foregroundStyle(DS.Colors.Ink.primary)
                    Text(detail)
                        .style(.foot)
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                }

                if showsAmount {
                    VStack(alignment: .leading, spacing: DS.Spacing.s4) {
                        Text(amountLabel.uppercased())
                            .style(.micro)
                            .foregroundStyle(DS.Colors.Ink.quaternary)
                        TextField("", text: $amountText, prompt: Text("\(defaultAmount)").foregroundColor(DS.Colors.Ink.quaternary))
                            .keyboardType(.numberPad)
                            .style(.body)
                            .foregroundStyle(DS.Colors.Ink.primary)
                            .padding(.horizontal, DS.Spacing.s12)
                            .frame(height: 44)
                            .background(DS.Colors.Bg.raised)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                    }
                }

                VStack(alignment: .leading, spacing: DS.Spacing.s4) {
                    Text("REASON \u{2014} REQUIRED")
                        .style(.micro)
                        .foregroundStyle(DS.Colors.Ink.quaternary)
                    TextField("", text: $reason, prompt: Text("Why is this being granted?").foregroundColor(DS.Colors.Ink.quaternary), axis: .vertical)
                        .style(.body)
                        .foregroundStyle(DS.Colors.Ink.primary)
                        .lineLimit(3...5)
                        .padding(DS.Spacing.s12)
                        .background(DS.Colors.Bg.raised)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                }

                Spacer(minLength: 0)

                FloatingButton(label: "Confirm grant", hint: nil) {
                    onConfirm(amount, reason.trimmingCharacters(in: .whitespacesAndNewlines))
                    dismiss()
                }
                .disabled(!reasonValid)
                .opacity(reasonValid ? 1 : 0.5)
            }
            .padding(DS.Spacing.s20)
            .background(DS.Colors.Bg.base)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { amountText = "\(defaultAmount)" }
    }
}

/// One row in the selected player's adjustment history.
private struct SupportHistoryRow: Identifiable {
    let id: String
    let kind: String
    let amount: Int
    let note: String
    let createdAt: Date
    let consumed: Bool
}

struct PlayerSupportView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var model = CoachViewModel()
    @State private var searchText = ""
    @State private var selected: RosterPlayer?
    @State private var history: [SupportHistoryRow] = []
    @State private var isLoadingHistory = false
    @State private var activeSheet: SupportSheetKind?
    @State private var capMessage: String?
    @State private var confirmation: String?

    private enum SupportSheetKind: String, Identifiable {
        case xp, purchasedXP, shields, streak, booster, badge, resync
        var id: String { rawValue }
    }

    private var filtered: [RosterPlayer] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return model.roster }
        return model.roster.filter {
            $0.displayName.lowercased().contains(query)
                || ($0.username?.lowercased().contains(query) ?? false)
                || ($0.kitNumber?.lowercased().contains(query) ?? false)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.s16) {
                header
                searchField

                if let capMessage {
                    Text(capMessage)
                        .style(.foot)
                        .foregroundStyle(Color(hex: "#FF5A5A"))
                        .padding(DS.Spacing.s12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(hex: "#FF5A5A").opacity(0.1), in: RoundedRectangle(cornerRadius: DS.Radius.md))
                }

                if let selected {
                    selectedPlayerSection(selected)
                } else {
                    resultsList
                }
            }
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.top, DS.Spacing.s16)
            .padding(.bottom, 120)
        }
        .background(DS.Colors.Bg.base)
        .scrollIndicators(.hidden)
        .navigationTitle("Player Support")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .bottom) { confirmationToast }
        .task {
            if model.roster.isEmpty { await model.loadOverviewAndRoster(context: modelContext) }
        }
        .sheet(item: $activeSheet) { kind in
            sheet(for: kind)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s4) {
            Text("Support a player directly")
                .style(.title3)
                .foregroundStyle(DS.Colors.Ink.primary)
            Text("Every grant requires a reason and is logged in the audit log.")
                .style(.micro)
                .foregroundStyle(DS.Colors.Ink.tertiary)
        }
    }

    private var searchField: some View {
        HStack(spacing: DS.Spacing.s8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DS.Colors.Ink.quaternary)
            TextField("", text: $searchText, prompt: Text("Search name, username, or kit #").foregroundColor(DS.Colors.Ink.quaternary))
                .style(.body)
                .foregroundStyle(DS.Colors.Ink.primary)
                .onChange(of: searchText) { _, _ in selected = nil }
            if selected != nil {
                Button("Change") { selected = nil }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DS.Colors.Ink.secondary)
            }
        }
        .padding(.horizontal, DS.Spacing.s16)
        .frame(height: 48)
        .background(DS.Colors.Bg.card)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(DS.Colors.Line.hairline, lineWidth: 1))
    }

    private var resultsList: some View {
        VStack(spacing: DS.Spacing.s8) {
            if filtered.isEmpty {
                Text(model.roster.isEmpty ? "Loading roster\u{2026}" : "No players match.")
                    .style(.foot)
                    .foregroundStyle(DS.Colors.Ink.tertiary)
                    .padding(.vertical, DS.Spacing.s24)
            } else {
                ForEach(filtered) { player in
                    Button { select(player) } label: {
                        CoachRosterRow(player: player)
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
        }
    }

    private func select(_ player: RosterPlayer) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        selected = player
        Task { await loadHistory(for: player) }
    }

    private func selectedPlayerSection(_ player: RosterPlayer) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s16) {
            CoachRosterRow(player: player)

            VStack(spacing: DS.Spacing.s8) {
                actionRow(icon: "bolt.fill", title: "Grant XP", detail: "Earned XP \u{2014} daily cap 1,000 per player") { activeSheet = .xp }
                actionRow(icon: "cart.fill", title: "Grant purchased XP", detail: "Counts toward rank only, never leaderboards") { activeSheet = .purchasedXP }
                actionRow(icon: "shield.fill", title: "Grant streak shields", detail: "Adds to the player's held shields") { activeSheet = .shields }
                actionRow(icon: "flame.fill", title: "Restore streak", detail: "Sets the streak to an exact day count") { activeSheet = .streak }
                actionRow(icon: "bolt.horizontal.circle.fill", title: "Grant booster hours", detail: "Adds 2x-earned-XP hours") { activeSheet = .booster }
                actionRow(icon: "rosette", title: "Restore a badge", detail: "Re-grants an achievement badge") { activeSheet = .badge }
                actionRow(icon: "arrow.triangle.2.circlepath", title: "Force re-sync", detail: "Retries any stuck sync on the player's device") { activeSheet = .resync }
            }

            historySection
        }
    }

    private func actionRow(icon: String, title: String, detail: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.s12) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DS.Colors.Gold.base)
                    .frame(width: 36, height: 36)
                    .background(DS.Colors.Gold.soft, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .style(.foot)
                        .fontWeight(.bold)
                        .foregroundStyle(DS.Colors.Ink.primary)
                    Text(detail)
                        .style(.micro)
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DS.Colors.Ink.quaternary)
            }
            .padding(DS.Spacing.s12)
            .background(DS.Colors.Bg.card)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(DS.Colors.Line.hairline, lineWidth: 1))
        }
        .buttonStyle(PressableButtonStyle())
    }

    @ViewBuilder
    private func sheet(for kind: SupportSheetKind) -> some View {
        switch kind {
        case .xp:
            SupportActionSheet(title: "Grant XP", detail: "Earned XP counts toward leaderboards and rank.", amountLabel: "XP amount", defaultAmount: 100) { amount, reason in
                Task { await grant(kind: "xp", amount: amount, reason: reason) }
            }
        case .purchasedXP:
            SupportActionSheet(title: "Grant purchased XP", detail: "Counts toward academy rank only, never leaderboards.", amountLabel: "XP amount", defaultAmount: 100) { amount, reason in
                Task { await grant(kind: "purchased_xp", amount: amount, reason: reason) }
            }
        case .shields:
            SupportActionSheet(title: "Grant streak shields", detail: "Adds to the player's held streak shields.", amountLabel: "Shields", defaultAmount: 1) { amount, reason in
                Task { await grant(kind: "streak_freeze", amount: amount, reason: reason) }
            }
        case .streak:
            SupportActionSheet(title: "Restore streak", detail: "Sets the player's current streak to this exact day count.", amountLabel: "Streak days", defaultAmount: 1) { amount, reason in
                Task { await grant(kind: "streak_set", amount: amount, reason: reason) }
            }
        case .booster:
            SupportActionSheet(title: "Grant booster hours", detail: "Adds hours of 2x earned-XP.", amountLabel: "Hours", defaultAmount: 48) { amount, reason in
                Task { await grant(kind: "booster_hours", amount: amount, reason: reason) }
            }
        case .badge:
            BadgeRestoreSheet { badgeID, reason in
                Task { await grant(kind: "badge", amount: 0, reason: reason, badgeID: badgeID) }
            }
        case .resync:
            SupportActionSheet(title: "Force re-sync", detail: "Retries any quarantined sync work on the player's next launch.", showsAmount: false) { _, reason in
                Task { await grant(kind: "force_resync", amount: 0, reason: reason) }
            }
        }
    }

    private func grant(kind: String, amount: Int, reason: String, badgeID: String? = nil) async {
        guard let selected, let coachID = SupabaseAuth.shared.userID else { return }
        capMessage = nil

        if kind == "xp" {
            let startOfDay = Calendar.current.startOfDay(for: Date())
            let rows = await SupabaseClient.shared.get(
                table: "support_adjustments",
                query: [
                    URLQueryItem(name: "user_id", value: "eq.\(selected.id)"),
                    URLQueryItem(name: "kind", value: "eq.xp"),
                    URLQueryItem(name: "created_at", value: "gte.\(ISO8601DateFormatter().string(from: startOfDay))")
                ]
            ) ?? []
            let existing = rows.reduce(0) { $0 + (($1["amount"] as? Int) ?? 0) }
            if existing + amount > 1000 {
                capMessage = "Daily XP grant limit for this player reached (1,000)."
                return
            }
        }

        var row: [String: Any] = [
            "user_id": selected.id,
            "kind": kind,
            "amount": amount,
            "note": reason,
            "created_by": coachID
        ]
        if let badgeID { row["badge_id"] = badgeID }
        let ok = await SupabaseClient.shared.insert(table: "support_adjustments", values: row)
        guard ok else { return }

        await AppConfigStore.shared.audit(action: "support_grant", detail: [
            "user_id": selected.id, "kind": kind, "amount": amount, "note": reason
        ])
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            confirmation = "Grant sent \u{2014} applies on the player's next launch."
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation { confirmation = nil }
        }
        await loadHistory(for: selected)
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s12) {
            Eyebrow(text: "History")
            if isLoadingHistory {
                ProgressView().tint(DS.Colors.Ink.tertiary)
            } else if history.isEmpty {
                Text("No support grants yet for this player.")
                    .style(.micro)
                    .foregroundStyle(DS.Colors.Ink.quaternary)
            } else {
                VStack(spacing: DS.Spacing.s8) {
                    ForEach(history) { item in
                        HStack(alignment: .top, spacing: DS.Spacing.s12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(item.kind.replacingOccurrences(of: "_", with: " ").capitalized) \(item.amount != 0 ? "\u{00b7} \(item.amount)" : "")")
                                    .style(.foot)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(DS.Colors.Ink.primary)
                                if !item.note.isEmpty {
                                    Text(item.note)
                                        .style(.micro)
                                        .foregroundStyle(DS.Colors.Ink.tertiary)
                                }
                                Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                                    .style(.micro)
                                    .foregroundStyle(DS.Colors.Ink.quaternary)
                            }
                            Spacer(minLength: 0)
                            Text(item.consumed ? "Applied" : "Pending")
                                .style(.micro)
                                .foregroundStyle(item.consumed ? DS.Colors.Ink.tertiary : DS.Colors.Gold.textLight)
                        }
                        .padding(DS.Spacing.s12)
                        .background(DS.Colors.Bg.card)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                        .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(DS.Colors.Line.hairline, lineWidth: 1))
                    }
                }
            }
        }
    }

    private func loadHistory(for player: RosterPlayer) async {
        isLoadingHistory = true
        let rows = await SupabaseClient.shared.get(
            table: "support_adjustments",
            query: [
                URLQueryItem(name: "user_id", value: "eq.\(player.id)"),
                URLQueryItem(name: "order", value: "created_at.desc"),
                URLQueryItem(name: "limit", value: "50")
            ]
        ) ?? []
        history = rows.compactMap { row in
            guard let id = row["id"] as? String, let kind = row["kind"] as? String else { return nil }
            let created = (row["created_at"] as? String).flatMap(SyncEngine.isoDate) ?? Date()
            return SupportHistoryRow(
                id: id,
                kind: kind,
                amount: (row["amount"] as? Int) ?? 0,
                note: (row["note"] as? String) ?? "",
                createdAt: created,
                consumed: row["consumed_at"] != nil && !(row["consumed_at"] is NSNull)
            )
        }
        isLoadingHistory = false
    }

    @ViewBuilder
    private var confirmationToast: some View {
        if let confirmation {
            Text(confirmation)
                .style(.foot)
                .foregroundStyle(DS.Colors.Ground.primary)
                .padding(.vertical, DS.Spacing.s12)
                .padding(.horizontal, DS.Spacing.s20)
                .background(Color.white, in: Capsule())
                .padding(.bottom, DS.Spacing.s32)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

/// A picker sheet for restoring a specific achievement badge.
private struct BadgeRestoreSheet: View {
    let onConfirm: (String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var badge: AchievementBadge = .firstDrill
    @State private var reason: String = ""

    private var reasonValid: Bool { reason.trimmingCharacters(in: .whitespacesAndNewlines).count >= 5 }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: DS.Spacing.s16) {
                Text("Restore a badge")
                    .style(.title3)
                    .foregroundStyle(DS.Colors.Ink.primary)

                Picker("Badge", selection: $badge) {
                    ForEach(AchievementBadge.allCases) { b in
                        Text(b.title).tag(b)
                    }
                }
                .pickerStyle(.wheel)

                VStack(alignment: .leading, spacing: DS.Spacing.s4) {
                    Text("REASON \u{2014} REQUIRED")
                        .style(.micro)
                        .foregroundStyle(DS.Colors.Ink.quaternary)
                    TextField("", text: $reason, prompt: Text("Why is this being restored?").foregroundColor(DS.Colors.Ink.quaternary), axis: .vertical)
                        .style(.body)
                        .foregroundStyle(DS.Colors.Ink.primary)
                        .lineLimit(2...4)
                        .padding(DS.Spacing.s12)
                        .background(DS.Colors.Bg.raised)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                }

                Spacer(minLength: 0)

                FloatingButton(label: "Confirm restore", hint: nil) {
                    onConfirm(badge.rawValue, reason.trimmingCharacters(in: .whitespacesAndNewlines))
                    dismiss()
                }
                .disabled(!reasonValid)
                .opacity(reasonValid ? 1 : 0.5)
            }
            .padding(DS.Spacing.s20)
            .background(DS.Colors.Bg.base)
            .navigationTitle("Restore a badge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Audit Log

private struct AuditRow: Identifiable {
    let id: String
    let actor: String
    let action: String
    let detail: String
    let createdAt: Date
}

struct AdminAuditView: View {
    @State private var rows: [AuditRow] = []
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.s8) {
                if isLoading {
                    ProgressView().tint(DS.Colors.Ink.tertiary).padding(.top, DS.Spacing.s32)
                } else if rows.isEmpty {
                    Text("No actions logged yet.")
                        .style(.foot)
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                        .padding(.top, DS.Spacing.s32)
                } else {
                    ForEach(rows) { row in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(row.action.replacingOccurrences(of: "_", with: " ").capitalized)
                                    .style(.foot)
                                    .fontWeight(.bold)
                                    .foregroundStyle(DS.Colors.Ink.primary)
                                Spacer(minLength: 0)
                                Text(row.createdAt.formatted(date: .abbreviated, time: .shortened))
                                    .style(.micro)
                                    .foregroundStyle(DS.Colors.Ink.quaternary)
                            }
                            Text(row.detail)
                                .style(.micro)
                                .foregroundStyle(DS.Colors.Ink.tertiary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(DS.Spacing.s12)
                        .background(DS.Colors.Bg.card)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                        .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(DS.Colors.Line.hairline, lineWidth: 1))
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.top, DS.Spacing.s16)
            .padding(.bottom, 120)
        }
        .background(DS.Colors.Bg.base)
        .scrollIndicators(.hidden)
        .navigationTitle("Audit Log")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        let fetched = await SupabaseClient.shared.get(
            table: "admin_audit",
            query: [
                URLQueryItem(name: "order", value: "created_at.desc"),
                URLQueryItem(name: "limit", value: "200")
            ]
        ) ?? []
        rows = fetched.compactMap { row in
            guard let id = row["id"] as? String, let action = row["action"] as? String else { return nil }
            let created = (row["created_at"] as? String).flatMap(SyncEngine.isoDate) ?? Date()
            var detailText = ""
            if let detail = row["detail"] as? [String: Any] {
                detailText = detail.map { "\($0.key): \($0.value)" }.sorted().joined(separator: " \u{00b7} ")
            }
            return AuditRow(id: id, actor: (row["actor"] as? String) ?? "", action: action, detail: detailText, createdAt: created)
        }
        isLoading = false
    }
}
