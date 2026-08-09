//
//  DrillDetailView.swift
//  MFElite
//
//  The canonical drill template — every drill renders into this structure.
//

import SwiftUI
import SwiftData
import AVKit

/// Navigation route carrying a drill plus its parents for breadcrumb context.
struct DrillRoute: Hashable, Identifiable {
    let discipline: Discipline
    let category: Category
    let level: MasteryLevel
    let drill: Drill

    var id: String { drill.id }
}

struct DrillDetailView: View {
    let drill: Drill
    let level: MasteryLevel
    let category: Category
    let discipline: Discipline

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(SubscriptionService.self) private var subscription
    @Query private var progress: [DrillProgress]
    @Query private var curriculumEdits: [CurriculumEditCache]
    @Query private var sessions: [SessionLogEntry]
    @Query private var notes: [DrillNote]
    @State private var activeSession: TrainingQueue?
    @State private var showLogConfirm = false
    @State private var lastLogResult: QuickLog.Result?
    @State private var favorites = FavoritesStore.shared
    @State private var showNoteEditor = false
    @State private var shareText: ShareableText?
    @State private var streakMilestone: StreakMilestone?

    /// Vertical space taken by the floating glass tab bar (68pt height + 26pt
    /// bottom offset — mirrors CustomTabBar's metrics) so the pinned CTA
    /// clears it instead of hiding behind it.
    private let tabBarClearance: CGFloat = 94

    /// When a coach last published a change to this drill, if ever.
    ///
    /// Players train off this content, so an edit landing silently — a changed
    /// rep count, a rewritten coaching point — is worth surfacing. It also
    /// tells the coach their publish actually took.
    private var lastUpdated: Date? {
        curriculumEdits.first { $0.drillID == drill.id }?.updatedAt
    }

    /// True when this drill sits in a level the current plan doesn't include.
    ///
    /// Gating used to live only in `LevelView`, so the Drill Library, Favorites
    /// and the Progress-tab ring rows all linked straight past it and a free
    /// player could open and train any Level 2–5 drill. This screen is the one
    /// place every one of those routes converges, so the check belongs here.
    private var isLocked: Bool {
        subscription.isLevelNumberLocked(level.number)
    }

    private var drillProgress: DrillProgress? {
        progress.first { $0.drillID == drill.id }
    }

    private var drillNote: DrillNote? {
        notes.first { $0.drillID == drill.id }
    }

    // MARK: - Personal history (this drill)

    private var drillSessions: [SessionLogEntry] {
        sessions.filter { $0.drillID == drill.id }
    }
    private var timesTrained: Int { drillSessions.count }
    private var lastTrained: Date? { drillSessions.map(\.completedAt).max() }
    private var totalMinutes: Int { drillSessions.map(\.durationSec).reduce(0, +) / 60 }
    private var avgFeltRating: Double? {
        let r = drillSessions.compactMap(\.feltRating)
        return r.isEmpty ? nil : Double(r.reduce(0, +)) / Double(r.count)
    }

    private var viewModel: DrillDetailViewModel {
        DrillDetailViewModel(
            drill: drill,
            level: level,
            category: category,
            discipline: discipline,
            passesLogged: drillProgress?.passesLogged ?? 0,
            isMastered: drillProgress?.isMastered ?? false
        )
    }

    var body: some View {
        let vm = viewModel
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                topBar
                titleBlock(vm)
                statStrip(vm)
                referencePhotoSection
                demoVideoSection
                historySection
                DrillScoreSection(drillID: drill.id, drillTitle: drill.title)
                    .padding(.horizontal, DS.Spacing.s20)
                    .padding(.top, DS.Spacing.s24)
                if let setup = drill.setupSummary {
                    setupSection(setup)
                }
                purposeSection
                if drill.isMentalExercise {
                    if !drill.steps.isEmpty {
                        stepsSection
                    }
                    coachingSection
                    if let prompt = drill.journalPrompt {
                        journalPromptSection(prompt)
                    }
                } else {
                    if !drill.instructions.isEmpty {
                        instructionsSection
                    }
                    coachingSection
                    challengeSection
                }
                notesSection
                accountabilitySection(vm)
                updatedFooter
            }
            .padding(.bottom, DS.Spacing.s24)
        }
        .safeAreaInset(edge: .bottom) {
            bottomCTA(vm)
        }
        // The pinned CTA owns the bottom band on this screen, so the app-wide
        // floating search button would sit on its trailing end.
        .suppressesFloatingSearch()
        .background(DS.Colors.Bg.base)
        .scrollIndicators(.hidden)
        .navigationBarHidden(true)
        .fullScreenCover(item: $activeSession) { queue in
            SessionPlayerView(queue: queue)
        }
        .fullScreenCover(item: $streakMilestone) { milestone in
            StreakMilestoneView(days: milestone.days, onClose: {})
        }
        .sheet(isPresented: $showNoteEditor) {
            DrillNoteEditorView(existing: drillNote?.text ?? "") { newText in
                saveNote(newText)
            }
        }
        .sheet(item: $shareText) { item in
            ShareSheet(items: [item.text])
                .presentationDetents([.medium, .large])
        }
        .confirmationDialog(
            drill.isMentalExercise ? "Log this exercise?" : "Log this drill?",
            isPresented: $showLogConfirm,
            titleVisibility: .visible
        ) {
            Button("Log as done") { logInstantly() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Records “\(drill.title)” without the timer — XP, streak and rings all count.")
        }
        .overlay(alignment: .bottom) {
            if let result = lastLogResult {
                loggedToast(result)
                    .padding(.bottom, DS.Spacing.s12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    /// Log this single drill instantly, no timer, then confirm with a toast.
    private func logInstantly() {
        // Belt and braces: the CTA is already hidden when locked, but this is
        // the other way a completion can be recorded from this screen.
        guard !isLocked else {
            subscription.presentPaywall()
            return
        }
        let ctx = DrillContext(drill: drill, level: level, category: category, discipline: discipline)
        let result = QuickLog.logDrills([ctx], source: .single, sourceName: nil, context: context)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(DS.Motion.standardSpring) { lastLogResult = result }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            withAnimation(DS.Motion.standardSpring) { lastLogResult = nil }
        }
        celebrateStreakMilestoneIfCrossed(result.newStreak)
    }

    /// Presents the once-only streak milestone celebration after the logged toast.
    private func celebrateStreakMilestoneIfCrossed(_ streak: Int) {
        guard StreakMilestones.pending(for: streak) else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if let days = StreakMilestones.claim(for: streak) {
                streakMilestone = StreakMilestone(days: days)
            }
        }
    }

    private func loggedToast(_ result: QuickLog.Result) -> some View {
        HStack(spacing: DS.Spacing.s12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(DS.Colors.Ground.primary)
            VStack(alignment: .leading, spacing: 2) {
                Text("Logged")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(DS.Colors.Ground.primary)
                Text("+\(result.xpEarned) XP · \(result.newStreak)-day streak")
                    .style(.micro)
                    .foregroundStyle(Color.black.opacity(0.6))
            }
        }
        .padding(.vertical, DS.Spacing.s12)
        .padding(.horizontal, DS.Spacing.s20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.pill))
        .pillLightElevation()
        .padding(.horizontal, DS.Spacing.s20)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Logged. \(result.xpEarned) XP earned. \(result.newStreak) day streak.")
    }

    /// Builds a session queue starting at this drill, followed by the remaining
    /// drills of the same level in order (so "Next drill" always has somewhere to go).
    private func makeQueue() -> TrainingQueue {
        let ordered = level.drills.sorted { $0.sortIndex < $1.sortIndex }
        let startIndex = ordered.firstIndex { $0.id == drill.id } ?? 0
        let chain = Array(ordered[startIndex...])
        let items = chain.map {
            DrillContext(drill: $0, level: level, category: category, discipline: discipline)
        }
        return TrainingQueue(items: items, source: .single, sourceName: nil)
    }

    // MARK: - 1. Top Bar

    private var topBar: some View {
        HStack(spacing: DS.Spacing.s8) {
            IconButton(systemName: "chevron.left", size: 36) {
                dismiss()
            }
            Spacer()
            shareButton
            favoriteButton
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s12)
    }

    private var shareButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            shareText = ShareableText(text: drillShareText())
        } label: {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(DS.Colors.Ink.secondary)
                .frame(width: 36, height: 36)
                .background(DS.Colors.Bg.raised)
                .clipShape(Circle())
                .overlay(Circle().stroke(DS.Colors.Line.hairline, lineWidth: 1))
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel("Share drill")
    }

    /// Compose a plain-text summary of this drill for sharing.
    private func drillShareText() -> String {
        var lines: [String] = []
        lines.append(drill.title)
        lines.append("\(discipline.name) · \(category.name) · Level \(level.number)")
        lines.append("")

        let space = drill.space?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let equipment = drill.equipment.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if !equipment.isEmpty || !space.isEmpty {
            lines.append("SET-UP")
            if !equipment.isEmpty { lines.append("Equipment: \(equipment.joined(separator: ", "))") }
            if !space.isEmpty { lines.append("Space: \(space)") }
            lines.append("")
        }

        let steps = drill.isMentalExercise ? drill.steps : drill.instructions
        if !steps.isEmpty {
            lines.append(drill.isMentalExercise ? "THE EXERCISE" : "HOW TO DO IT")
            for (index, step) in steps.enumerated() {
                lines.append("\(index + 1). \(step)")
            }
            lines.append("")
        }

        if !drill.coachingPoints.isEmpty {
            lines.append("COACHING POINTS")
            for point in drill.coachingPoints {
                lines.append("• \(point)")
            }
            lines.append("")
        }

        lines.append("— shared from MF Elite")
        return lines.joined(separator: "\n")
    }

    private var favoriteButton: some View {
        let isFav = favorites.isFavoriteDrill(drill.id)
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(DS.Motion.standardSpring) { favorites.toggleDrill(drill.id) }
        } label: {
            Image(systemName: isFav ? "heart.fill" : "heart")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isFav ? DS.Colors.Ink.primary : DS.Colors.Ink.secondary)
                .frame(width: 36, height: 36)
                .background(DS.Colors.Bg.raised)
                .clipShape(Circle())
                .overlay(Circle().stroke(DS.Colors.Line.hairline, lineWidth: 1))
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(isFav ? "Remove from favorites" : "Add to favorites")
    }

    // MARK: - 2. Title Block

    private func titleBlock(_ vm: DrillDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(discipline.name) · \(category.name) · Level \(level.number)")
                .style(.micro)
                .foregroundStyle(DS.Colors.Ink.tertiary)

            Text(drill.title)
                .style(.title1)
                .foregroundStyle(DS.Colors.Ink.primary)
                .padding(.top, DS.Spacing.s8)

            Text(vm.drillCode)
                .style(.micro)
                .foregroundStyle(DS.Colors.Ink.quaternary)
                .padding(.top, DS.Spacing.s4 + 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s20)
    }

    // MARK: - Reference photo (coach-uploaded)

    /// A coach-uploaded still reference image, shown only when the drill has one.
    @ViewBuilder
    private var referencePhotoSection: some View {
        if let urlString = drill.imageURL, let url = URL(string: urlString), !urlString.isEmpty {
            VStack(alignment: .leading, spacing: DS.Spacing.s8) {
                Eyebrow(text: "Reference photo")
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        Rectangle().fill(DS.Colors.Bg.raised)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 210)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
            }
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.top, DS.Spacing.s24)
        }
    }

    // MARK: - Demo video (coach-uploaded)

    /// A 16:9 player for the coach-uploaded demo video, shown only when the drill
    /// has a usable video URL (synced down via the curriculum overlay).
    @ViewBuilder
    private var demoVideoSection: some View {
        if let raw = drill.videoURL,
           !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let url = URL(string: raw) {
            VStack(alignment: .leading, spacing: DS.Spacing.s8) {
                Eyebrow(text: "Demo video")
                DrillDemoVideoView(url: url)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.md)
                            .stroke(DS.Colors.Line.hairline, lineWidth: 1)
                    )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.top, DS.Spacing.s20)
        }
    }

    private var setDurationLabel: String {
        let totalSec = drill.durationSec
        let sets = max(1, drill.sets)
        let perSet = totalSec / sets
        let minutes = perSet / 60
        let seconds = perSet % 60
        if seconds == 0 {
            return "\(minutes):00"
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    // MARK: - 3. Stat Strip

    private func statStrip(_ vm: DrillDetailViewModel) -> some View {
        VStack(spacing: 0) {
            Hairline()
            HStack(spacing: 0) {
                if drill.isMentalExercise {
                    statCell(value: "~\(vm.formattedDuration)", label: "Guide")
                    statDivider
                    statCell(value: "\(max(drill.steps.count, 1))", label: "Steps")
                    statDivider
                    statCell(value: kindLabel, label: "Type")
                } else {
                    statCell(value: vm.formattedDuration, label: "Duration")
                    statDivider
                    statCell(value: "\(drill.sets) × \(setDurationLabel)", label: "Sets")
                    statDivider
                    statCell(value: "+\(ProgressionRules.xpPerDrill) XP", label: "Earns")
                }
            }
            Hairline()
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s20)
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: DS.Spacing.s4) {
            Text(value)
                .font(DS.Typography.num(size: 18))
                .tracking(-0.6)
                .foregroundStyle(DS.Colors.Ink.primary)
            Eyebrow(text: label)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.s16 - 2)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(DS.Colors.Line.hairline)
            .frame(width: 1, height: 40)
    }

    // MARK: - Your History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: "YOUR HISTORY")
            Card {
                if timesTrained == 0 {
                    Text("Not trained yet — today's a good day.")
                        .style(.callout)
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    VStack(alignment: .leading, spacing: DS.Spacing.s16) {
                        HStack(spacing: 0) {
                            historyStat(value: "×\(timesTrained)", label: "Trained")
                            historyDivider
                            historyStat(value: lastTrainedLabel, label: "Last")
                            historyDivider
                            historyStat(value: "\(totalMinutes) min", label: "Total")
                        }
                        if let avg = avgFeltRating {
                            feltRow(avg: avg)
                        }
                    }
                }
            }
            .padding(.top, DS.Spacing.s12 + 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s24 + 4)
    }

    private var lastTrainedLabel: String {
        guard let last = lastTrained else { return "—" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: last, relativeTo: Date())
    }

    private func historyStat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s4) {
            Text(value)
                .font(DS.Typography.num(size: 17))
                .tracking(-0.4)
                .foregroundStyle(DS.Colors.Ink.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Eyebrow(text: label)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var historyDivider: some View {
        Rectangle()
            .fill(DS.Colors.Line.hairline)
            .frame(width: 1, height: 32)
            .padding(.horizontal, DS.Spacing.s12)
    }

    private func feltRow(avg: Double) -> some View {
        let rounded = Int(avg.rounded())
        return HStack(spacing: DS.Spacing.s8) {
            HStack(spacing: DS.Spacing.s4 + 2) {
                ForEach(1...5, id: \.self) { i in
                    Circle()
                        .fill(i <= rounded ? DS.Colors.Ink.primary : DS.Colors.Line.subtle)
                        .frame(width: 8, height: 8)
                }
            }
            Text("How it felt")
                .style(.micro)
                .foregroundStyle(DS.Colors.Ink.tertiary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("How it felt: \(rounded) of 5")
    }

    // MARK: - My Notes

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: "MY NOTES")
            Card {
                if let note = drillNote {
                    VStack(alignment: .leading, spacing: DS.Spacing.s12) {
                        Text(note.text)
                            .style(.callout)
                            .foregroundStyle(DS.Colors.Ink.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        HStack {
                            Text("Edited \(noteEditedLabel(note.updatedAt))")
                                .style(.micro)
                                .foregroundStyle(DS.Colors.Ink.tertiary)
                            Spacer()
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                showNoteEditor = true
                            } label: {
                                Text("Edit")
                                    .style(.foot)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(DS.Colors.Ink.primary)
                            }
                            .buttonStyle(PressableButtonStyle())
                        }
                    }
                } else {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showNoteEditor = true
                    } label: {
                        HStack(spacing: DS.Spacing.s8) {
                            Image(systemName: "square.and.pencil")
                                .font(.system(size: 15, weight: .medium))
                            Text("Add a note")
                                .style(.callout)
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
            .padding(.top, DS.Spacing.s12 + 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s24 + 4)
    }

    private func noteEditedLabel(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    /// Saves, updates, or deletes (on empty) the private note for this drill.
    private func saveNote(_ rawText: String) {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            if let existing = drillNote {
                context.delete(existing)
            }
            SyncEngine.shared.enqueueDrillNoteDeletion(drillID: drill.id)
        } else if let existing = drillNote {
            existing.text = trimmed
            existing.updatedAt = Date()
            SyncEngine.shared.enqueueDrillNote(drillID: drill.id, text: trimmed, updatedAt: existing.updatedAt)
        } else {
            let note = DrillNote(drillID: drill.id, text: trimmed)
            context.insert(note)
            SyncEngine.shared.enqueueDrillNote(drillID: drill.id, text: trimmed, updatedAt: note.updatedAt)
        }
        try? context.save()
    }

    // MARK: - Set-Up

    private func setupSection(_ summary: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: "SET-UP")
            HStack(alignment: .top, spacing: DS.Spacing.s12) {
                Image(systemName: "shippingbox")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(DS.Colors.Ink.tertiary)
                Text(summary)
                    .style(.callout)
                    .foregroundStyle(DS.Colors.Ink.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.top, DS.Spacing.s12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s24 + 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Set up: \(summary)")
    }

    // MARK: - 4. Section 01 — Purpose

    private var purposeSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: "PURPOSE")
            Text(drill.how)
                .style(.body)
                .foregroundStyle(DS.Colors.Ink.secondary)
                .padding(.top, DS.Spacing.s12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s24 + 4)
    }

    /// Quiet footer, not a badge — it matters when it matters and should not
    /// compete with the drill itself.
    @ViewBuilder
    private var updatedFooter: some View {
        if let lastUpdated {
            HStack(spacing: DS.Spacing.s8) {
                Image(systemName: "pencil.circle")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DS.Colors.Ink.quaternary)
                Text("Updated by your coach \(lastUpdated.formatted(date: .abbreviated, time: .omitted))")
                    .style(.micro)
                    .foregroundStyle(DS.Colors.Ink.quaternary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.top, DS.Spacing.s24)
        }
    }

    // MARK: - Instructions

    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: "HOW TO DO IT")

            VStack(alignment: .leading, spacing: DS.Spacing.s16) {
                ForEach(Array(drill.instructions.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: DS.Spacing.s12) {
                        Text("\(index + 1)")
                            .font(DS.Typography.num(size: 16))
                            .foregroundStyle(DS.Colors.Ink.primary)
                            .frame(width: 28, height: 28)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Circle())

                        Text(step)
                            .style(.body)
                            .foregroundStyle(DS.Colors.Ink.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(.top, DS.Spacing.s16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s24 + 4)
    }

    private var kindLabel: String {
        (MentalExerciseKind(rawValue: drill.exerciseKind ?? "") ?? .guided).label
    }

    // MARK: - Mental: Steps

    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: "THE EXERCISE")

            VStack(alignment: .leading, spacing: DS.Spacing.s16) {
                ForEach(Array(drill.steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: DS.Spacing.s12) {
                        Text("\(index + 1)")
                            .font(DS.Typography.num(size: 16))
                            .foregroundStyle(DS.Colors.Ink.primary)
                            .frame(width: 28, height: 28)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Circle())

                        Text(step)
                            .style(.body)
                            .foregroundStyle(DS.Colors.Ink.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(.top, DS.Spacing.s16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s24 + 4)
    }

    // MARK: - Mental: Journal Prompt

    private func journalPromptSection(_ prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: "REFLECT")

            HStack(alignment: .top, spacing: DS.Spacing.s12) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(DS.Colors.Ink.primary)
                Text(prompt)
                    .style(.callout)
                    .foregroundStyle(DS.Colors.Ink.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(DS.Spacing.s20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DS.Colors.Bg.elevated)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
            .padding(.top, DS.Spacing.s12 + 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s24 + 4)
    }

    // MARK: - 5. Section 02 — Coaching Points

    private var coachingSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: "COACHING POINTS")

            VStack(alignment: .leading, spacing: DS.Spacing.s12) {
                ForEach(Array(drill.coachingPoints.enumerated()), id: \.offset) { index, point in
                    HStack(alignment: .top, spacing: DS.Spacing.s12) {
                        Text("\(index + 1)")
                            .style(.foot)
                            .fontWeight(.bold)
                            .foregroundStyle(DS.Colors.Ink.primary)
                            .frame(width: 24, height: 24)
                            .background(DS.Colors.Bg.raised)
                            .clipShape(Circle())

                        Text(point)
                            .style(.callout)
                            .foregroundStyle(DS.Colors.Ink.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(.top, DS.Spacing.s16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s24 + 4)
    }

    // MARK: - 6. Section 03 — The Challenge

    private var challengeSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: "THE CHALLENGE")

            VStack(alignment: .leading, spacing: 0) {
                Text(drill.focus)
                    .style(.title2)
                    .foregroundStyle(DS.Colors.Ground.primary)

                HStack(spacing: DS.Spacing.s8) {
                    challengeTag("\(drill.sets) Sets")
                    challengeTag("\(setDurationLabel) Each")
                    challengeTag("No Loss")
                }
                .padding(.top, DS.Spacing.s12 - 2)
            }
            .padding(DS.Spacing.s24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
            .padding(.top, DS.Spacing.s12 + 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s24 + 4)
    }

    private func challengeTag(_ text: String) -> some View {
        Text(text)
            .style(.foot)
            .foregroundStyle(DS.Colors.Ground.primary)
            .padding(.vertical, 6)
            .padding(.horizontal, DS.Spacing.s12)
            .background(Color.black.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.pill))
    }

    // MARK: - 7. Section 04 — Accountability

    private func accountabilitySection(_ vm: DrillDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: "ACCOUNTABILITY")

            Card {
                VStack(alignment: .leading, spacing: DS.Spacing.s12) {
                    Eyebrow(text: "\(ProgressionRules.masteryPasses) Honest Passes")

                    masteryTrack(passes: vm.passesLogged)

                    Text("\(vm.passesLogged) of \(ProgressionRules.masteryPasses) logged")
                        .style(.foot)
                        .foregroundStyle(DS.Colors.Ink.tertiary)

                    Text("Log each clean run yourself — the work is yours. No video. No proof. Just your word.")
                        .style(.body)
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                }
            }
            .padding(.top, DS.Spacing.s12 + 2)

            honorCode
                .padding(.top, DS.Spacing.s16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s24 + 4)
    }

    private func masteryTrack(passes: Int) -> some View {
        HStack(spacing: DS.Spacing.s4 + 2) {
            ForEach(0..<ProgressionRules.masteryPasses, id: \.self) { index in
                RoundedRectangle(cornerRadius: 3)
                    .fill(index < passes ? Color.white : DS.Colors.Line.subtle)
                    .frame(height: 6)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var honorCode: some View {
        HStack(spacing: DS.Spacing.s12) {
            Image(systemName: "checkmark.shield")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(DS.Colors.Ink.primary)

            VStack(alignment: .leading, spacing: DS.Spacing.s4) {
                Text("The honor code")
                    .style(.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(DS.Colors.Ink.primary)
                Text("Only you know if it was your best · Log it true")
                    .style(.micro)
                    .foregroundStyle(DS.Colors.Ink.tertiary)
            }
        }
    }

    // MARK: - 8. Bottom CTA

    @ViewBuilder
    private func bottomCTA(_ vm: DrillDetailViewModel) -> some View {
        VStack(spacing: DS.Spacing.s8) {
            if isLocked {
                // The drill page stays readable as a teaser, but training it is
                // the thing behind the paywall. Gating here catches every route
                // into this screen at once instead of per entry point.
                PrimaryButton(
                    label: "Unlock with Elite",
                    hint: "Level \(level.number) drills"
                ) {
                    subscription.presentPaywall()
                }

                Text("Level \(level.number) is part of Elite. Levels 1–\(ProgressionRules.freeLevels) stay free.")
                    .style(.foot)
                    .foregroundStyle(DS.Colors.Ink.quaternary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            } else {
                PrimaryButton(
                    label: drill.isMentalExercise ? "Begin exercise" : "Start drill",
                    hint: vm.drill.durationSec.minutesHint
                ) {
                    activeSession = makeQueue()
                }

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showLogConfirm = true
                } label: {
                    Label("Log as done — no timer", systemImage: "checkmark.circle")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s12)
        .padding(.bottom, tabBarClearance + DS.Spacing.s12)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(alignment: .top) {
                    Divider().opacity(0.4)
                }
                .ignoresSafeArea(edges: .bottom)
        )
    }
}


// MARK: - Demo video player

/// Wraps an `AVPlayer` in `@State` so it is created once for the drill's video
/// and paused when the view scrolls away. Streams the public `drill-videos` URL.
private struct DrillDemoVideoView: View {
    @State private var player: AVPlayer
    @State private var isMuted: Bool

    init(url: URL) {
        let player = AVPlayer(url: url)
        // Starts muted when the player already has something playing. A demo
        // video is watched for the movement, not the audio, and silently
        // stopping someone's podcast to show them a fifteen-second clip is the
        // rudest thing this screen could do. Unmuting is one tap.
        let shouldMute = AppAudioSession.isOtherAudioPlaying
        player.isMuted = shouldMute
        _player = State(initialValue: player)
        _isMuted = State(initialValue: shouldMute)
    }

    var body: some View {
        VideoPlayer(player: player)
            .overlay(alignment: .bottomTrailing) {
                if isMuted {
                    Button {
                        isMuted = false
                        player.isMuted = false
                    } label: {
                        Image(systemName: "speaker.slash.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(DS.Colors.Ink.primary)
                            .frame(width: 36, height: 36)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(DS.Spacing.s8)
                    .accessibilityLabel("Unmute demo video")
                }
            }
            .onDisappear { player.pause() }
    }
}
