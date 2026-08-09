//
//  TeamStatsReportEditor.swift
//  MFElite
//
//  One game, filed by the coach: who they played, how it finished, and a line
//  per player. This is the only place stats are entered — everything on the
//  season sheet is rolled up from these.
//
//  The form hands the finished report back to its caller rather than saving it
//  itself, the same way `AnnouncementComposerView` does, so the screen that
//  owns the store is the one that reports a failure.
//

import SwiftUI

struct TeamStatsReportEditor: View {
    let roster: [TeamStatsPlayer]
    /// Scheduled games this report can be attached to.
    let games: [TeamStatsScheduledGame]
    let onSave: (TeamStatReport) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: TeamStatReport

    init(
        report: TeamStatReport,
        roster: [TeamStatsPlayer],
        games: [TeamStatsScheduledGame],
        onSave: @escaping (TeamStatReport) -> Void
    ) {
        self.roster = roster
        self.games = games
        self.onSave = onSave

        // Seed a line for every current squad member so the form can bind
        // straight into the array by index, keeping whatever was already
        // recorded for the players who have one.
        var existing: [String: TeamStatLine] = [:]
        for line in report.lines { existing[line.playerID] = line }
        var merged = roster.map { existing[$0.id] ?? TeamStatLine(playerID: $0.id) }

        // A line belonging to someone who has since left the squad is carried
        // through untouched rather than dropped. It isn't editable here, but
        // removing a player from a team should not quietly rewrite a game that
        // has already been played.
        let current = Set(roster.map { $0.id })
        merged.append(contentsOf: report.lines.filter { !current.contains($0.playerID) })

        var seeded = report
        seeded.lines = merged
        _draft = State(initialValue: seeded)
    }

    private var opponentIsSet: Bool {
        !draft.opponent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                gameSection
                playersSection
            }
            // Attached to the form rather than to the section they belong to:
            // a `Section` wrapped in a modifier is no longer plainly a section
            // to the enclosing `Form`, and these watch the draft, not a view.
            //
            // The score is what a coach types first, so the result follows it.
            // They can still override the picker afterwards; touching the score
            // again re-derives it, which is the predictable half of that trade.
            .onChange(of: draft.goalsFor) { _, _ in syncResult() }
            .onChange(of: draft.goalsAgainst) { _, _ in syncResult() }
            .onChange(of: draft.gameDate) { _, newValue in
                draft.season = TeamStatsFormat.season(for: newValue)
            }
            .onChange(of: draft.eventID) { _, newValue in adoptScheduledGame(newValue) }
            .navigationTitle("Game report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(draft)
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .disabled(!opponentIsSet)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Game

    private var gameSection: some View {
        Section {
            if !games.isEmpty { schedulePicker }

            HStack(spacing: DS.Spacing.s8) {
                TextField("Opponent", text: $draft.opponent)
                    .textInputAutocapitalization(.words)
                // The one field that gates Save — the check says the
                // requirement is met, rather than leaving the coach to work
                // that out from a dimmed button in the navigation bar.
                ConfirmBadge(
                    isConfirmed: opponentIsSet,
                    label: "Set",
                    unconfirmedLabel: "Opponent needed"
                )
            }

            DatePicker("Date", selection: $draft.gameDate, displayedComponents: .date)

            Picker("Result", selection: $draft.result) {
                ForEach(TeamStatResult.allCases) { value in
                    Text(value.label).tag(value)
                }
            }

            Stepper("Goals for: \(draft.goalsFor)", value: $draft.goalsFor, in: 0...50)
            Stepper("Goals against: \(draft.goalsAgainst)", value: $draft.goalsAgainst, in: 0...50)
        } header: {
            Text("Game")
        } footer: {
            Text("Attaching a scheduled game is what clears it off the missing-reports count. A game that was never on the schedule still counts as played.")
        }
    }

    private var schedulePicker: some View {
        Picker("Scheduled game", selection: $draft.eventID) {
            Text("Not on the schedule").tag(nil as String?)
            ForEach(games) { game in
                Text(scheduleLabel(game)).tag(game.id as String?)
            }
        }
    }

    private func scheduleLabel(_ game: TeamStatsScheduledGame) -> String {
        "\(game.title) \u{00B7} \(CoachFormat.shortDate(game.startsAt))"
    }

    private func syncResult() {
        draft.result = TeamStatResult.from(goalsFor: draft.goalsFor, goalsAgainst: draft.goalsAgainst)
    }

    /// Picking a scheduled game fills in what the schedule already knows.
    /// The opponent is only borrowed from the event title when the coach hasn't
    /// typed one — an event called "Home game" shouldn't overwrite "Elizabethtown".
    private func adoptScheduledGame(_ eventID: String?) {
        guard let eventID, let game = games.first(where: { $0.id == eventID }) else { return }
        draft.gameDate = game.startsAt
        draft.season = game.season
        if !opponentIsSet { draft.opponent = game.title }
    }

    // MARK: - Players

    private var playersSection: some View {
        Section {
            if roster.isEmpty {
                Text("No athletes on this team yet. Add them in Teams & rosters and they'll appear here.")
            } else {
                ForEach(roster) { player in
                    playerRow(player)
                }
            }
        } header: {
            Text("Players")
        } footer: {
            Text("Tick Played for everyone who appeared. Season averages divide by a player's own games, not the team's.")
        }
    }

    @ViewBuilder
    private func playerRow(_ player: TeamStatsPlayer) -> some View {
        if let index = lineIndex(for: player.id) {
            DisclosureGroup {
                Toggle("Played", isOn: $draft.lines[index].played)
                Stepper("Goals: \(draft.lines[index].goals)",
                        value: $draft.lines[index].goals, in: 0...20)
                Stepper("Assists: \(draft.lines[index].assists)",
                        value: $draft.lines[index].assists, in: 0...20)
                Stepper("Goalkeeper saves: \(draft.lines[index].saves)",
                        value: $draft.lines[index].saves, in: 0...60)
                Stepper("Goals allowed: \(draft.lines[index].goalsAllowed)",
                        value: $draft.lines[index].goalsAllowed, in: 0...30)
                Toggle("Shutout", isOn: $draft.lines[index].shutout)
            } label: {
                playerLabel(player, line: draft.lines[index])
            }
        }
    }

    private func playerLabel(_ player: TeamStatsPlayer, line: TeamStatLine) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(player.kitNumber.isEmpty ? player.displayName : "#\(player.kitNumber)  \(player.displayName)")
                .style(.body)
                .foregroundStyle(DS.Colors.Ink.primary)
                .lineLimit(1)
            Text(summary(line))
                .style(.micro)
                .foregroundStyle(line.played ? DS.Colors.Gold.textLight : DS.Colors.Ink.quaternary)
        }
    }

    /// A one-glance recap so the coach can scan the list without opening every
    /// row to check what they already entered.
    private func summary(_ line: TeamStatLine) -> String {
        guard line.played else { return "Did not play" }
        var parts: [String] = []
        if line.goals > 0 { parts.append("\(line.goals)G") }
        if line.assists > 0 { parts.append("\(line.assists)A") }
        if line.saves > 0 { parts.append("\(line.saves) saves") }
        if line.goalsAllowed > 0 { parts.append("\(line.goalsAllowed) allowed") }
        if line.shutout { parts.append("shutout") }
        return parts.isEmpty ? "Played" : parts.joined(separator: " \u{00B7} ")
    }

    private func lineIndex(for playerID: String) -> Int? {
        draft.lines.firstIndex { $0.playerID == playerID }
    }
}
