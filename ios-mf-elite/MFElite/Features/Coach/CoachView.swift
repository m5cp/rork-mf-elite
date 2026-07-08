//
//  CoachView.swift
//  MFElite
//
//  Coach Mode home: team overview, searchable roster, and read-only player
//  detail. Visible only to authorized coaches. All data loads async with
//  pull-to-refresh and fails soft to a friendly retry state.
//

import SwiftUI
import SwiftData

struct CoachView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Discipline.sortIndex) private var disciplines: [Discipline]
    @State private var model = CoachViewModel()
    @State private var sync = SyncEngine.shared
    @State private var showPublish = false
    @State private var showAnnounce = false
    @State private var shareText: ShareableText?
    @State private var indexCache = DrillIndexCache()
    @State private var showWODPicker = false
    @State private var showClearWODConfirm = false
    @AppStorage("MF_COACH_GUIDE_SEEN") private var coachGuideSeen = false
    @State private var showCoachGuide = false

    /// drillID → resolved drill for counts/minutes. Memoized via the shared helper.
    private var drillIndex: [String: ResolvedDrill] {
        buildDrillIndex(disciplines, cache: indexCache)
    }

    /// The players' current Workout of the Day: the most recent ACTIVE published
    /// workout — the same "latest wins" rule the Today fallback chain uses.
    private var currentWOD: CoachPublishedWorkout? {
        model.publishedWorkouts.filter(\.active).max(by: { $0.createdAt < $1.createdAt })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.s24) {
                    header

                    if !sync.isOnline {
                        offlineBanner
                    }

                    switch model.overviewState {
                    case .idle, .loading where model.overview == nil:
                        loadingState
                    case .failed where model.overview == nil:
                        retryState
                    default:
                        overviewSection
                        approvalsSection
                        announcementsSection
                        workoutOfTheDaySection
                        workoutsSection
                        drillEditorSection
                        rosterSection
                        coachGuideSection
                    }
                }
                .padding(.horizontal, DS.Spacing.s20)
                .padding(.top, DS.Spacing.s24)
                .padding(.bottom, 120)
            }
            .background(DS.Colors.Bg.base)
            .scrollIndicators(.hidden)
            .refreshable {
            await model.loadOverviewAndRoster(context: modelContext)
            await model.loadApprovals(context: modelContext)
        }
            .navigationDestination(for: RosterPlayer.self) { player in
                CoachPlayerDetailView(player: player, model: model)
            }
            .navigationDestination(for: CoachDrillEditorRoute.self) { _ in
                CoachDrillEditorView(model: model)
            }
            .navigationDestination(for: CoachGuideRoute.self) { _ in
                CoachGuideView()
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            if !coachGuideSeen {
                showCoachGuide = true
            }
        }
        .sheet(isPresented: $showCoachGuide) {
            NavigationStack { CoachGuideView() }
                .preferredColorScheme(.dark)
                .onDisappear { coachGuideSeen = true }
        }
        .task {
            if model.overview == nil {
                await model.loadOverviewAndRoster(context: modelContext)
            }
            if model.publishedWorkouts.isEmpty {
                await model.loadPublishedWorkouts()
            }
            if model.announcements.isEmpty {
                await model.loadAnnouncements()
            }
            await model.loadApprovals(context: modelContext)
        }
        .sheet(isPresented: $showAnnounce) {
            AnnouncementComposerView { title, body in
                Task {
                    let text = await model.sendAnnouncement(title: title, body: body)
                    if !text.isEmpty {
                        shareText = ShareableText(text: text)
                    }
                }
            }
            .presentationDetents([.medium, .large])
            .presentationBackground(DS.Colors.Bg.base)
        }
        .sheet(isPresented: $showPublish) {
            WorkoutBuilderView { title, note, drillIDs in
                Task { await model.publishWorkout(title: title, note: note, drillIDs: drillIDs) }
            }
        }
        .sheet(isPresented: $showWODPicker) {
            WorkoutOfTheDayPicker(
                coachWorkouts: model.publishedWorkouts,
                drillIndex: drillIndex
            ) { title, note, drillIDs in
                Task { await model.publishWorkout(title: title, note: note, drillIDs: drillIDs) }
            }
        }
        .confirmationDialog(
            "Clear the Workout of the Day?",
            isPresented: $showClearWODConfirm,
            titleVisibility: .visible
        ) {
            Button("Clear", role: .destructive) { clearWorkoutOfTheDay() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Players will see the app's default daily routine until you set a new one.")
        }
        .sheet(item: $shareText) { item in
            ShareSheet(items: [item.text])
                .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Ballon d'Or approvals

    @ViewBuilder
    private var approvalsSection: some View {
        if !model.pendingApprovals.isEmpty {
            VStack(alignment: .leading, spacing: DS.Spacing.s12) {
                HStack(spacing: DS.Spacing.s8) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(BallonDorTheme.gold)
                    Eyebrow(text: "Ballon d'Or · Approvals")
                }
                Text("Players who've reached the final tier and await your invitation.")
                    .style(.micro)
                    .foregroundStyle(DS.Colors.Ink.tertiary)
                VStack(spacing: DS.Spacing.s8) {
                    ForEach(model.pendingApprovals) { approval in
                        BallonDorApprovalRow(
                            approval: approval,
                            onApprove: { Task { await model.approve(approval) } },
                            onDecline: { Task { await model.decline(approval) } }
                        )
                    }
                }
            }
        }
    }

    // MARK: - Announcements

    private var announcementsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s12) {
            Eyebrow(text: "Announcements")

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                showAnnounce = true
            } label: {
                HStack(spacing: DS.Spacing.s12) {
                    Image(systemName: "megaphone.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(DS.Colors.Ink.primary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Send a message")
                            .style(.title3)
                            .foregroundStyle(DS.Colors.Ink.primary)
                        Text("Post an update to the whole team")
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

            let visible = model.announcements.filter { !$0.title.hasPrefix("__") }
            if !visible.isEmpty {
                VStack(spacing: DS.Spacing.s8) {
                    ForEach(visible) { announcement in
                        CoachAnnouncementRow(announcement: announcement) { active in
                            Task { await model.setAnnouncementActive(announcement, active: active) }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Workout of the Day

    /// Shows the workout players currently see as the WOD, with actions to set a
    /// new one (from existing workouts or stock routines) or clear it entirely.
    private var workoutOfTheDaySection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s12) {
            Eyebrow(text: "Workout of the Day")

            VStack(alignment: .leading, spacing: DS.Spacing.s12) {
                if let wod = currentWOD {
                    let drills = wod.drillIDs.compactMap { drillIndex[$0] }.map(\.drill)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(wod.title)
                            .style(.title3)
                            .foregroundStyle(DS.Colors.Ink.primary)
                            .lineLimit(1)
                        Text("\(wod.drillIDs.count) \(wod.drillIDs.count == 1 ? "drill" : "drills") · \(estimatedSessionMinutes(forDrills: drills)) min · Published \(CoachFormat.shortDate(wod.createdAt))")
                            .style(.micro)
                            .foregroundStyle(DS.Colors.Ink.tertiary)
                    }
                } else {
                    Text("No workout set — players see the app default rotation.")
                        .style(.foot)
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: DS.Spacing.s8) {
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        showWODPicker = true
                    } label: {
                        Text("Set Workout of the Day")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(DS.Colors.Ground.primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Color.white)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(PressableButtonStyle())

                    if currentWOD != nil {
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            showClearWODConfirm = true
                        } label: {
                            Text("Clear")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(DS.Colors.Ink.secondary)
                                .padding(.horizontal, DS.Spacing.s20)
                                .frame(height: 44)
                                .background(DS.Colors.Bg.raised)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(PressableButtonStyle())
                        .accessibilityLabel("Clear the Workout of the Day")
                    }
                }
            }
            .padding(DS.Spacing.s16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DS.Colors.Bg.card)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .stroke(DS.Colors.Line.hairline, lineWidth: 1)
            )
        }
    }

    /// Retire every active published workout via the existing active/inactive
    /// mechanism so players fall back to the app default rotation after sync.
    private func clearWorkoutOfTheDay() {
        let active = model.publishedWorkouts.filter(\.active)
        Task {
            for workout in active {
                await model.setWorkoutActive(workout, active: false)
            }
        }
    }

    // MARK: - Workouts (Coach's Workout of the Day)

    private var workoutsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s12) {
            Eyebrow(text: "Workouts")

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                showPublish = true
            } label: {
                HStack(spacing: DS.Spacing.s12) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(DS.Colors.Ink.primary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Publish a workout")
                            .style(.title3)
                            .foregroundStyle(DS.Colors.Ink.primary)
                        Text("Send a featured session to your whole team")
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

            if !model.publishedWorkouts.isEmpty {
                VStack(spacing: DS.Spacing.s8) {
                    ForEach(model.publishedWorkouts) { workout in
                        CoachWorkoutRow(workout: workout) { active in
                            Task { await model.setWorkoutActive(workout, active: active) }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Drill editor

    private var drillEditorSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s12) {
            Eyebrow(text: "Drill Editor")
            NavigationLink(value: CoachDrillEditorRoute()) {
                HStack(spacing: DS.Spacing.s12) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(DS.Colors.Ink.primary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Improve the drills")
                            .style(.title3)
                            .foregroundStyle(DS.Colors.Ink.primary)
                        Text("Edit content, add new drills, or hide one")
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

    // MARK: - Coach guide

    private var coachGuideSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s12) {
            Eyebrow(text: "Help")
            NavigationLink(value: CoachGuideRoute()) {
                HStack(spacing: DS.Spacing.s12) {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(DS.Colors.Ink.primary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("How Coach Mode works")
                            .style(.title3)
                            .foregroundStyle(DS.Colors.Ink.primary)
                        Text("The coach guide, anytime")
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

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: DS.Spacing.s8) {
                Eyebrow(text: coachRoleLabel)
                Text("Your Team")
                    .style(.title1)
                    .foregroundStyle(DS.Colors.Ink.primary)
                Text(updatedText)
                    .style(.cap)
                    .foregroundStyle(DS.Colors.Ink.quaternary)
            }
            Spacer(minLength: DS.Spacing.s12)
            Button {
                Task { await model.loadOverviewAndRoster(context: modelContext) }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DS.Colors.Ink.secondary)
                    .frame(width: 44, height: 44)
                    .background(DS.Colors.Bg.card)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(DS.Colors.Line.hairline, lineWidth: 1))
                    .rotationEffect(.degrees(model.overviewState == .loading ? 360 : 0))
                    .animation(model.overviewState == .loading
                        ? .linear(duration: 0.9).repeatForever(autoreverses: false)
                        : .default, value: model.overviewState)
            }
            .buttonStyle(PressableButtonStyle())
            .disabled(model.overviewState == .loading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// "Head Coach" when the server role says so; otherwise the default label.
    private var coachRoleLabel: String {
        SubscriptionService.shared.coachRole == "head_coach" ? "Head Coach" : "Coach Mode"
    }

    private var updatedText: String {
        guard let date = model.lastLoadedAt else { return "Pull to refresh" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return "Updated \(formatter.localizedString(for: date, relativeTo: Date()))"
    }

    private var offlineBanner: some View {
        HStack(spacing: DS.Spacing.s8) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 13, weight: .semibold))
            Text("You're offline — Coach Mode needs a connection.")
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

    // MARK: - Loading / retry

    private var loadingState: some View {
        VStack(spacing: DS.Spacing.s12) {
            ProgressView()
                .controlSize(.large)
                .tint(DS.Colors.Ink.tertiary)
            Text("Loading your team…")
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
            Text("Pull to retry, or check your connection.")
                .style(.callout)
                .foregroundStyle(DS.Colors.Ink.tertiary)
                .multilineTextAlignment(.center)
            Button("Retry") {
                Task { await model.loadOverviewAndRoster(context: modelContext) }
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(DS.Colors.Ink.primary)
            .padding(.top, DS.Spacing.s4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.s64)
    }

    // MARK: - Overview

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s12) {
            Eyebrow(text: "This Week")
            if let overview = model.overview {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DS.Spacing.s12) {
                    statCard(value: "\(overview.totalPlayers)", label: "Players")
                    statCard(value: "\(overview.activeThisWeek)", label: "Active this week")
                    statCard(value: "\(overview.teamMinutesThisWeek)", label: "Team minutes")
                    statCard(value: "\(overview.sessionsThisWeek)", label: "Sessions")
                }

                Button {
                    guard let overview = model.overview else { return }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    shareText = ShareableText(text: CoachExport.weeklyDigest(overview))
                } label: {
                    HStack(spacing: DS.Spacing.s8) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Share weekly digest")
                            .style(.foot)
                            .fontWeight(.semibold)
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(model.overview == nil ? DS.Colors.Ink.quaternary : DS.Colors.Ink.primary)
                    .padding(DS.Spacing.s12)
                    .frame(maxWidth: .infinity)
                    .background(DS.Colors.Bg.card)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                    .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(DS.Colors.Line.hairline, lineWidth: 1))
                }
                .buttonStyle(PressableButtonStyle())
                .disabled(model.overview == nil)
            }
        }
    }

    private func statCard(value: String, label: String) -> some View {
        Card(padding: DS.Spacing.s16) {
            VStack(alignment: .leading, spacing: DS.Spacing.s4) {
                Text(value)
                    .style(.num(size: 30))
                    .foregroundStyle(DS.Colors.Ink.primary)
                Text(label.uppercased())
                    .style(.micro)
                    .foregroundStyle(DS.Colors.Ink.quaternary)
            }
        }
    }

    // MARK: - Roster

    private var rosterSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s12) {
            HStack {
                Eyebrow(text: "Roster")
                Spacer()
                Text("\(model.roster.count)")
                    .style(.micro)
                    .foregroundStyle(DS.Colors.Ink.quaternary)
            }

            searchField

            if model.filteredRoster.isEmpty {
                Text(model.roster.isEmpty ? "No players yet." : "No players match your search.")
                    .style(.callout)
                    .foregroundStyle(DS.Colors.Ink.tertiary)
                    .padding(.vertical, DS.Spacing.s24)
            } else {
                VStack(spacing: DS.Spacing.s8) {
                    ForEach(model.filteredRoster) { player in
                        NavigationLink(value: player) {
                            CoachRosterRow(player: player)
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                }
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: DS.Spacing.s8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DS.Colors.Ink.quaternary)
            TextField("", text: $model.searchText, prompt: Text("Search name or email")
                .foregroundColor(DS.Colors.Ink.quaternary))
                .style(.body)
                .foregroundStyle(DS.Colors.Ink.primary)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !model.searchText.isEmpty {
                Button { model.searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(DS.Colors.Ink.quaternary)
                }
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
}

// MARK: - Roster row

struct CoachRosterRow: View {
    let player: RosterPlayer

    var body: some View {
        HStack(spacing: DS.Spacing.s12) {
            Monogram(size: 44, initials: CoachFormat.initials(player.displayName), kit: nil)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: DS.Spacing.s8) {
                    Text(player.displayName)
                        .style(.title3)
                        .foregroundStyle(DS.Colors.Ink.primary)
                        .lineLimit(1)
                    if player.ballonDorApproved {
                        Text("BALLON D'OR")
                            .font(.system(size: 8, weight: .heavy, design: .monospaced))
                            .tracking(0.5)
                            .foregroundStyle(.black)
                            .padding(.vertical, 2)
                            .padding(.horizontal, 5)
                            .background(BallonDorTheme.gold)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                }
                Text(subtitle)
                    .style(.foot)
                    .foregroundStyle(DS.Colors.Ink.tertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: DS.Spacing.s8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(lastActiveText)
                    .style(.cap)
                    .foregroundStyle(DS.Colors.Ink.quaternary)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DS.Colors.Ink.quaternary)
            }
        }
        .padding(DS.Spacing.s12)
        .background(DS.Colors.Bg.card)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .stroke(DS.Colors.Line.hairline, lineWidth: 1)
        )
    }

    private var subtitle: String {
        var parts: [String] = []
        if let username = player.username, !username.isEmpty { parts.append("@\(username)") }
        if let kit = player.kitNumber, !kit.isEmpty { parts.append("#\(kit)") }
        if let position = player.position, !position.isEmpty { parts.append(position) }
        if let email = player.email, !email.isEmpty, parts.isEmpty { parts.append(email) }
        return parts.isEmpty ? "Player" : parts.joined(separator: " · ")
    }

    private var lastActiveText: String {
        guard let date = player.lastActive else { return "No activity" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Published workout row

/// One coach-published workout with an active/inactive toggle. Deactivating it
/// stops players seeing it; nothing else changes anywhere.
struct CoachWorkoutRow: View {
    let workout: CoachPublishedWorkout
    let onToggleActive: (Bool) -> Void

    var body: some View {
        HStack(spacing: DS.Spacing.s12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(workout.title)
                    .style(.title3)
                    .foregroundStyle(DS.Colors.Ink.primary)
                    .lineLimit(1)
                Text(subtitle)
                    .style(.micro)
                    .foregroundStyle(DS.Colors.Ink.tertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: DS.Spacing.s8)
            Toggle("", isOn: Binding(
                get: { workout.active },
                set: { newValue in
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onToggleActive(newValue)
                }
            ))
            .labelsHidden()
            .tint(DS.Colors.Ink.primary)
        }
        .padding(DS.Spacing.s12)
        .background(DS.Colors.Bg.card)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .stroke(DS.Colors.Line.hairline, lineWidth: 1)
        )
        .opacity(workout.active ? 1 : 0.6)
    }

    private var subtitle: String {
        let count = workout.drillIDs.count
        let drills = "\(count) \(count == 1 ? "drill" : "drills")"
        let status = workout.active ? "Active" : "Inactive"
        return "\(status) · \(drills) · \(CoachFormat.shortDate(workout.createdAt))"
    }
}

// MARK: - Ballon d'Or approval row

/// Shared gold accent for the Ballon d'Or surfaces.
enum BallonDorTheme {
    static let gold = Color(red: 0.86, green: 0.71, blue: 0.36)
}

/// One pending request with a stats summary plus Approve / Not yet actions.
struct BallonDorApprovalRow: View {
    let approval: PendingApproval
    let onApprove: () -> Void
    let onDecline: () -> Void

    @State private var showApproveConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s12) {
            HStack(spacing: DS.Spacing.s12) {
                Monogram(size: 40, initials: CoachFormat.initials(approval.displayName), kit: nil)
                VStack(alignment: .leading, spacing: 2) {
                    Text(approval.displayName)
                        .style(.title3)
                        .foregroundStyle(DS.Colors.Ink.primary)
                        .lineLimit(1)
                    Text(subtitle)
                        .style(.micro)
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: DS.Spacing.s16) {
                stat(value: "\(approval.xp.formatted())", label: "XP")
                stat(value: "\(approval.streak)", label: "Streak")
                stat(value: "\(approval.mastered)", label: "Mastered")
                stat(value: "\(approval.minutes30d)", label: "Min · 30d")
            }

            HStack(spacing: DS.Spacing.s8) {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onDecline()
                } label: {
                    Text("Not yet")
                        .style(.foot)
                        .fontWeight(.semibold)
                        .foregroundStyle(DS.Colors.Ink.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.s12)
                        .background(DS.Colors.Bg.raised)
                        .clipShape(Capsule())
                }
                .buttonStyle(PressableButtonStyle())

                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    showApproveConfirm = true
                } label: {
                    HStack(spacing: DS.Spacing.s4 + 2) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text("Approve")
                            .style(.foot)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.s12)
                    .background(BallonDorTheme.gold)
                    .clipShape(Capsule())
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
        .padding(DS.Spacing.s16)
        .background(DS.Colors.Bg.card)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .stroke(BallonDorTheme.gold.opacity(0.35), lineWidth: 1)
        )
        .alert("Award the Ballon d'Or?", isPresented: $showApproveConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Approve") { onApprove() }
        } message: {
            Text("\(approval.displayName) will unlock the final tier with a full celebration. This is the academy's highest honour.")
        }
    }

    private var subtitle: String {
        var parts: [String] = []
        if let kit = approval.kitNumber, !kit.isEmpty { parts.append("#\(kit)") }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        parts.append("Requested \(formatter.localizedString(for: approval.requestedAt, relativeTo: Date()))")
        return parts.joined(separator: " · ")
    }

    private func stat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .style(.num(size: 18))
                .foregroundStyle(DS.Colors.Ink.primary)
            Text(label.uppercased())
                .style(.microSm)
                .foregroundStyle(DS.Colors.Ink.quaternary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    CoachView()
        .preferredColorScheme(.dark)
}
