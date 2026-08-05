//
//  ProgressReportBuilderView.swift
//  MFElite
//
//  A full-screen, coach-editable progress report builder. Loads (or prefills)
//  the report for a player + period, lets the coach edit / reorder / toggle /
//  add sections, then renders a paginated, white-background PDF to share with
//  parents. Persists to progress_reports (draft or final).
//

import SwiftUI
import UIKit
import MessageUI

struct ProgressReportBuilderView: View {
    let player: RosterPlayer
    let detail: CoachPlayerDetail

    @Environment(\.dismiss) private var dismiss
    @State private var sections: [ReportSection] = []
    @State private var serverSections: [ReportSection] = []
    @State private var reportID: String?
    @State private var status: String = "draft"
    @State private var period: String = ""
    @State private var loaded = false
    @State private var isSaving = false
    @State private var shareURL: URL?
    @State private var showShare = false
    @State private var restoredDraft = false
    @State private var autosaveTask: Task<Void, Never>?
    @State private var mailRequest: MailRequest?
    @State private var showContactPicker = false
    @State private var pendingParentEmail = ""
    @State private var copied = false

    /// Current month formatted "MMMM yyyy" (e.g. "July 2026").
    private var defaultPeriod: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: Date())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.s16) {
                    if restoredDraft { restoredBanner }
                    ForEach($sections) { $section in
                        sectionCard($section)
                    }
                    addButtons
                    parentActions
                }
                .padding(.horizontal, DS.Spacing.s20)
                .padding(.top, DS.Spacing.s16)
                .padding(.bottom, 120)
            }
            .background(DS.Colors.Bg.base)
            .scrollIndicators(.hidden)
            .navigationTitle(period.isEmpty ? "Report" : period)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { Task { await save(newStatus: "draft") } }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Finalize & PDF") { Task { await finalizeAndShare() } }
                        .disabled(isSaving)
                        .fontWeight(.semibold)
                }
            }
            .task {
                if period.isEmpty { period = defaultPeriod }
                if !loaded {
                    await load()
                    loaded = true
                }
            }
            .onChange(of: sections) { _, _ in
                if loaded { scheduleAutosave() }
            }
            .sheet(isPresented: $showShare) {
                if let shareURL {
                    ShareSheet(items: [shareURL])
                        .presentationDetents([.medium, .large])
                }
            }
            .sheet(item: $mailRequest) { request in
                MailComposeView(request: request)
                    .ignoresSafeArea()
            }
            .sheet(isPresented: $showContactPicker) {
                ContactEmailPicker { email in
                    pendingParentEmail = email
                    Task { await emailToParent() }
                }
                .ignoresSafeArea()
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Restore banner

    private var restoredBanner: some View {
        HStack(spacing: DS.Spacing.s12) {
            Image(systemName: "arrow.uturn.backward.circle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(DS.Colors.Gold.base)
            VStack(alignment: .leading, spacing: 2) {
                Text("Restored unsaved edits")
                    .style(.foot)
                    .fontWeight(.semibold)
                    .foregroundStyle(DS.Colors.Ink.primary)
                Text("We recovered changes from your last session.")
                    .style(.cap)
                    .foregroundStyle(DS.Colors.Ink.tertiary)
            }
            Spacer(minLength: 0)
            Button("Discard") { discardDraft() }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DS.Colors.Ink.secondary)
        }
        .padding(DS.Spacing.s12)
        .background(DS.Colors.Bg.card)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(DS.Colors.Gold.base.opacity(0.4), lineWidth: 1))
    }

    // MARK: - Parent actions (email / copy)

    private var parentActions: some View {
        VStack(spacing: DS.Spacing.s12) {
            Hairline()
            if MFMailComposeViewController.canSendMail() {
                actionRow(icon: "envelope.fill", title: "Email to parent",
                          subtitle: "Attach the PDF and open Mail") {
                    Task { await emailToParent() }
                }
                actionRow(icon: "person.crop.circle.fill", title: "Choose parent from Contacts",
                          subtitle: "Pick an email, then attach the PDF") {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showContactPicker = true
                }
            }
            actionRow(icon: copied ? "checkmark.circle.fill" : "doc.on.doc.fill",
                      title: copied ? "Copied" : "Copy text summary",
                      subtitle: "Paste into a message or note") {
                copySummary()
            }
        }
    }

    private func actionRow(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.s12) {
                SectionIcon(systemName: icon, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .style(.title3)
                        .foregroundStyle(DS.Colors.Ink.primary)
                    Text(subtitle)
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

    // MARK: - Load / prefill

    private func load() async {
        if let existing = await ProgressReportStore.load(playerUserID: player.id, period: period) {
            reportID = existing.id
            status = existing.status
            serverSections = existing.sections.isEmpty ? prefilled() : existing.sections
        } else {
            serverSections = prefilled()
        }
        // Restore any locally-cached unsaved edits that differ from the server.
        if let draft = ReportDraftCache.load(playerID: player.id, period: period),
           draft.sections != serverSections {
            sections = draft.sections
            if reportID == nil { reportID = draft.reportID }
            restoredDraft = true
        } else {
            sections = serverSections
        }
    }

    /// Debounced local autosave — persists edits to the device ~1s after typing stops.
    private func scheduleAutosave() {
        autosaveTask?.cancel()
        let snapshot = sections
        let currentID = reportID
        autosaveTask = Task {
            try? await Task.sleep(for: .seconds(1))
            if Task.isCancelled { return }
            ReportDraftCache.save(ReportDraft(
                playerID: player.id, period: period,
                reportID: currentID, sections: snapshot, savedAt: Date()
            ))
        }
    }

    private func discardDraft() {
        autosaveTask?.cancel()
        sections = serverSections
        ReportDraftCache.clear(playerID: player.id, period: period)
        restoredDraft = false
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }

    // MARK: - Parent email / copy

    private func emailToParent() async {
        await save(newStatus: status == "final" ? "final" : "draft")
        guard let url = generatePDF() else { return }
        let subject = "\(player.displayName) — Progress Report (\(period))"
        let body = """
        Hi,

        Attached is \(ShareText.firstName(player.displayName))'s progress report for \(period).

        — MF Elite Training Academy
        """
        mailRequest = MailRequest(
            recipient: pendingParentEmail, subject: subject, body: body,
            attachmentURL: url, attachmentFilename: filename
        )
    }

    private func copySummary() {
        UIPasteboard.general.string = textSummary()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        copied = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            copied = false
        }
    }

    private func textSummary() -> String {
        var lines: [String] = ["\(player.displayName) — \(period)", ""]
        for section in sections where section.included {
            if section.kind == .ratings {
                lines.append(section.title + ":")
                for row in section.ratings {
                    let clamped = max(1, min(4, row.score))
                    lines.append("  • \(row.label): \(ReportSection.ratingScale[clamped])")
                }
            } else if !section.body.isEmpty {
                lines.append("\(section.title): \(section.body)")
            }
            lines.append("")
        }
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The default template with auto sections filled from live data.
    private func prefilled() -> [ReportSection] {
        var template = ReportSection.defaultTemplate(playerName: player.displayName, period: period)
        for index in template.indices {
            switch template[index].kind {
            case .autoCombine:
                template[index].body = autoCombineBody()
            case .autoConsistency:
                template[index].body = autoConsistencyBody()
            case .autoMastery:
                template[index].body = autoMasteryBody()
            case .freeText where template[index].title == "Training Focus This Period":
                template[index].body = detail.coachFocus
            default:
                break
            }
        }
        return template
    }

    private func autoCombineBody() -> String {
        guard !detail.combineProgress.isEmpty else { return "No combine tests recorded yet." }
        return detail.combineProgress.map { item in
            "\(item.label) — Baseline \(CoachFormat.combineValue(item.baseline, unit: item.unit)) → Latest \(CoachFormat.combineValue(item.latest, unit: item.unit)) · Best \(CoachFormat.combineValue(item.best, unit: item.unit))"
        }.joined(separator: "\n")
    }

    private func autoConsistencyBody() -> String {
        "\(detail.sessionCount) sessions · \(detail.minutesAllTime) min · \(detail.streakPB)-day best streak"
    }

    private func autoMasteryBody() -> String {
        guard !detail.masteryByDiscipline.isEmpty else { return "No skills mastered yet." }
        return detail.masteryByDiscipline
            .map { "\($0.name): \($0.count) mastered" }
            .joined(separator: "\n")
    }

    // MARK: - Section editor

    @ViewBuilder
    private func sectionCard(_ section: Binding<ReportSection>) -> some View {
        let kind = section.wrappedValue.kind
        Card(padding: DS.Spacing.s16) {
            VStack(alignment: .leading, spacing: DS.Spacing.s12) {
                HStack(spacing: DS.Spacing.s12) {
                    Toggle("Include", isOn: section.included)
                        .labelsHidden()
                        .tint(DS.Colors.Gold.base)
                    TextField("Section title", text: section.title)
                        .style(.title3)
                        .foregroundStyle(DS.Colors.Ink.primary)
                    Spacer(minLength: 0)
                }

                if kind == .ratings {
                    ForEach(section.ratings) { $row in
                        ratingEditor($row)
                    }
                } else {
                    TextField("Write here…", text: section.body, axis: .vertical)
                        .style(.body)
                        .foregroundStyle(DS.Colors.Ink.secondary)
                        .lineLimit(2...12)
                }

                HStack(spacing: DS.Spacing.s8) {
                    Button {
                        move(section.wrappedValue.id, by: -1)
                    } label: {
                        Image(systemName: "arrow.up")
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Move section up")
                    Button {
                        move(section.wrappedValue.id, by: 1)
                    } label: {
                        Image(systemName: "arrow.down")
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Move section down")
                    Spacer()
                    Button(role: .destructive) {
                        remove(section.wrappedValue.id)
                    } label: {
                        Image(systemName: "trash")
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Delete section")
                }
                .buttonStyle(.plain)
                .foregroundStyle(DS.Colors.Ink.tertiary)
                .font(.system(size: 15, weight: .semibold))
            }
            .opacity(section.wrappedValue.included ? 1 : 0.5)
        }
    }

    private func ratingEditor(_ row: Binding<ReportSection.RatingRow>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("Label", text: row.label)
                .style(.foot)
                .foregroundStyle(DS.Colors.Ink.primary)
            Picker("", selection: row.score) {
                ForEach(1...4, id: \.self) { level in
                    Text(ReportSection.ratingScale[level]).tag(level)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.vertical, 4)
    }

    private var addButtons: some View {
        HStack(spacing: DS.Spacing.s12) {
            addButton(title: "Add text section") {
                sections.append(ReportSection(kind: .freeText, title: "New Section"))
            }
            addButton(title: "Add ratings section") {
                sections.append(ReportSection(
                    kind: .ratings, title: "New Ratings",
                    ratings: [.init(label: "Skill", score: 2)]
                ))
            }
        }
    }

    private func addButton(title: String, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            HStack(spacing: DS.Spacing.s4) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .bold))
                Text(title)
                    .style(.foot)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(DS.Colors.Ink.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.s12)
            .background(DS.Colors.Bg.card)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(DS.Colors.Line.hairline, lineWidth: 1))
        }
        .buttonStyle(PressableButtonStyle())
    }

    private func move(_ id: UUID, by offset: Int) {
        guard let index = sections.firstIndex(where: { $0.id == id }) else { return }
        let target = index + offset
        guard sections.indices.contains(target) else { return }
        sections.swapAt(index, target)
    }

    private func remove(_ id: UUID) {
        sections.removeAll { $0.id == id }
    }

    // MARK: - Persist

    private func save(newStatus: String) async {
        isSaving = true
        let ok = await ProgressReportStore.save(
            id: reportID, playerUserID: player.id, period: period,
            sections: sections, status: newStatus
        )
        if ok {
            status = newStatus
            // Fetch the generated id after a first insert so later saves update
            // the same row instead of creating duplicates.
            if reportID == nil,
               let existing = await ProgressReportStore.load(playerUserID: player.id, period: period) {
                reportID = existing.id
            }
            // The report is now safely on the server — clear the local draft.
            serverSections = sections
            ReportDraftCache.clear(playerID: player.id, period: period)
            restoredDraft = false
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        isSaving = false
    }

    private func finalizeAndShare() async {
        await save(newStatus: "final")
        if let url = generatePDF() {
            shareURL = url
            showShare = true
        }
    }

    // MARK: - PDF

    private var filename: String {
        let safeName = player.displayName.replacingOccurrences(of: " ", with: "-")
        let safePeriod = period.replacingOccurrences(of: " ", with: "-")
        return "MFElite-Report-\(safeName)-\(safePeriod).pdf"
    }

    /// Group the included sections into pages by an estimated ~700pt budget.
    /// Each rendered page is sized to its natural content height, so the budget
    /// only controls how many sections share a page — nothing ever clips.
    private func paginate(_ input: [ReportSection]) -> [[ReportSection]] {
        var pages: [[ReportSection]] = []
        var current: [ReportSection] = []
        var height: CGFloat = 0
        for section in input where section.included {
            let sectionHeight = estimatedHeight(section)
            if height + sectionHeight > 700, !current.isEmpty {
                pages.append(current)
                current = []
                height = 0
            }
            current.append(section)
            height += sectionHeight
        }
        if !current.isEmpty { pages.append(current) }
        return pages.isEmpty ? [[]] : pages
    }

    private func estimatedHeight(_ section: ReportSection) -> CGFloat {
        switch section.kind {
        case .header, .signature:
            return 90
        case .ratings:
            return 54 + CGFloat(section.ratings.count) * 34
        default:
            let charLines = section.body.count / 60
            let hardLines = section.body.components(separatedBy: "\n").count
            let lines = max(1, charLines + hardLines)
            return 64 + CGFloat(lines) * 20
        }
    }

    private func generatePDF() -> URL? {
        let pages = paginate(sections)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        var box = CGRect(x: 0, y: 0, width: 540, height: 720)
        guard let pdf = CGContext(url as CFURL, mediaBox: &box, nil) else { return nil }
        for (index, pageSections) in pages.enumerated() {
            let page = ReportPDFPage(
                sections: pageSections,
                showHeader: index == 0,
                playerName: player.displayName,
                period: period
            )
            let renderer = ImageRenderer(content: page)
            renderer.scale = 3.0
            renderer.render { size, drawInContext in
                let mediaBox = CGRect(origin: .zero, size: size)
                let info = [kCGPDFContextMediaBox as String: mediaBox] as CFDictionary
                pdf.beginPDFPage(info)
                drawInContext(pdf)
                pdf.endPDFPage()
            }
        }
        pdf.closePDF()
        return url
    }
}

// MARK: - PDF page (white, printed for parents)

/// One white printed page: an optional MF letterhead plus its sections flowed
/// in order. Fixed 540pt content width; height flows to fit.
private struct ReportPDFPage: View {
    let sections: [ReportSection]
    let showHeader: Bool
    let playerName: String
    let period: String

    private let ink = Color.black
    private let sub = Color.black.opacity(0.55)
    private let line = Color.black.opacity(0.12)
    private let gold = Color(hex: "#E8B84B")
    private let emptyChip = Color.black.opacity(0.08)

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if showHeader { header }
            ForEach(sections) { section in
                sectionView(section)
            }
        }
        .padding(36)
        .frame(width: 540, alignment: .leading)
        .background(Color.white)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Image("mf-logo-black")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 14)
                    .accessibilityLabel("MF Elite")
                Spacer()
                Text("PLAYER PROGRESS REPORT")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(sub)
            }
            Rectangle().fill(line).frame(height: 1)
        }
    }

    @ViewBuilder
    private func sectionView(_ section: ReportSection) -> some View {
        switch section.kind {
        case .header:
            VStack(alignment: .leading, spacing: 4) {
                Text(section.title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(ink)
                if !section.body.isEmpty {
                    Text(section.body)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(sub)
                }
            }
        case .ratings:
            VStack(alignment: .leading, spacing: 10) {
                Text(section.title.uppercased())
                    .font(.system(size: 12, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(sub)
                ForEach(section.ratings) { row in
                    ratingRow(row)
                }
            }
        case .signature:
            VStack(alignment: .leading, spacing: 6) {
                Rectangle().fill(line).frame(height: 1)
                Text(section.body.isEmpty ? section.title : section.body)
                    .font(.system(size: 18, weight: .bold))
                    .italic()
                    .foregroundStyle(ink)
                Text(section.title.uppercased())
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(sub)
            }
        default:
            VStack(alignment: .leading, spacing: 6) {
                Text(section.title.uppercased())
                    .font(.system(size: 12, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(sub)
                Text(section.body.isEmpty ? "—" : section.body)
                    .font(.system(size: 13))
                    .foregroundStyle(ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func ratingRow(_ row: ReportSection.RatingRow) -> some View {
        let clamped = max(1, min(4, row.score))
        return HStack {
            Text(row.label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(ink)
            Spacer()
            HStack(spacing: 4) {
                ForEach(1...4, id: \.self) { level in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(level <= clamped ? gold : emptyChip)
                        .frame(width: 16, height: 16)
                }
            }
            Text(ReportSection.ratingScale[clamped])
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(sub)
                .frame(width: 78, alignment: .leading)
        }
    }
}
