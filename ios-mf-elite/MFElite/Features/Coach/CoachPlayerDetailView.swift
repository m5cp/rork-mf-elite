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

struct CoachPlayerDetailView: View {
    let player: RosterPlayer
    @Bindable var model: CoachViewModel
    @Environment(\.modelContext) private var modelContext
    @State private var sync = SyncEngine.shared

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
                    masterySection(detail)
                    trainingTimeSection(detail)
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
        .refreshable { await model.loadDetail(for: player, context: modelContext, force: true) }
        .task { await model.loadDetail(for: player, context: modelContext) }
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

    private func historySection(_ detail: CoachPlayerDetail) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s12) {
            Eyebrow(text: "Session History")
            if detail.history.isEmpty {
                emptyLine("No sessions logged yet.")
            } else {
                VStack(spacing: DS.Spacing.s8) {
                    ForEach(detail.history) { item in
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
                }
            }
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
        let isWhole = value.rounded() == value
        let number = isWhole ? String(Int(value)) : String(format: "%.1f", value)
        return unit.isEmpty ? number : "\(number) \(unit)"
    }
}
