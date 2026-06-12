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
    @State private var model = CoachViewModel()
    @State private var sync = SyncEngine.shared
    @State private var showPublish = false

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
                        workoutsSection
                        drillEditorSection
                        rosterSection
                    }
                }
                .padding(.horizontal, DS.Spacing.s20)
                .padding(.top, DS.Spacing.s24)
                .padding(.bottom, 120)
            }
            .background(DS.Colors.Bg.base)
            .scrollIndicators(.hidden)
            .refreshable { await model.loadOverviewAndRoster(context: modelContext) }
            .navigationDestination(for: RosterPlayer.self) { player in
                CoachPlayerDetailView(player: player, model: model)
            }
            .navigationDestination(for: CoachDrillEditorRoute.self) { _ in
                CoachDrillEditorView(model: model)
            }
        }
        .preferredColorScheme(.dark)
        .task {
            if model.overview == nil {
                await model.loadOverviewAndRoster(context: modelContext)
            }
            if model.publishedWorkouts.isEmpty {
                await model.loadPublishedWorkouts()
            }
        }
        .sheet(isPresented: $showPublish) {
            WorkoutBuilderView { title, note, drillIDs in
                Task { await model.publishWorkout(title: title, note: note, drillIDs: drillIDs) }
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

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: DS.Spacing.s8) {
                Eyebrow(text: "Coach Mode")
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
                Text(player.displayName)
                    .style(.title3)
                    .foregroundStyle(DS.Colors.Ink.primary)
                    .lineLimit(1)
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

#Preview {
    CoachView()
        .preferredColorScheme(.dark)
}
