//
//  CoachTeamsView.swift
//  MFElite
//
//  Coach-side teams manager: build multiple teams (rosters), add any app user
//  to a team, rename/remove, and reuse teams to target broadcasts. Head Coaches
//  see every coach's teams; regular coaches see only their own (RLS-enforced).
//

import SwiftUI

struct CoachTeamsRoute: Hashable {}
struct CoachTeamDetailRoute: Hashable {
    let teamID: String
}

struct CoachTeamsView: View {
    @State private var store = TeamsStore.shared
    @State private var showCreate = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.s16) {
                Eyebrow(text: "Teams & rosters")
                Text("Your teams")
                    .style(.title2)
                    .foregroundStyle(DS.Colors.Ink.primary)
                Text("Group athletes into teams — U11, U16, personal training, anything. Add any app user directly, then target your schedule, announcements, and workouts to the right group.")
                    .style(.foot)
                    .foregroundStyle(DS.Colors.Ink.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                PrimaryButton(label: "Create a team") {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    showCreate = true
                }

                if store.teamsState == .loading && store.teams.isEmpty {
                    ProgressView()
                        .tint(DS.Colors.Ink.tertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, DS.Spacing.s24)
                } else if store.teams.isEmpty {
                    Text("No teams yet. Create your first team to start organizing athletes.")
                        .style(.foot)
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                        .padding(.top, DS.Spacing.s16)
                } else {
                    VStack(spacing: DS.Spacing.s8) {
                        ForEach(store.teams) { team in
                            NavigationLink(value: CoachTeamDetailRoute(teamID: team.id)) {
                                teamRow(team)
                            }
                            .buttonStyle(PressableButtonStyle())
                        }
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.top, DS.Spacing.s16)
            .padding(.bottom, 120)
        }
        .background(DS.Colors.Bg.base)
        .scrollIndicators(.hidden)
        .navigationTitle("Teams")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await store.loadTeams()
            if store.athletes.isEmpty { await store.loadAthletes() }
        }
        .refreshable { await store.loadTeams() }
        .sheet(isPresented: $showCreate) {
            TeamEditorSheet(team: nil)
                .presentationDetents([.height(320)])
                .presentationBackground(DS.Colors.Bg.base)
        }
    }

    private func teamRow(_ team: CoachTeam) -> some View {
        HStack(spacing: DS.Spacing.s12) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(DS.Colors.Gold.base)
                .frame(width: 44, height: 44)
                .background(DS.Colors.Bg.raised)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            VStack(alignment: .leading, spacing: 2) {
                Text(team.name)
                    .style(.title3)
                    .foregroundStyle(DS.Colors.Ink.primary)
                    .lineLimit(1)
                Text(team.label.isEmpty
                     ? "\(team.memberCount) athlete\(team.memberCount == 1 ? "" : "s")"
                     : "\(team.label) · \(team.memberCount) athlete\(team.memberCount == 1 ? "" : "s")")
                    .style(.micro)
                    .foregroundStyle(DS.Colors.Ink.tertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: DS.Spacing.s8)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DS.Colors.Ink.quaternary)
        }
        .padding(DS.Spacing.s12)
        .background(DS.Colors.Bg.card)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(DS.Colors.Line.hairline, lineWidth: 1))
        .contentShape(Rectangle())
    }
}

// MARK: - Team editor (create / rename)

struct TeamEditorSheet: View {
    /// nil = create; non-nil = rename/relabel.
    let team: CoachTeam?

    @Environment(\.dismiss) private var dismiss
    @State private var store = TeamsStore.shared
    @State private var name = ""
    @State private var label = ""
    @State private var isWorking = false
    @State private var failed = false

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s16) {
            Capsule()
                .fill(DS.Colors.Line.subtle)
                .frame(width: 36, height: 4)
                .frame(maxWidth: .infinity)

            Eyebrow(text: team == nil ? "New team" : "Edit team")

            field("Team name") {
                TextField("e.g. U16 Boys", text: $name)
                    .textInputAutocapitalization(.words)
            }
            field("Age group / label (optional)") {
                TextField("e.g. U16 · Personal", text: $label)
                    .textInputAutocapitalization(.words)
            }

            if failed {
                Text("Couldn't save. Check your connection and try again.")
                    .style(.foot)
                    .foregroundStyle(Color(hex: "#FF5A5F"))
            }

            PrimaryButton(label: isWorking ? "Saving…" : (team == nil ? "Create team" : "Save changes")) {
                save()
            }
            .disabled(isWorking || name.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(DS.Spacing.s20)
        .background(DS.Colors.Bg.base)
        .onAppear {
            name = team?.name ?? ""
            label = team?.label ?? ""
        }
    }

    private func field<C: View>(_ label: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s8) {
            Eyebrow(text: label)
            content()
                .font(DS.Typography.body)
                .foregroundStyle(DS.Colors.Ink.primary)
                .tint(.white)
                .padding(DS.Spacing.s16)
                .background(DS.Colors.Bg.raised)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func save() {
        isWorking = true
        failed = false
        Task {
            let ok: Bool
            if let team {
                ok = await store.updateTeam(team, name: name, label: label)
            } else {
                ok = await store.createTeam(name: name, label: label)
            }
            isWorking = false
            if ok {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                dismiss()
            } else {
                failed = true
            }
        }
    }
}

// MARK: - Team detail (roster)

struct CoachTeamDetailView: View {
    let teamID: String

    @Environment(\.dismiss) private var dismiss
    @State private var store = TeamsStore.shared
    @State private var showAddAthletes = false
    @State private var showEdit = false
    @State private var showDeleteConfirm = false

    private var team: CoachTeam? { store.teams.first { $0.id == teamID } }

    var body: some View {
        ScrollView {
            if let team {
                VStack(alignment: .leading, spacing: DS.Spacing.s16) {
                    header(team)

                    HStack(spacing: DS.Spacing.s8) {
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            showAddAthletes = true
                        } label: {
                            Label("Add athletes", systemImage: "person.badge.plus")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(DS.Colors.Ground.primary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Color.white)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(PressableButtonStyle())

                        Button {
                            showEdit = true
                        } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(DS.Colors.Ink.secondary)
                                .frame(width: 44, height: 44)
                                .background(DS.Colors.Bg.raised)
                                .clipShape(Circle())
                        }
                        .buttonStyle(PressableButtonStyle())
                        .accessibilityLabel("Edit team")
                    }

                    rosterList(team)

                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Text("Delete team")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color(hex: "#FF5A5F"))
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(DS.Colors.Bg.raised, in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                    }
                    .buttonStyle(PressableButtonStyle())
                    .padding(.top, DS.Spacing.s12)
                }
                .padding(.horizontal, DS.Spacing.s20)
                .padding(.top, DS.Spacing.s16)
                .padding(.bottom, 120)
            } else {
                Text("This team is no longer available.")
                    .style(.foot)
                    .foregroundStyle(DS.Colors.Ink.tertiary)
                    .padding(.top, DS.Spacing.s64)
            }
        }
        .background(DS.Colors.Bg.base)
        .scrollIndicators(.hidden)
        .navigationTitle(team?.name ?? "Team")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if store.athletes.isEmpty { await store.loadAthletes() }
            if store.teams.isEmpty { await store.loadTeams() }
        }
        .sheet(isPresented: $showAddAthletes) {
            AddAthletesSheet(teamID: teamID)
                .presentationDetents([.large])
                .presentationBackground(DS.Colors.Bg.base)
        }
        .sheet(isPresented: $showEdit) {
            if let team {
                TeamEditorSheet(team: team)
                    .presentationDetents([.height(320)])
                    .presentationBackground(DS.Colors.Bg.base)
            }
        }
        .confirmationDialog("Delete this team?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let team {
                    Task {
                        await store.deleteTeam(team)
                        dismiss()
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Athletes stay in the app — they're only removed from this team. Broadcasts already sent are unaffected.")
        }
    }

    private func header(_ team: CoachTeam) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s4) {
            if !team.label.isEmpty {
                Text(team.label.uppercased())
                    .style(.micro)
                    .foregroundStyle(DS.Colors.Gold.textLight)
            }
            Text("\(team.memberCount) athlete\(team.memberCount == 1 ? "" : "s")")
                .style(.foot)
                .foregroundStyle(DS.Colors.Ink.secondary)
        }
    }

    @ViewBuilder
    private func rosterList(_ team: CoachTeam) -> some View {
        let members = team.memberIDs.compactMap { store.athleteByID[$0] }
        if members.isEmpty {
            Text("No athletes on this team yet. Tap \u{201C}Add athletes\u{201D} to build the roster.")
                .style(.foot)
                .foregroundStyle(DS.Colors.Ink.tertiary)
                .padding(.top, DS.Spacing.s16)
        } else {
            VStack(spacing: DS.Spacing.s8) {
                ForEach(members) { athlete in
                    HStack(spacing: DS.Spacing.s12) {
                        Monogram(size: 40, initials: CoachFormat.initials(athlete.displayName), kit: nil)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(athlete.displayName)
                                .style(.title3)
                                .foregroundStyle(DS.Colors.Ink.primary)
                                .lineLimit(1)
                            Text(athlete.subtitle)
                                .style(.micro)
                                .foregroundStyle(DS.Colors.Ink.tertiary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: DS.Spacing.s8)
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            Task { await store.removeAthlete(athlete.id, from: teamID) }
                        } label: {
                            Image(systemName: "minus.circle")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(DS.Colors.Ink.quaternary)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PressableButtonStyle())
                        .accessibilityLabel("Remove \(athlete.displayName)")
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

// MARK: - Add athletes

struct AddAthletesSheet: View {
    let teamID: String

    @Environment(\.dismiss) private var dismiss
    @State private var store = TeamsStore.shared
    @State private var query = ""

    private var team: CoachTeam? { store.teams.first { $0.id == teamID } }

    private var filtered: [TeamAthlete] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return store.athletes }
        return store.athletes.filter {
            $0.displayName.lowercased().contains(q)
                || ($0.username?.lowercased().contains(q) ?? false)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.s8) {
                    ForEach(filtered) { athlete in
                        row(athlete)
                    }
                }
                .padding(.horizontal, DS.Spacing.s20)
                .padding(.top, DS.Spacing.s12)
                .padding(.bottom, DS.Spacing.s32)
            }
            .background(DS.Colors.Bg.base)
            .scrollIndicators(.hidden)
            .navigationTitle("Add athletes")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "Search all app users")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.bold)
                }
            }
            .task { if store.athletes.isEmpty { await store.loadAthletes() } }
        }
        .preferredColorScheme(.dark)
    }

    private func row(_ athlete: TeamAthlete) -> some View {
        let isOn = team?.memberIDs.contains(athlete.id) ?? false
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            Task {
                if isOn {
                    await store.removeAthlete(athlete.id, from: teamID)
                } else {
                    await store.addAthlete(athlete.id, to: teamID)
                }
            }
        } label: {
            HStack(spacing: DS.Spacing.s12) {
                Monogram(size: 40, initials: CoachFormat.initials(athlete.displayName), kit: nil)
                VStack(alignment: .leading, spacing: 2) {
                    Text(athlete.displayName)
                        .style(.title3)
                        .foregroundStyle(DS.Colors.Ink.primary)
                        .lineLimit(1)
                    Text(athlete.subtitle)
                        .style(.micro)
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                        .lineLimit(1)
                }
                Spacer(minLength: DS.Spacing.s8)
                Image(systemName: isOn ? "checkmark.circle.fill" : "plus.circle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(isOn ? DS.Colors.Gold.base : DS.Colors.Ink.secondary)
            }
            .padding(DS.Spacing.s12)
            .background(DS.Colors.Bg.card)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(isOn ? DS.Colors.Gold.line : DS.Colors.Line.hairline, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
    }
}
