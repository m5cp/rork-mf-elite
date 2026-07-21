//
//  AudiencePickerView.swift
//  MFElite
//
//  Reusable "who receives this" picker used as the first step of every coach
//  publish flow (schedule events, announcements, workouts). A segmented choice
//  of Everyone / Teams / Athletes, followed by a checklist when Teams or
//  Athletes is selected. Reads teams + athletes from TeamsStore.
//

import SwiftUI

/// Compact inline audience picker for embedding inside a composer form.
struct AudiencePickerSection: View {
    @Binding var audience: BroadcastAudience
    @State private var store = TeamsStore.shared
    @State private var athleteQuery = ""

    private var teams: [CoachTeam] { store.teams }

    private var filteredAthletes: [TeamAthlete] {
        let query = athleteQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return store.athletes }
        return store.athletes.filter {
            $0.displayName.lowercased().contains(query)
                || ($0.username?.lowercased().contains(query) ?? false)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s12) {
            Eyebrow(text: "Send to")

            scopePicker

            switch audience.scope {
            case .everyone:
                Text("This goes to every athlete in the app.")
                    .style(.micro)
                    .foregroundStyle(DS.Colors.Ink.tertiary)
            case .teams:
                teamChecklist
            case .athletes:
                athleteChecklist
            }
        }
        .task {
            if store.teams.isEmpty { await store.loadTeams() }
            if store.athletes.isEmpty { await store.loadAthletes() }
        }
    }

    // MARK: - Scope

    private var scopePicker: some View {
        HStack(spacing: DS.Spacing.s8) {
            ForEach(BroadcastAudience.Scope.allCases) { scope in
                let selected = audience.scope == scope
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    audience.scope = scope
                } label: {
                    Text(scope.label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(selected ? DS.Colors.Gold.inkOnGold : DS.Colors.Ink.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.s12)
                        .background(
                            selected ? AnyShapeStyle(DS.Colors.Gold.base) : AnyShapeStyle(DS.Colors.Bg.raised),
                            in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                        )
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
    }

    // MARK: - Teams

    @ViewBuilder
    private var teamChecklist: some View {
        if teams.isEmpty {
            Text("You haven't created any teams yet. Create one from Coach → Teams first.")
                .style(.micro)
                .foregroundStyle(DS.Colors.Ink.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            VStack(spacing: DS.Spacing.s8) {
                ForEach(teams) { team in
                    let on = audience.teamIDs.contains(team.id)
                    checkRow(
                        title: team.name,
                        subtitle: team.label.isEmpty
                            ? "\(team.memberCount) athlete\(team.memberCount == 1 ? "" : "s")"
                            : "\(team.label) · \(team.memberCount) athlete\(team.memberCount == 1 ? "" : "s")",
                        isOn: on
                    ) {
                        if on { audience.teamIDs.remove(team.id) } else { audience.teamIDs.insert(team.id) }
                    }
                }
            }
        }
    }

    // MARK: - Athletes

    @ViewBuilder
    private var athleteChecklist: some View {
        if store.athletes.isEmpty {
            Text("No athletes found yet.")
                .style(.micro)
                .foregroundStyle(DS.Colors.Ink.tertiary)
        } else {
            searchField
            VStack(spacing: DS.Spacing.s8) {
                ForEach(filteredAthletes.prefix(40)) { athlete in
                    let on = audience.athleteIDs.contains(athlete.id)
                    checkRow(title: athlete.displayName, subtitle: athlete.subtitle, isOn: on) {
                        if on { audience.athleteIDs.remove(athlete.id) } else { audience.athleteIDs.insert(athlete.id) }
                    }
                }
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: DS.Spacing.s8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DS.Colors.Ink.quaternary)
            TextField("", text: $athleteQuery, prompt: Text("Search athletes")
                .foregroundColor(DS.Colors.Ink.quaternary))
                .style(.body)
                .foregroundStyle(DS.Colors.Ink.primary)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, DS.Spacing.s12)
        .frame(height: 44)
        .background(DS.Colors.Bg.raised, in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
    }

    // MARK: - Row

    private func checkRow(title: String, subtitle: String, isOn: Bool, toggle: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            toggle()
        } label: {
            HStack(spacing: DS.Spacing.s12) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isOn ? DS.Colors.Gold.base : DS.Colors.Ink.quaternary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .style(.body)
                        .foregroundStyle(DS.Colors.Ink.primary)
                        .lineLimit(1)
                    Text(subtitle)
                        .style(.micro)
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(DS.Spacing.s12)
            .background(DS.Colors.Bg.card, in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .stroke(isOn ? DS.Colors.Gold.line : DS.Colors.Line.hairline, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
    }
}
