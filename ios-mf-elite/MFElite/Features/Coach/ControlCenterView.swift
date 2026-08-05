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
                ConfirmButton(
                    isEnabled: isMeaningfulChange,
                    isBusy: isSaving,
                    isConfirmed: !isMeaningfulChange && hasOverride,
                    label: "Publish rename"
                ) {
                    showPublishConfirm = true
                }
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

/// One renameable thing, flattened with the group it belongs to.
private struct RenameItem: Identifiable {
    let kind: String
    let targetID: String
    let name: String
    /// "Technical · Ball Mastery" — the category or program it sits under.
    let group: String
    var id: String { "\(kind)|\(targetID)" }
}

/// A sub-heading inside a section (a discipline, or a discipline · category).
private struct RenameGroup: Identifiable {
    let title: String
    let items: [RenameItem]
    var id: String { title }
}

/// One collapsible kind: Ranks, Drills, Levels…
private struct RenameSection: Identifiable {
    let kind: String
    let title: String
    let note: String?
    let groups: [RenameGroup]
    var id: String { kind }
    var count: Int { groups.reduce(0) { $0 + $1.items.count } }
}

struct RenameBrowserView: View {
    @Query(sort: \Discipline.sortIndex) private var disciplines: [Discipline]
    @Query(sort: \CombineTest.sortIndex) private var combineTests: [CombineTest]
    @State private var store = AppConfigStore.shared
    @State private var awardText = ""
    @State private var showAwardConfirm = false
    @State private var searchText = ""
    @State private var expanded: Set<String> = []

    // MARK: - Model

    /// Everything renameable, grouped by the category or program it belongs to.
    ///
    /// This screen used to render all seven kinds as flat, always-visible
    /// sections in one non-lazy ScrollView — about 342 editable rows, each with
    /// its own TextField, state, config observer and alert, built eagerly on
    /// appear. The search box only filtered the drills; the other 116 rows were
    /// always on screen.
    private var sections: [RenameSection] {
        let sortedCategories: (Discipline) -> [Category] = { discipline in
            discipline.categories.sorted { $0.sortIndex < $1.sortIndex }
        }

        var result: [RenameSection] = []

        result.append(
            RenameSection(
                kind: "rank",
                title: "Ranks",
                note: "The academy pathway names.",
                groups: [
                    RenameGroup(
                        title: "Academy pathway",
                        items: AcademyRank.allCases.map {
                            RenameItem(kind: "rank", targetID: "\($0.rawValue)",
                                       name: $0.title, group: "Academy pathway")
                        }
                    )
                ]
            )
        )

        result.append(
            RenameSection(
                kind: "discipline",
                title: "Disciplines",
                note: "The four training pillars.",
                groups: [
                    RenameGroup(
                        title: "Training pillars",
                        items: disciplines.map {
                            RenameItem(kind: "discipline", targetID: $0.id,
                                       name: $0.name, group: "Training pillars")
                        }
                    )
                ]
            )
        )

        result.append(
            RenameSection(
                kind: "category",
                title: "Categories",
                note: "Grouped by the discipline they belong to.",
                groups: disciplines.map { discipline in
                    RenameGroup(
                        title: discipline.name,
                        items: sortedCategories(discipline).map {
                            RenameItem(kind: "category", targetID: $0.id,
                                       name: $0.name, group: discipline.name)
                        }
                    )
                }
            )
        )

        result.append(
            RenameSection(
                kind: "level",
                title: "Levels",
                note: "Grouped by discipline and category.",
                groups: disciplines.flatMap { discipline in
                    sortedCategories(discipline).map { category in
                        let group = "\(discipline.name) · \(category.name)"
                        return RenameGroup(
                            title: group,
                            items: category.levels
                                .sorted { $0.sortIndex < $1.sortIndex }
                                .map {
                                    RenameItem(kind: "level", targetID: $0.id,
                                               name: $0.name, group: group)
                                }
                        )
                    }
                }
            )
        )

        result.append(
            RenameSection(
                kind: "drill",
                title: "Drills",
                note: "Grouped by discipline and category.",
                groups: disciplines.flatMap { discipline in
                    sortedCategories(discipline).map { category in
                        let group = "\(discipline.name) · \(category.name)"
                        return RenameGroup(
                            title: group,
                            items: category.levels
                                .sorted { $0.sortIndex < $1.sortIndex }
                                .flatMap { level in
                                    level.drills
                                        .sorted { $0.sortIndex < $1.sortIndex }
                                        .map {
                                            RenameItem(kind: "drill", targetID: $0.id,
                                                       name: $0.title, group: group)
                                        }
                                }
                        )
                    }
                }
            )
        )

        result.append(
            RenameSection(
                kind: "combine_test",
                title: "Combine Tests",
                note: nil,
                groups: [
                    RenameGroup(
                        title: "MF Combine",
                        items: combineTests.map {
                            RenameItem(kind: "combine_test", targetID: $0.id,
                                       name: $0.name, group: "MF Combine")
                        }
                    )
                ]
            )
        )

        result.append(
            RenameSection(
                kind: "certification",
                title: "Certifications",
                note: "One per category.",
                groups: disciplines.map { discipline in
                    RenameGroup(
                        title: discipline.name,
                        items: sortedCategories(discipline).map {
                            RenameItem(kind: "certification", targetID: $0.id,
                                       name: $0.certName, group: discipline.name)
                        }
                    )
                }
            )
        )

        return result
    }

    private var query: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var isSearching: Bool { !query.isEmpty }

    /// Sections with the search applied, dropping anything that ends up empty.
    /// The search now spans every kind, not just drills.
    private var visibleSections: [RenameSection] {
        guard isSearching else { return sections }
        return sections.compactMap { section in
            let groups = section.groups.compactMap { group -> RenameGroup? in
                let items = group.items.filter {
                    $0.name.lowercased().contains(query)
                        || $0.targetID.lowercased().contains(query)
                        || group.title.lowercased().contains(query)
                }
                return items.isEmpty ? nil : RenameGroup(title: group.title, items: items)
            }
            return groups.isEmpty
                ? nil
                : RenameSection(kind: section.kind, title: section.title,
                                note: section.note, groups: groups)
        }
    }

    private var totalRenameable: Int {
        sections.reduce(0) { $0 + $1.count }
    }

    private var matchCount: Int {
        visibleSections.reduce(0) { $0 + $1.count }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DS.Spacing.s16) {
                heroCard
                awardSection

                if isSearching {
                    Text("\(matchCount) match\(matchCount == 1 ? "" : "es")")
                        .style(.micro)
                        .foregroundStyle(DS.Colors.Ink.quaternary)
                }

                if visibleSections.isEmpty {
                    Text("Nothing matches “\(searchText)”.")
                        .style(.body)
                        .foregroundStyle(DS.Colors.Ink.quaternary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, DS.Spacing.s32)
                }

                ForEach(visibleSections) { section in
                    sectionBlock(section)
                }
            }
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.top, DS.Spacing.s16)
            .padding(.bottom, DS.tabBarClearance + DS.Spacing.s24)
        }
        .background(DS.Colors.Bg.base)
        .scrollIndicators(.hidden)
        .searchable(text: $searchText, prompt: "Search anything you can rename")
        .navigationTitle("Renaming")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { awardText = store.awardTitle }
    }

    /// Explains the screen and carries the counts, so the first thing on screen
    /// is orientation rather than 342 text fields.
    private var heroCard: some View {
        Card {
            VStack(alignment: .leading, spacing: DS.Spacing.s8) {
                HStack(spacing: DS.Spacing.s12) {
                    SectionIcon(systemName: "textformat")
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Rename anything")
                            .style(.title3)
                            .foregroundStyle(DS.Colors.Ink.primary)
                        Text("\(totalRenameable) items across \(sections.count) groups")
                            .style(.micro)
                            .foregroundStyle(DS.Colors.Ink.tertiary)
                    }
                    Spacer(minLength: 0)
                }
                Text("Renames apply to every player as soon as you publish. Search, or open a group to browse.")
                    .style(.foot)
                    .foregroundStyle(DS.Colors.Ink.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private func sectionBlock(_ section: RenameSection) -> some View {
        // While searching, everything is open — hiding matches behind a
        // collapsed header would defeat the search.
        let isOpen = isSearching || expanded.contains(section.kind)

        VStack(alignment: .leading, spacing: DS.Spacing.s8) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(DS.Motion.standardSpring) {
                    if expanded.contains(section.kind) { expanded.remove(section.kind) }
                    else { expanded.insert(section.kind) }
                }
            } label: {
                HStack(spacing: DS.Spacing.s12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(section.title)
                            .style(.title3)
                            .foregroundStyle(DS.Colors.Ink.primary)
                        if let note = section.note {
                            Text(note)
                                .style(.micro)
                                .foregroundStyle(DS.Colors.Ink.quaternary)
                        }
                    }
                    Spacer(minLength: DS.Spacing.s8)
                    Text("\(section.count)")
                        .style(.micro)
                        .foregroundStyle(DS.Colors.Gold.textLight)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(DS.Colors.Ink.quaternary)
                        .rotationEffect(.degrees(isOpen ? 90 : 0))
                }
                .padding(DS.Spacing.s16)
                .frame(maxWidth: .infinity)
                .background(DS.Colors.Bg.card)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.md)
                        .stroke(DS.Colors.Line.hairline, lineWidth: 1)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableButtonStyle())
            .disabled(isSearching)
            .accessibilityLabel("\(section.title), \(section.count) items")
            .accessibilityHint(isOpen ? "Collapse" : "Expand")

            if isOpen {
                ForEach(section.groups) { group in
                    groupBlock(group, showsHeader: section.groups.count > 1)
                }
            }
        }
    }

    @ViewBuilder
    private func groupBlock(_ group: RenameGroup, showsHeader: Bool) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s8) {
            if showsHeader {
                Eyebrow(text: group.title)
                    .padding(.top, DS.Spacing.s8)
            }
            ForEach(group.items) { item in
                RenameRow(kind: item.kind, targetID: item.targetID, builtInName: item.name)
            }
        }
        .padding(.leading, showsHeader ? DS.Spacing.s8 : 0)
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
                    ConfirmButton(isEnabled: !awardText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                        showAwardConfirm = true
                    }
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
