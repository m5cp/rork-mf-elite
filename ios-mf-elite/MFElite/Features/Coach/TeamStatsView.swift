//
//  TeamStatsView.swift
//  MFElite
//
//  The coach's season stat sheet: the four sections of the paper sheet he
//  already keeps (Players, Team Stats, Scoring, Goalkeeper), rolled up from the
//  per-game reports filed on this screen.
//
//  Everything here is scoped to one team the signed-in coach controls. Sharing
//  goes out through the system share sheet or as an announcement addressed to
//  that team — never app-wide, and never through a new social surface.
//

import SwiftUI

// MARK: - Dashboard entry

/// The Coach dashboard section that opens the stat sheet.
///
/// A destination `NavigationLink` rather than a `navigationDestination(for:)`
/// route so that wiring this feature into the dashboard is one line in
/// `CoachView` and nothing else.
struct TeamStatsEntrySection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s12) {
            Eyebrow(text: "Team Stats")
            NavigationLink {
                TeamStatsView()
            } label: {
                HStack(spacing: DS.Spacing.s12) {
                    SectionIcon(systemName: "list.number")
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Season stat sheet")
                            .style(.title3)
                            .foregroundStyle(DS.Colors.Ink.primary)
                        Text("File a report per game; the season totals roll up")
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
}

// MARK: - The sheet

struct TeamStatsView: View {
    @State private var store = TeamStatsStore.shared
    @State private var teams = TeamsStore.shared
    @State private var teamID = ""
    @State private var season = TeamStatsFormat.season(for: Date())
    /// Non-nil while the per-game editor is open. Also carries the draft for a
    /// brand-new report, so there is one piece of state rather than two that
    /// can disagree.
    @State private var editing: TeamStatReport?
    @State private var shareText: ShareableText?
    @State private var pendingDelete: TeamStatReport?
    @State private var showPostConfirm = false
    @State private var actionError: String?
    @State private var postedConfirmation = false

    private var selectedTeam: CoachTeam? {
        store.manageableTeams.first { $0.id == teamID }
    }

    private var currentSheet: TeamStatsSheet {
        store.sheet(teamName: selectedTeam?.name ?? "Team", season: season)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.s20) {
                header
                content
            }
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.top, DS.Spacing.s16)
            .padding(.bottom, 120)
        }
        .background(DS.Colors.Bg.base)
        .scrollIndicators(.hidden)
        .navigationTitle("Team Stats")
        .navigationBarTitleDisplayMode(.inline)
        .task { await initialLoad() }
        .refreshable {
            if !teamID.isEmpty { await store.load(teamID: teamID) }
        }
        .sheet(item: $editing) { report in
            TeamStatsReportEditor(
                report: report,
                roster: store.roster,
                games: store.linkableGames(season: report.season, currentEventID: report.eventID),
                onSave: { saved in fileReport(saved) }
            )
            .presentationDetents([.large])
        }
        .sheet(item: $shareText) { item in
            ShareSheet(items: [item.text])
                .presentationDetents([.medium, .large])
        }
        .confirmationDialog(
            "Post these stats to \(selectedTeam?.name ?? "your team")?",
            isPresented: $showPostConfirm,
            titleVisibility: .visible
        ) {
            Button("Post") { postToTeam() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Only the athletes on this team see it, on their Today screen. Nobody else in the app does.")
        }
        .confirmationDialog(
            "Delete this game report?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { deletePending() }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: {
            Text("The season totals recalculate without it. Nothing else changes.")
        }
        .alert("Couldn't do that", isPresented: Binding(
            get: { actionError != nil },
            set: { if !$0 { actionError = nil } }
        )) {
            Button("OK", role: .cancel) { actionError = nil }
        } message: {
            Text(actionError ?? "")
        }
        .alert("Posted to your team", isPresented: $postedConfirmation) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The athletes on \(selectedTeam?.name ?? "this team") will see the summary on their Today screen.")
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s8) {
            ArtworkBanner(name: MFArtwork.teams)
                .padding(.bottom, DS.Spacing.s12)

            Eyebrow(text: "Cumulative season")
            Text(selectedTeam?.name ?? "Team stats")
                .style(.title2)
                .foregroundStyle(DS.Colors.Ink.primary)
            Text("One report per game. Goals, assists, saves and clean sheets roll up into the season sheet below — the same sheet you can share or post to this team.")
                .style(.foot)
                .foregroundStyle(DS.Colors.Ink.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var content: some View {
        if store.manageableTeams.isEmpty {
            // Don't tell a coach they have no teams before we have looked —
            // `manageableTeams` reads an empty `TeamsStore` on first appearance.
            if teams.teamsState == .idle || teams.teamsState == .loading {
                loadingState
            } else {
                noTeamsState
            }
        } else {
            teamPicker
            if store.seasons.count > 1 { seasonPicker }

            if store.state == .loading && store.reports.isEmpty {
                loadingState
            } else if store.state == .failed && store.reports.isEmpty {
                retryState
            } else {
                loadedContent(currentSheet)
            }
        }
    }

    /// The rolled-up sheet is built once and handed down, rather than being
    /// recomputed by every section that needs a number off it.
    private func loadedContent(_ current: TeamStatsSheet) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s20) {
            summaryLine(current)
            teamStatsBox(current)
            playersSection(current)
            scoringSection(current)
            goalkeeperSection(current)
            actions(current)
            reportsSection(current)
        }
    }

    private var noTeamsState: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s8) {
            Text("No teams yet")
                .style(.title3)
                .foregroundStyle(DS.Colors.Ink.primary)
            Text("Stats are filed against a team you coach — one you created, or one with your players on it. Build a team in Teams & rosters, or ask the head coach to add your players to theirs.")
                .style(.foot)
                .foregroundStyle(DS.Colors.Ink.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DS.Spacing.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.Colors.Bg.card)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(DS.Colors.Line.hairline, lineWidth: 1))
    }

    private var teamPicker: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s8) {
            Eyebrow(text: "Team")
            Menu {
                ForEach(store.manageableTeams) { team in
                    Button(team.name) { selectTeam(team.id) }
                }
            } label: {
                pickerLabel(selectedTeam?.name ?? "Choose a team")
            }
        }
    }

    private var seasonPicker: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s8) {
            Eyebrow(text: "Season")
            Menu {
                ForEach(store.seasons, id: \.self) { value in
                    Button(value) { season = value }
                }
            } label: {
                pickerLabel(season)
            }
        }
    }

    private func pickerLabel(_ text: String) -> some View {
        HStack(spacing: DS.Spacing.s8) {
            Text(text)
                .style(.body)
                .foregroundStyle(DS.Colors.Ink.primary)
                .lineLimit(1)
            Spacer(minLength: 0)
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DS.Colors.Ink.quaternary)
        }
        .padding(.horizontal, DS.Spacing.s16)
        .frame(height: 48)
        .frame(maxWidth: .infinity)
        .background(DS.Colors.Bg.card)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(DS.Colors.Line.hairline, lineWidth: 1))
        .contentShape(Rectangle())
    }

    private func summaryLine(_ current: TeamStatsSheet) -> some View {
        Text("\(current.gamesPlayed) game\(current.gamesPlayed == 1 ? "" : "s") played \u{00B7} \(current.reportsFiled) stat report\(current.reportsFiled == 1 ? "" : "s") filed")
            .style(.micro)
            .foregroundStyle(DS.Colors.Gold.textLight)
    }

    private func teamStatsBox(_ current: TeamStatsSheet) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s12) {
            Eyebrow(text: "Team Stats")
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: DS.Spacing.s12),
                    GridItem(.flexible(), spacing: DS.Spacing.s12)
                ],
                spacing: DS.Spacing.s12
            ) {
                statCard(value: "\(current.gamesPlayed)", label: "Games played")
                statCard(value: "\(current.reportsFiled)", label: "Stat reports filed")
                statCard(
                    value: "\(current.missingReports)",
                    label: "Missing stat reports",
                    tint: current.missingReports > 0 ? DS.Colors.Status.warn : nil
                )
                statCard(value: current.record, label: "Win-loss record")
                statCard(value: "\(current.goalsScored)", label: "Goals scored")
                statCard(value: "\(current.goalsAllowed)", label: "Goals allowed")
            }
        }
    }

    private func statCard(value: String, label: String, tint: Color? = nil) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s4) {
            Text(value)
                .style(.num(size: 26))
                .foregroundStyle(tint ?? DS.Colors.Ink.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .style(.micro)
                .foregroundStyle(DS.Colors.Ink.quaternary)
                .lineLimit(2)
        }
        .padding(DS.Spacing.s16)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .background(DS.Colors.Bg.card)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(DS.Colors.Line.hairline, lineWidth: 1))
    }

    private func playersSection(_ current: TeamStatsSheet) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s12) {
            Eyebrow(text: "Players")
            TeamStatsTable(
                columns: [
                    TeamStatsColumn(title: "Player", width: 132, leading: true),
                    TeamStatsColumn(title: "#", width: 44),
                    TeamStatsColumn(title: "Grade", width: 56),
                    TeamStatsColumn(title: "GP", width: 44)
                ],
                rows: current.players.map { player in
                    TeamStatsTableRow(id: player.id, values: [
                        player.displayName,
                        player.number,
                        player.grade,
                        "\(player.gamesPlayed)"
                    ])
                },
                emptyMessage: "No athletes on this team yet. Add them in Teams & rosters."
            )
        }
    }

    private func scoringSection(_ current: TeamStatsSheet) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s12) {
            Eyebrow(text: "Scoring")
            TeamStatsTable(
                columns: [
                    TeamStatsColumn(title: "Player", width: 132, leading: true),
                    TeamStatsColumn(title: "#", width: 44),
                    TeamStatsColumn(title: "Grade", width: 56),
                    TeamStatsColumn(title: "GP", width: 44),
                    TeamStatsColumn(title: "G", width: 44),
                    TeamStatsColumn(title: "G avg.", width: 60),
                    TeamStatsColumn(title: "A", width: 44),
                    TeamStatsColumn(title: "A avg.", width: 60),
                    TeamStatsColumn(title: "Pts", width: 48),
                    TeamStatsColumn(title: "Pts avg.", width: 68)
                ],
                rows: current.scoring.map { player in
                    TeamStatsTableRow(id: player.id, values: [
                        player.displayName,
                        player.number,
                        player.grade,
                        "\(player.gamesPlayed)",
                        "\(player.goals)",
                        TeamStatsFormat.avg(player.goalsAvg),
                        "\(player.assists)",
                        TeamStatsFormat.avg(player.assistsAvg),
                        "\(player.points)",
                        TeamStatsFormat.avg(player.pointsAvg)
                    ])
                },
                emptyMessage: "No games reported yet."
            )
            Text("Points count a goal as two and an assist as one.")
                .style(.micro)
                .foregroundStyle(DS.Colors.Ink.quaternary)
        }
    }

    private func goalkeeperSection(_ current: TeamStatsSheet) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s12) {
            Eyebrow(text: "Goalkeeper")
            TeamStatsTable(
                columns: [
                    TeamStatsColumn(title: "Player", width: 132, leading: true),
                    TeamStatsColumn(title: "#", width: 44),
                    TeamStatsColumn(title: "Grade", width: 56),
                    TeamStatsColumn(title: "GP", width: 44),
                    TeamStatsColumn(title: "Saves", width: 60),
                    TeamStatsColumn(title: "Sv avg.", width: 66),
                    TeamStatsColumn(title: "GA", width: 48),
                    TeamStatsColumn(title: "GA avg.", width: 68),
                    TeamStatsColumn(title: "SO", width: 48),
                    TeamStatsColumn(title: "SO avg.", width: 68)
                ],
                rows: current.goalkeepers.map { player in
                    TeamStatsTableRow(id: player.id, values: [
                        player.displayName,
                        player.number,
                        player.grade,
                        "\(player.gamesPlayed)",
                        "\(player.saves)",
                        TeamStatsFormat.avg(player.savesAvg),
                        "\(player.goalsAllowed)",
                        TeamStatsFormat.avg(player.goalsAllowedAvg),
                        "\(player.shutouts)",
                        TeamStatsFormat.avg(player.shutoutsAvg)
                    ])
                },
                emptyMessage: "No goalkeeper minutes recorded yet."
            )
        }
    }

    private func actions(_ current: TeamStatsSheet) -> some View {
        VStack(spacing: DS.Spacing.s8) {
            PrimaryButton(label: "File a game report") { startNewReport() }
                .disabled(teamID.isEmpty)

            HStack(spacing: DS.Spacing.s8) {
                secondaryAction(icon: "square.and.arrow.up", title: "Share sheet") {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    shareText = ShareableText(text: TeamStatsExport.sheetText(current))
                }
                secondaryAction(icon: "megaphone.fill", title: "Post to team") {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    showPostConfirm = true
                }
            }
        }
    }

    private func secondaryAction(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.s8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(title)
                    .style(.foot)
                    .fontWeight(.semibold)
                    .lineLimit(1)
            }
            .foregroundStyle(DS.Colors.Ink.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(DS.Colors.Bg.card)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(DS.Colors.Line.hairline, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
    }

    /// The filed-report list, with the same count the Team Stats box shows —
    /// taken off the rolled-up sheet rather than counted again here, so the two
    /// can never disagree on screen.
    private func reportsSection(_ current: TeamStatsSheet) -> some View {
        let filed = store.filedReports(season: season)
        return VStack(alignment: .leading, spacing: DS.Spacing.s12) {
            HStack(spacing: DS.Spacing.s8) {
                Eyebrow(text: "Filed reports")
                Spacer(minLength: 0)
                Text("\(current.reportsFiled)")
                    .style(.micro)
                    .foregroundStyle(DS.Colors.Ink.quaternary)
            }
            if filed.isEmpty {
                Text("Nothing filed for \(season) yet.")
                    .style(.foot)
                    .foregroundStyle(DS.Colors.Ink.tertiary)
            } else {
                LazyVStack(spacing: DS.Spacing.s8) {
                    ForEach(filed) { report in
                        reportRow(report)
                    }
                }
            }
        }
    }

    private func reportRow(_ report: TeamStatReport) -> some View {
        HStack(spacing: DS.Spacing.s12) {
            Text(report.result.rawValue)
                .style(.num(size: 16))
                .foregroundStyle(resultTint(report.result))
                .frame(width: 32, height: 32)
                .background(DS.Colors.Bg.raised)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(report.opponent.isEmpty ? "Opponent not set" : report.opponent)
                    .style(.title3)
                    .foregroundStyle(DS.Colors.Ink.primary)
                    .lineLimit(1)
                Text("\(report.scoreLine) \u{00B7} \(CoachFormat.shortDate(report.gameDate))")
                    .style(.micro)
                    .foregroundStyle(DS.Colors.Ink.tertiary)
            }

            Spacer(minLength: DS.Spacing.s8)

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                editing = report
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DS.Colors.Ink.secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel("Edit report")

            Button {
                pendingDelete = report
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DS.Colors.Ink.quaternary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel("Delete report")
        }
        .padding(DS.Spacing.s12)
        .background(DS.Colors.Bg.card)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(DS.Colors.Line.hairline, lineWidth: 1))
    }

    private func resultTint(_ result: TeamStatResult) -> Color {
        switch result {
        case .win:  return DS.Colors.Status.good
        case .loss: return DS.Colors.Status.bad
        case .draw: return DS.Colors.Ink.tertiary
        }
    }

    private var loadingState: some View {
        ProgressView()
            .tint(DS.Colors.Ink.tertiary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.s48)
    }

    private var retryState: some View {
        VStack(spacing: DS.Spacing.s8) {
            Text("Couldn't load these stats")
                .style(.title3)
                .foregroundStyle(DS.Colors.Ink.primary)
            Text("Pull to retry, or check your connection.")
                .style(.foot)
                .foregroundStyle(DS.Colors.Ink.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.s48)
    }

    // MARK: - Actions

    private func initialLoad() async {
        if teams.teams.isEmpty { await teams.loadTeams() }
        // Before `manageableTeams` is read for the first time. It depends on
        // this set, and `load(teamID:)` — the only other caller — is gated on
        // having already picked a team, so without this a coach who created
        // no teams of their own could never get past the empty state.
        await store.loadCoachedPlayers()
        if teamID.isEmpty, let first = store.manageableTeams.first { teamID = first.id }
        guard !teamID.isEmpty else { return }
        await store.load(teamID: teamID)
        alignSeason()
    }

    private func selectTeam(_ id: String) {
        guard id != teamID else { return }
        teamID = id
        Task {
            await store.load(teamID: id)
            alignSeason()
        }
    }

    /// Land on a season that actually has something in it. Defaulting to the
    /// current year would show an empty sheet in January to a coach whose
    /// season finished in November.
    private func alignSeason() {
        let available = store.seasons
        guard !available.contains(season) || store.filedReports(season: season).isEmpty else { return }
        if let withReports = available.first(where: { !store.filedReports(season: $0).isEmpty }) {
            season = withReports
        } else if let newest = available.first {
            season = newest
        }
    }

    private func startNewReport() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        editing = TeamStatReport.draft(teamID: teamID, season: season, roster: store.roster)
    }

    private func fileReport(_ report: TeamStatReport) {
        Task {
            let ok = await store.save(report)
            if ok {
                season = report.season
            } else {
                actionError = "Couldn't save that game report. Check your connection and try again — nothing was recorded."
            }
        }
    }

    private func deletePending() {
        guard let report = pendingDelete else { return }
        pendingDelete = nil
        Task {
            let ok = await store.delete(report)
            if !ok {
                actionError = "Couldn't delete that report. It's still on the server — check your connection, or ask a head coach if it isn't your team."
            }
        }
    }

    private func postToTeam() {
        guard let team = selectedTeam else { return }
        let summary = TeamStatsExport.announcement(currentSheet)
        Task {
            let ok = await store.postToTeam(teamID: team.id, teamName: team.name, summary: summary)
            if ok {
                postedConfirmation = true
            } else {
                actionError = "Couldn't post those stats. Check your connection and try again — your players didn't receive anything."
            }
        }
    }
}

// MARK: - Table

/// One column of a stat table. Titles are unique inside a table, so they double
/// as the `ForEach` identity.
struct TeamStatsColumn: Identifiable {
    let title: String
    let width: CGFloat
    var leading: Bool = false

    var id: String { title }
}

struct TeamStatsTableRow: Identifiable {
    let id: String
    let values: [String]
}

/// One rendered cell. Columns and values are zipped into these up front so the
/// row body never has to index two arrays in step — a mismatch there would
/// print a save total under the goals heading, silently.
private struct TeamStatsCell: Identifiable {
    let id: String
    let text: String
    let width: CGFloat
    let leading: Bool
}

/// A stat table that scrolls sideways.
///
/// The Scoring and Goalkeeper tables carry ten columns each; squeezing those
/// into a phone width would either truncate the numbers or shrink them past
/// reading. Fixed column widths inside a horizontal scroll keep the header and
/// the rows in step, which is the one thing a stat sheet cannot get wrong.
struct TeamStatsTable: View {
    let columns: [TeamStatsColumn]
    let rows: [TeamStatsTableRow]
    let emptyMessage: String

    var body: some View {
        if rows.isEmpty {
            Text(emptyMessage)
                .style(.foot)
                .foregroundStyle(DS.Colors.Ink.tertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(DS.Spacing.s16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DS.Colors.Bg.card)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(DS.Colors.Line.hairline, lineWidth: 1))
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    headerRow
                    Hairline()
                        .padding(.vertical, DS.Spacing.s8)
                    ForEach(rows) { row in
                        bodyRow(row)
                    }
                }
                .padding(DS.Spacing.s16)
            }
            .background(DS.Colors.Bg.card)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(DS.Colors.Line.hairline, lineWidth: 1))
        }
    }

    private var headerRow: some View {
        HStack(spacing: DS.Spacing.s8) {
            ForEach(columns) { column in
                Text(column.title)
                    .style(.micro)
                    .foregroundStyle(DS.Colors.Ink.quaternary)
                    .lineLimit(1)
                    .frame(width: column.width, alignment: column.leading ? .leading : .trailing)
            }
        }
    }

    private func bodyRow(_ row: TeamStatsTableRow) -> some View {
        HStack(spacing: DS.Spacing.s8) {
            ForEach(cells(for: row)) { cell in
                Text(cell.text)
                    .style(.foot)
                    .foregroundStyle(cell.leading ? DS.Colors.Ink.primary : DS.Colors.Ink.secondary)
                    .lineLimit(1)
                    .frame(width: cell.width, alignment: cell.leading ? .leading : .trailing)
            }
        }
        .padding(.vertical, DS.Spacing.s4)
    }

    private func cells(for row: TeamStatsTableRow) -> [TeamStatsCell] {
        columns.enumerated().map { index, column in
            TeamStatsCell(
                id: column.title,
                text: index < row.values.count ? row.values[index] : "",
                width: column.width,
                leading: column.leading
            )
        }
    }
}
