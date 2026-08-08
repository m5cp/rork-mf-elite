//
//  CoachPlayerDetailView.swift
//  MFElite
//
//  Read-only deep view of one player for a coach: progression, mastery,
//  training time, combine results, Game IQ and full session history. Loads
//  async with pull-to-refresh and fails soft.
//

import SwiftUI
import SwiftData
import Charts

/// One calendar month of a player's session history. Grouping turns a 500-row
/// wall into a dozen headers a coach can actually scan.
private struct HistoryGroup: Identifiable {
    let title: String
    let items: [SessionHistoryItem]
    var id: String { title }
    var minutes: Int { items.reduce(0) { $0 + $1.durationSec } / 60 }
}

struct CoachPlayerDetailView: View {
    let player: RosterPlayer
    @Bindable var model: CoachViewModel
    @Environment(\.modelContext) private var modelContext
    @State private var sync = SyncEngine.shared
    @State private var shareImage: ShareableImage?
    @State private var isExporting = false
    @State private var focusDraft: String = ""
    @State private var focusSaved = false
    @State private var noteDraft: String = ""
    @State private var noteSaved = false
    @State private var showReportBuilder = false
    /// Non-nil when a coach save failed.
    @State private var saveError: String?
    /// The server values the drafts were last synced from, so a refresh that
    /// lands mid-edit doesn't overwrite what the coach is typing.
    @State private var loadedFocus: String = ""
    @State private var loadedNote: String = ""
    /// Set once the coach touches a field. Emptiness alone isn't a safe signal —
    /// deliberately clearing a note leaves it empty, and refilling it from the
    /// server would undo exactly the edit they meant to make.
    @State private var focusEdited = false
    @State private var noteEdited = false
    /// In-flight flags for the two per-field confirms, so the check turns into a
    /// spinner rather than looking tappable while the write is out.
    @State private var isSavingFocus = false
    @State private var isSavingNote = false
    /// Session-history browsing state. The history can run to 500 rows, so it
    /// gets its own search and collapsed month groups.
    @State private var historyQuery = ""
    @State private var historyExpanded: Set<String> = []

    private var currentMonthKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: Date())
    }

    private var notes: [CoachNote] { model.notesCache[player.id] ?? [] }
    private var currentMonthNote: CoachNote? { notes.first { $0.month == currentMonthKey } }

    private var state: CoachLoadState { model.detailState[player.id] ?? .idle }
    private var detail: CoachPlayerDetail? { model.detailCache[player.id] }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.s24) {
                identityHeader

                if !sync.isOnline && detail == nil {
                    offlineBanner
                }

                if let detail {
                    progressionCard(detail)
                    shareProgressButton(detail)
                    masterySection(detail)
                    trainingTimeSection(detail)
                    trendSection(detail)
                    if !detail.combineProgress.isEmpty { combineProgressSection(detail) }
                    focusSection(detail)
                    notesSection()
                    reportSection(detail)
                    if !detail.combineLatest.isEmpty { combineSection(detail) }
                    gameIQSection(detail)
                    historySection(detail)
                } else if state == .failed {
                    retryState
                } else {
                    loadingState
                }
            }
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.top, DS.Spacing.s16)
            .padding(.bottom, 120)
        }
        .background(DS.Colors.Bg.base)
        .scrollIndicators(.hidden)
        .navigationTitle(player.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let detail {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(
                        item: CoachExport.report(for: player, detail: detail),
                        preview: SharePreview("\(player.displayName) — MF Elite report")
                    ) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(DS.Colors.Ink.secondary)
                    }
                }
            }
        }
        .refreshable {
            await model.loadDetail(for: player, context: modelContext, force: true)
            await model.loadNotes(for: player.id)
            syncDrafts()
        }
        .task {
            await model.loadDetail(for: player, context: modelContext)
            await model.loadNotes(for: player.id)
            syncDrafts()
        }
        .alert("Couldn't save", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK", role: .cancel) { saveError = nil }
        } message: {
            Text(saveError ?? "")
        }
        .onChange(of: focusDraft) { _, _ in focusSaved = false }
        .onChange(of: noteDraft) { _, _ in noteSaved = false }
        .sheet(item: $shareImage) { item in
            ShareSheet(items: [item.image])
                .presentationDetents([.medium, .large])
        }
        .fullScreenCover(isPresented: $showReportBuilder) {
            if let detail = model.detailCache[player.id] {
                ProgressReportBuilderView(player: player, detail: detail)
            }
        }
    }

    /// Sync editable drafts from freshly-loaded data (focus + this month's note).
    /// Pull server values into the editors, but never clobber in-progress
    /// typing. This ran from both `.task` and `.refreshable` and assigned
    /// unconditionally, so a coach who started writing while the detail fetch
    /// (six round-trips) was still in flight had their text wiped when it landed.
    private func syncDrafts() {
        let serverFocus = model.detailCache[player.id]?.coachFocus ?? ""
        if !focusEdited { focusDraft = serverFocus }
        loadedFocus = serverFocus

        let serverNote = currentMonthNote?.body ?? ""
        if !noteEdited { noteDraft = serverNote }
        loadedNote = serverNote
    }

    // MARK: - Trend (last 8 weeks)

    private func trendSection(_ detail: CoachPlayerDetail) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s12) {
            Eyebrow(text: "Last 8 Weeks")
            Card(padding: DS.Spacing.s16) {
                if detail.weeklyMinutes.allSatisfy({ $0.minutes == 0 }) {
                    emptyLine("No training logged in the last 8 weeks.")
                } else {
                    trendSummaryHeader(detail)
                        .padding(.bottom, DS.Spacing.s12)
                    Chart(detail.weeklyMinutes) { point in
                        BarMark(
                            x: .value("Week", point.weekStart, unit: .weekOfYear),
                            y: .value("Minutes", point.minutes)
                        )
                        .foregroundStyle(DS.Colors.Gold.base)
                        .cornerRadius(3)
                    }
                    .frame(height: 160)
                    .chartYAxis {
                        AxisMarks { _ in
                            AxisGridLine().foregroundStyle(DS.Colors.Line.hairline)
                            AxisValueLabel()
                        }
                    }
                }
            }
        }
    }

    /// Header above the 8-week chart: total minutes this window and the change
    /// from the first tracked week to the most recent week.
    private func trendSummaryHeader(_ detail: CoachPlayerDetail) -> some View {
        let points = detail.weeklyMinutes
        let total = points.reduce(0) { $0 + $1.minutes }
        let first = points.first?.minutes ?? 0
        let last = points.last?.minutes ?? 0
        let delta = last - first
        let improved = delta >= 0
        return HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(CoachFormat.minutes(total))
                    .style(.num(size: 26))
                    .foregroundStyle(DS.Colors.Ink.primary)
                Text("Total this window")
                    .style(.micro)
                    .foregroundStyle(DS.Colors.Ink.quaternary)
            }
            Spacer()
            HStack(spacing: DS.Spacing.s4) {
                Image(systemName: delta == 0 ? "minus" : (improved ? "arrow.up.right" : "arrow.down.right"))
                    .font(.system(size: 12, weight: .bold))
                Text("\(improved ? "+" : "")\(delta) min")
                    .style(.foot)
                    .fontWeight(.semibold)
                    .monospacedDigit()
            }
            .foregroundStyle(delta == 0 ? DS.Colors.Ink.tertiary : (improved ? Color(hex: "#30D158") : Color(hex: "#FF453A")))
        }
    }

    // MARK: - Combine progress (baseline → latest · best)

    private func combineProgressSection(_ detail: CoachPlayerDetail) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s12) {
            Eyebrow(text: "Combine Progress")
            Card(padding: DS.Spacing.s16) {
                VStack(spacing: 0) {
                    ForEach(Array(detail.combineProgress.enumerated()), id: \.element.testID) { index, item in
                        if index > 0 { Hairline() }
                        combineProgressRow(item)
                    }
                }
            }
        }
    }

    private func combineProgressRow(_ item: CombineProgress) -> some View {
        let unchanged = item.latest == item.baseline
        let improved = item.lowerIsBetter ? (item.latest < item.baseline) : (item.latest > item.baseline)
        return HStack(alignment: .firstTextBaseline) {
            Text(item.label)
                .style(.title3)
                .foregroundStyle(DS.Colors.Ink.primary)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: DS.Spacing.s4) {
                    if !unchanged {
                        Image(systemName: improved ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(improved ? Color(hex: "#30D158") : Color(hex: "#FF453A"))
                    }
                    Text("\(CoachFormat.combineValue(item.baseline, unit: item.unit)) → \(CoachFormat.combineValue(item.latest, unit: item.unit))")
                        .style(.foot)
                        .foregroundStyle(DS.Colors.Ink.secondary)
                }
                Text("Best \(CoachFormat.combineValue(item.best, unit: item.unit))")
                    .style(.cap)
                    .foregroundStyle(DS.Colors.Ink.quaternary)
            }
        }
        .padding(.vertical, DS.Spacing.s12)
    }

    // MARK: - Training focus

    private func focusSection(_ detail: CoachPlayerDetail) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s12) {
            Eyebrow(text: "Training Focus")
            Card(padding: DS.Spacing.s16) {
                // The confirm sits on the field it commits rather than under the
                // card, so there is never a question of what the checkmark saves.
                HStack(alignment: .bottom, spacing: DS.Spacing.s8) {
                    TextField("What this player is working on…", text: $focusDraft, axis: .vertical)
                        .style(.body)
                        .foregroundStyle(DS.Colors.Ink.primary)
                        .lineLimit(2...5)
                        // Compare against the last synced server value: syncDrafts also
                        // assigns this field, and that assignment must not count as
                        // the coach editing it.
                        .onChange(of: focusDraft) { _, new in
                            if new != loadedFocus { focusEdited = true }
                        }
                    ConfirmButton(
                        isEnabled: focusDraft != loadedFocus,
                        isBusy: isSavingFocus,
                        isConfirmed: focusSaved,
                        label: "Save training focus"
                    ) {
                        Task {
                            isSavingFocus = true
                            // Only claim "Saved" when it actually saved.
                            let ok = await model.saveCoachFocus(focusDraft, for: player.id)
                            isSavingFocus = false
                            focusSaved = ok
                            if ok { loadedFocus = focusDraft; focusEdited = false }
                            if !ok { saveError = "Couldn't save that focus. Check your connection and try again." }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Coach notes

    private func notesSection() -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s12) {
            Eyebrow(text: "Coach Notes")
            Card(padding: DS.Spacing.s16) {
                VStack(alignment: .leading, spacing: DS.Spacing.s12) {
                    Text(CoachFormat.monthLabel(currentMonthKey))
                        .style(.micro)
                        .foregroundStyle(DS.Colors.Ink.quaternary)
                    HStack(alignment: .bottom, spacing: DS.Spacing.s8) {
                        TextField("Add a note for this month…", text: $noteDraft, axis: .vertical)
                            .style(.body)
                            .foregroundStyle(DS.Colors.Ink.primary)
                            .lineLimit(3...8)
                            .onChange(of: noteDraft) { _, new in
                                if new != loadedNote { noteEdited = true }
                            }
                        ConfirmButton(
                            isEnabled: noteDraft != loadedNote,
                            isBusy: isSavingNote,
                            isConfirmed: noteSaved,
                            label: "Save this month's note"
                        ) {
                            Task {
                                isSavingNote = true
                                let ok = await model.saveNote(month: currentMonthKey, text: noteDraft, for: player.id)
                                isSavingNote = false
                                noteSaved = ok
                                if ok { loadedNote = noteDraft; noteEdited = false }
                                if !ok { saveError = "Couldn't save that note. Check your connection and try again." }
                            }
                        }
                    }
                }
            }

            let prior = notes.filter { $0.month != currentMonthKey }
            if !prior.isEmpty {
                VStack(spacing: DS.Spacing.s8) {
                    ForEach(prior) { note in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(CoachFormat.monthLabel(note.month))
                                .style(.cap)
                                .foregroundStyle(DS.Colors.Ink.quaternary)
                            Text(note.body)
                                .style(.foot)
                                .foregroundStyle(DS.Colors.Ink.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(DS.Spacing.s12)
                        .background(DS.Colors.Bg.card)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                        .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(DS.Colors.Line.hairline, lineWidth: 1))
                    }
                }
            }
        }
    }

    // MARK: - Progress report

    private func reportSection(_ detail: CoachPlayerDetail) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s12) {
            Eyebrow(text: "Progress Report")
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                showReportBuilder = true
            } label: {
                HStack(spacing: DS.Spacing.s12) {
                    SectionIcon(systemName: "doc.text.fill")
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Create / edit report")
                            .style(.title3)
                            .foregroundStyle(DS.Colors.Ink.primary)
                        Text("An editable report card you can send to parents as a PDF")
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
                .background(DS.Colors.Bg.card)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(DS.Colors.Line.hairline, lineWidth: 1))
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableButtonStyle())
        }
    }

    // MARK: - Share progress card (image)

    private func shareProgressButton(_ detail: CoachPlayerDetail) -> some View {
        Button {
            exportProgressCard(detail)
        } label: {
            HStack(spacing: DS.Spacing.s8) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 14, weight: .semibold))
                Text(isExporting ? "Preparing…" : "Share progress card")
                    .style(.foot)
                    .fontWeight(.semibold)
                Spacer(minLength: 0)
            }
            .foregroundStyle(DS.Colors.Ink.primary)
            .padding(DS.Spacing.s12)
            .frame(maxWidth: .infinity)
            .background(DS.Colors.Bg.card)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(DS.Colors.Line.hairline, lineWidth: 1))
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(isExporting)
    }

    /// A dark, branded progress card image. First name only; no email or surname.
    private func progressCard(_ detail: CoachPlayerDetail) -> some View {
        let firstName = ShareText.firstName(player.displayName)
        let kit = (player.kitNumber?.isEmpty == false) ? " · #\(player.kitNumber!)" : ""
        return MFShareCard(eyebrow: "Progress") {
            VStack(spacing: DS.Spacing.s16) {
                Text("\(firstName)\(kit)")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)

                HStack(spacing: 0) {
                    cardStat(value: "\(detail.streak)", label: "Day streak")
                    cardStatDivider
                    cardStat(value: CoachFormat.minutes(detail.minutes30d), label: "Last 30d")
                    cardStatDivider
                    cardStat(value: "\(detail.totalMastered)", label: "Mastered")
                }

                if !detail.combineLatest.isEmpty {
                    VStack(spacing: DS.Spacing.s8) {
                        Text("LATEST COMBINE")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1.6)
                            .foregroundStyle(.white.opacity(0.4))
                        ForEach(detail.combineLatest.prefix(4)) { item in
                            HStack {
                                Text(item.name)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.75))
                                Spacer(minLength: DS.Spacing.s12)
                                Text(CoachFormat.combineValue(item.value, unit: item.unit))
                                    .font(.system(size: 15, weight: .bold))
                                    .monospacedDigit()
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func cardStat(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(.white)
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold))
                .tracking(1)
                .foregroundStyle(.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity)
    }

    private var cardStatDivider: some View {
        Rectangle()
            .fill(.white.opacity(0.12))
            .frame(width: 1, height: 36)
    }

    private func exportProgressCard(_ detail: CoachPlayerDetail) {
        guard !isExporting else { return }
        isExporting = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let image = ShareCardRenderer.render(progressCard(detail))
        isExporting = false
        if let image { shareImage = ShareableImage(image: image) }
    }

    // MARK: - Identity

    private var identityHeader: some View {
        HStack(spacing: DS.Spacing.s16) {
            Monogram(size: 56, initials: CoachFormat.initials(player.displayName),
                     kit: player.kitNumber?.isEmpty == false ? player.kitNumber : nil)
            VStack(alignment: .leading, spacing: 4) {
                Text(player.displayName)
                    .style(.title2)
                    .foregroundStyle(DS.Colors.Ink.primary)
                if let line = identityLine {
                    Text(line)
                        .style(.foot)
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                        .lineLimit(1)
                }
                if let email = player.email, !email.isEmpty {
                    Text(email)
                        .style(.cap)
                        .foregroundStyle(DS.Colors.Ink.quaternary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private var identityLine: String? {
        var parts: [String] = []
        if let username = player.username, !username.isEmpty { parts.append("@\(username)") }
        if let position = player.position, !position.isEmpty { parts.append(position) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    // MARK: - Progression

    private func progressionCard(_ detail: CoachPlayerDetail) -> some View {
        Card {
            VStack(alignment: .leading, spacing: DS.Spacing.s16) {
                Eyebrow(text: "Progression")
                HStack(spacing: DS.Spacing.s12) {
                    metric(value: "\(detail.xp)", label: "XP")
                    divider
                    metric(value: "\(detail.streak)", label: "Streak")
                    divider
                    metric(value: "\(detail.streakPB)", label: "Best")
                }
                Hairline()
                HStack {
                    Text("Last trained")
                        .style(.callout)
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                    Spacer()
                    Text(CoachFormat.relative(detail.lastTrained))
                        .style(.callout)
                        .foregroundStyle(DS.Colors.Ink.secondary)
                }
            }
        }
    }

    private func metric(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .style(.num(size: 26))
                .foregroundStyle(DS.Colors.Ink.primary)
            Text(label.uppercased())
                .style(.micro)
                .foregroundStyle(DS.Colors.Ink.quaternary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var divider: some View {
        Rectangle()
            .fill(DS.Colors.Line.hairline)
            .frame(width: 1, height: 32)
    }

    // MARK: - Mastery

    private func masterySection(_ detail: CoachPlayerDetail) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s12) {
            HStack {
                Eyebrow(text: "Mastery")
                Spacer()
                Text("\(detail.totalMastered) mastered")
                    .style(.micro)
                    .foregroundStyle(DS.Colors.Ink.quaternary)
            }
            if detail.masteryByDiscipline.isEmpty {
                emptyLine("No drills mastered yet.")
            } else {
                Card(padding: DS.Spacing.s16) {
                    VStack(spacing: 0) {
                        ForEach(Array(detail.masteryByDiscipline.enumerated()), id: \.element.id) { index, item in
                            if index > 0 { Hairline() }
                            HStack {
                                Text(item.name)
                                    .style(.title3)
                                    .foregroundStyle(DS.Colors.Ink.primary)
                                Spacer()
                                Text("\(item.count)")
                                    .style(.title3)
                                    .foregroundStyle(DS.Colors.Ink.secondary)
                            }
                            .padding(.vertical, DS.Spacing.s12)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Training time

    private func trainingTimeSection(_ detail: CoachPlayerDetail) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s12) {
            Eyebrow(text: "Training Time")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DS.Spacing.s12) {
                timeCard(value: CoachFormat.minutes(detail.minutesAllTime), label: "All time")
                timeCard(value: "\(detail.sessionCount)", label: "Sessions")
                timeCard(value: CoachFormat.minutes(detail.minutes30d), label: "Last 30 days")
                timeCard(value: CoachFormat.minutes(detail.minutes7d), label: "Last 7 days")
            }
        }
    }

    private func timeCard(value: String, label: String) -> some View {
        Card(padding: DS.Spacing.s16) {
            VStack(alignment: .leading, spacing: DS.Spacing.s4) {
                Text(value)
                    .style(.title2)
                    .foregroundStyle(DS.Colors.Ink.primary)
                Text(label.uppercased())
                    .style(.micro)
                    .foregroundStyle(DS.Colors.Ink.quaternary)
            }
        }
    }

    // MARK: - Combine

    private func combineSection(_ detail: CoachPlayerDetail) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s12) {
            Eyebrow(text: "Latest Combine")
            Card(padding: DS.Spacing.s16) {
                VStack(spacing: 0) {
                    ForEach(Array(detail.combineLatest.enumerated()), id: \.element.id) { index, item in
                        if index > 0 { Hairline() }
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name)
                                    .style(.title3)
                                    .foregroundStyle(DS.Colors.Ink.primary)
                                Text(CoachFormat.shortDate(item.date))
                                    .style(.cap)
                                    .foregroundStyle(DS.Colors.Ink.quaternary)
                            }
                            Spacer()
                            Text(CoachFormat.combineValue(item.value, unit: item.unit))
                                .style(.title3)
                                .foregroundStyle(DS.Colors.Ink.secondary)
                        }
                        .padding(.vertical, DS.Spacing.s12)
                    }
                }
            }
        }
    }

    // MARK: - Game IQ

    private func gameIQSection(_ detail: CoachPlayerDetail) -> some View {
        Card(padding: DS.Spacing.s16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Game IQ")
                        .style(.title3)
                        .foregroundStyle(DS.Colors.Ink.primary)
                    Text("Lessons completed")
                        .style(.cap)
                        .foregroundStyle(DS.Colors.Ink.quaternary)
                }
                Spacer()
                Text("\(detail.gameIQCompleted)")
                    .style(.num(size: 24))
                    .foregroundStyle(DS.Colors.Ink.secondary)
            }
        }
    }

    // MARK: - History

    /// Up to 500 sessions. This used to be a plain `ForEach` inside a non-lazy
    /// stack, so every row was built on appear and the whole history sat on
    /// screen with no way to narrow it.
    private func historySection(_ detail: CoachPlayerDetail) -> some View {
        // Bound once per body pass. The filter and the month bucketing walk the
        // same 500 items, and the hero counts, the match line and the ForEach
        // would otherwise each redo that walk.
        let query = historyQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let isSearching = !query.isEmpty
        let matches = isSearching
            ? detail.history.filter { $0.drillTitle.lowercased().contains(query) }
            : detail.history
        let groups = historyGroups(matches)
        let totalMinutes = detail.history.reduce(0) { $0 + $1.durationSec } / 60

        return VStack(alignment: .leading, spacing: DS.Spacing.s12) {
            // Unlike the rename browser this collapsing was modelled on, this is
            // read-only data the coach opened the screen to see. Collapsing all
            // of it would show them a stack of headers and nothing else, so the
            // newest month starts open and the rest stay tucked away.
            Color.clear.frame(height: 0).onAppear {
                if historyExpanded.isEmpty, let newest = groups.first {
                    historyExpanded.insert(newest.id)
                }
            }
            Eyebrow(text: "Session History")

            if detail.history.isEmpty {
                emptyLine("No sessions logged yet.")
            } else {
                historyHero(sessions: detail.history.count, minutes: totalMinutes)
                historySearchField

                if isSearching {
                    Text("\(matches.count) match\(matches.count == 1 ? "" : "es")")
                        .style(.micro)
                        .foregroundStyle(DS.Colors.Ink.quaternary)
                }

                if groups.isEmpty {
                    Text("Nothing matches “\(historyQuery)”.")
                        .style(.callout)
                        .foregroundStyle(DS.Colors.Ink.quaternary)
                        .padding(.vertical, DS.Spacing.s16)
                }

                LazyVStack(alignment: .leading, spacing: DS.Spacing.s8) {
                    ForEach(groups) { group in
                        historyGroupBlock(group, isSearching: isSearching)
                    }
                }
            }
        }
    }

    /// Counts before rows — a coach opening a two-year history should get the
    /// shape of it first, the way the rename browser does.
    private func historyHero(sessions: Int, minutes: Int) -> some View {
        Card(padding: DS.Spacing.s16) {
            HStack(spacing: DS.Spacing.s12) {
                SectionIcon(systemName: "clock.arrow.circlepath")
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(sessions) session\(sessions == 1 ? "" : "s")")
                        .style(.title3)
                        .foregroundStyle(DS.Colors.Ink.primary)
                    Text("\(CoachFormat.minutes(minutes)) logged · open a month to browse")
                        .style(.micro)
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var historySearchField: some View {
        HStack(spacing: DS.Spacing.s8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DS.Colors.Ink.quaternary)
            TextField("", text: $historyQuery, prompt: Text("Search sessions by drill")
                .foregroundColor(DS.Colors.Ink.quaternary))
                .style(.body)
                .foregroundStyle(DS.Colors.Ink.primary)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !historyQuery.isEmpty {
                Button { historyQuery = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(DS.Colors.Ink.quaternary)
                }
                .accessibilityLabel("Clear session search")
            }
        }
        .padding(.horizontal, DS.Spacing.s16)
        .frame(height: 48)
        .background(DS.Colors.Bg.card)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .stroke(DS.Colors.Line.hairline, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func historyGroupBlock(_ group: HistoryGroup, isSearching: Bool) -> some View {
        // While searching every month is open — hiding a match behind a
        // collapsed header would defeat the search.
        let isOpen = isSearching || historyExpanded.contains(group.id)

        VStack(alignment: .leading, spacing: DS.Spacing.s8) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(DS.Motion.standardSpring) {
                    if historyExpanded.contains(group.id) { historyExpanded.remove(group.id) }
                    else { historyExpanded.insert(group.id) }
                }
            } label: {
                HStack(spacing: DS.Spacing.s12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(group.title)
                            .style(.title3)
                            .foregroundStyle(DS.Colors.Ink.primary)
                        Text("\(group.items.count) session\(group.items.count == 1 ? "" : "s") · \(CoachFormat.minutes(group.minutes))")
                            .style(.micro)
                            .foregroundStyle(DS.Colors.Ink.quaternary)
                    }
                    Spacer(minLength: DS.Spacing.s8)
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
            .accessibilityLabel("\(group.title), \(group.items.count) sessions")
            .accessibilityHint(isOpen ? "Collapse" : "Expand")

            if isOpen {
                ForEach(group.items) { item in
                    historyRow(item)
                }
            }
        }
    }

    private func historyRow(_ item: SessionHistoryItem) -> some View {
        HStack(spacing: DS.Spacing.s12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.drillTitle)
                    .style(.callout)
                    .foregroundStyle(DS.Colors.Ink.primary)
                    .lineLimit(1)
                Text(CoachFormat.shortDate(item.date))
                    .style(.cap)
                    .foregroundStyle(DS.Colors.Ink.quaternary)
            }
            Spacer(minLength: DS.Spacing.s8)
            if let rating = item.feltRating {
                Text("\(rating)/5")
                    .style(.cap)
                    .foregroundStyle(DS.Colors.Ink.tertiary)
            }
            Text(CoachFormat.duration(item.durationSec))
                .style(.foot)
                .foregroundStyle(DS.Colors.Ink.secondary)
        }
        .padding(.vertical, DS.Spacing.s12)
        .padding(.horizontal, DS.Spacing.s16)
        .background(DS.Colors.Bg.card)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .stroke(DS.Colors.Line.hairline, lineWidth: 1)
        )
    }

    /// Sessions bucketed by calendar month. The rows arrive ordered
    /// `completed_at desc`, so preserving encounter order keeps the newest month
    /// first without paying for a second sort of 500 items.
    private func historyGroups(_ items: [SessionHistoryItem]) -> [HistoryGroup] {
        // Bucketed on year+month components, then formatted once per bucket.
        // Formatting per item meant 500 `DateFormatter.string` calls on every
        // body pass — including every keystroke in the focus field, the note
        // field and the search box directly above this.
        let calendar = Calendar.current
        var order: [DateComponents] = []
        var buckets: [DateComponents: [SessionHistoryItem]] = [:]
        for item in items {
            let key = calendar.dateComponents([.year, .month], from: item.date)
            if buckets[key] == nil {
                order.append(key)
                buckets[key] = []
            }
            buckets[key]?.append(item)
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return order.map { key in
            let title = calendar.date(from: key).map(formatter.string(from:)) ?? "Earlier"
            return HistoryGroup(title: title, items: buckets[key] ?? [])
        }
    }

    // MARK: - States

    private func emptyLine(_ text: String) -> some View {
        Text(text)
            .style(.callout)
            .foregroundStyle(DS.Colors.Ink.tertiary)
            .padding(.vertical, DS.Spacing.s8)
    }

    private var offlineBanner: some View {
        HStack(spacing: DS.Spacing.s8) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 13, weight: .semibold))
            Text("You're offline — connect to load this player.")
                .style(.foot)
            Spacer(minLength: 0)
        }
        .foregroundStyle(DS.Colors.Ink.tertiary)
        .padding(DS.Spacing.s12)
        .background(DS.Colors.Bg.card)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .stroke(DS.Colors.Line.hairline, lineWidth: 1)
        )
    }

    private var loadingState: some View {
        VStack(spacing: DS.Spacing.s12) {
            ProgressView()
                .controlSize(.large)
                .tint(DS.Colors.Ink.tertiary)
            Text("Loading…")
                .style(.callout)
                .foregroundStyle(DS.Colors.Ink.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.s64)
    }

    private var retryState: some View {
        VStack(spacing: DS.Spacing.s12) {
            Text("Couldn't load")
                .style(.title3)
                .foregroundStyle(DS.Colors.Ink.primary)
            Text("Pull to retry.")
                .style(.callout)
                .foregroundStyle(DS.Colors.Ink.tertiary)
            Button("Retry") {
                Task { await model.loadDetail(for: player, context: modelContext, force: true) }
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(DS.Colors.Ink.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.s64)
    }
}

/// Small formatting helpers shared across Coach Mode.
enum CoachFormat {
    static func initials(_ name: String) -> String {
        let parts = name.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first }.map(String.init)
        let joined = letters.joined().uppercased()
        return joined.isEmpty ? "MF" : joined
    }

    static func minutes(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        let remainder = minutes % 60
        return remainder == 0 ? "\(hours)h" : "\(hours)h \(remainder)m"
    }

    static func duration(_ seconds: Int) -> String {
        let mins = max(0, seconds) / 60
        return minutes(mins == 0 && seconds > 0 ? 1 : mins)
    }

    static func relative(_ date: Date?) -> String {
        guard let date else { return "Never" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    static func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    static func combineValue(_ value: Double, unit: String) -> String {
        guard value.isFinite else { return unit.isEmpty ? "—" : "— \(unit)" }
        // Not `String(Int(value))` — that traps above Int.max, and this renders
        // whatever a player managed to type into an unbounded score field.
        let isWhole = value.rounded() == value
        let number = isWhole ? String(format: "%.0f", value) : String(format: "%.1f", value)
        return unit.isEmpty ? number : "\(number) \(unit)"
    }

    /// Turn a "yyyy-MM" key into a readable "July 2026" label.
    static func monthLabel(_ key: String) -> String {
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM"
        guard let date = parser.date(from: key) else { return key }
        let out = DateFormatter()
        out.dateFormat = "MMMM yyyy"
        return out.string(from: date)
    }
}
