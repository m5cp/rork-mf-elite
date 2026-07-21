//
//  MyGamesView.swift
//  MFElite
//
//  The player's game schedule: add upcoming games, see what's next, and
//  swipe to remove. Entries drive the Match Day card on Today and the
//  night-before prep reminder.
//

import SwiftUI
import SwiftData

/// Navigation route to the player's game schedule.
struct MyGamesRoute: Hashable {}

struct MyGamesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GameEntry.date) private var games: [GameEntry]
    @State private var showAddGame = false
    @State private var teamFeed = TeamEventsFeed.shared

    /// Upcoming games only — past games auto-hide but stay in the store.
    private var upcoming: [GameEntry] {
        let start = Calendar.current.startOfDay(for: Date())
        return games.filter { $0.date >= start }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: DS.Spacing.s8) {
                    Eyebrow(text: "Schedule")
                    Text("My Games")
                        .style(.hero)
                        .foregroundStyle(DS.Colors.Ink.primary)
                }
                .padding(.top, DS.Spacing.s16)

                PrimaryButton(label: "Add game") {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showAddGame = true
                }
                .padding(.top, DS.Spacing.s20)

                if !teamFeed.events.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        Eyebrow(text: "Team schedule")
                            .padding(.top, DS.Spacing.s24)

                        VStack(spacing: 0) {
                            ForEach(Array(teamFeed.events.enumerated()), id: \.element.id) { idx, event in
                                teamEventRow(event)
                                if idx != teamFeed.events.count - 1 { Hairline() }
                            }
                        }
                        .padding(.horizontal, DS.Spacing.s16)
                        .background(DS.Colors.Bg.elevated)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                        .overlay(RoundedRectangle(cornerRadius: DS.Radius.lg).stroke(DS.Colors.Line.hairline, lineWidth: 1))
                        .padding(.top, DS.Spacing.s12)
                    }
                }

                if upcoming.isEmpty {
                    Card(padding: DS.Spacing.s16) {
                        VStack(alignment: .leading, spacing: DS.Spacing.s8) {
                            Eyebrow(text: "No games scheduled")
                            Text("Add your next game and Today will switch to Match Day prep on game day — plus a reminder the night before.")
                                .style(.callout)
                                .foregroundStyle(DS.Colors.Ink.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.top, DS.Spacing.s20)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        Eyebrow(text: "Upcoming")
                            .padding(.top, DS.Spacing.s24)

                        VStack(spacing: 0) {
                            ForEach(Array(upcoming.enumerated()), id: \.element.id) { idx, game in
                                gameRow(game)
                                if idx != upcoming.count - 1 { Hairline() }
                            }
                        }
                        .padding(.horizontal, DS.Spacing.s16)
                        .background(DS.Colors.Bg.elevated)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                        .overlay(RoundedRectangle(cornerRadius: DS.Radius.lg).stroke(DS.Colors.Line.hairline, lineWidth: 1))
                        .padding(.top, DS.Spacing.s12)
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.bottom, 120)
        }
        .background(DS.Colors.Bg.base)
        .scrollIndicators(.hidden)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task { await teamFeed.refresh() }
        .sheet(isPresented: $showAddGame) {
            AddGameSheet { date, opponent in
                addGame(date: date, opponent: opponent)
            }
            .preferredColorScheme(.dark)
        }
    }

    // MARK: - Rows

    private func teamEventRow(_ event: TeamEvent) -> some View {
        HStack(spacing: DS.Spacing.s16) {
            VStack(spacing: 2) {
                Text(event.startsAt, format: .dateTime.month(.abbreviated))
                    .style(.microSm)
                    .foregroundStyle(DS.Colors.Ink.tertiary)
                    .textCase(.uppercase)
                Text(event.startsAt, format: .dateTime.day())
                    .font(DS.Typography.num(size: 20))
                    .foregroundStyle(DS.Colors.Ink.primary)
            }
            .frame(width: 44, height: 44)
            .background(DS.Colors.Bg.raised)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(DS.Colors.Line.hairline, lineWidth: 1))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: DS.Spacing.s8) {
                    Text(event.kind.uppercased())
                        .style(.microSm)
                        .foregroundStyle(DS.Colors.Gold.textLight)
                    Text(event.title)
                        .style(.title3)
                        .foregroundStyle(DS.Colors.Ink.primary)
                        .lineLimit(1)
                }
                Text(event.startsAt.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute())
                     + (event.location.isEmpty ? "" : " · \(event.location)"))
                    .style(.micro)
                    .foregroundStyle(DS.Colors.Ink.tertiary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                Task {
                    let ok = await teamFeed.addToDeviceCalendar(event)
                    UINotificationFeedbackGenerator().notificationOccurred(ok ? .success : .error)
                }
            } label: {
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DS.Colors.Ink.secondary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel("Add to calendar")
        }
        .padding(.vertical, DS.Spacing.s12)
        .contentShape(Rectangle())
    }

    private func gameRow(_ game: GameEntry) -> some View {
        let isToday = Calendar.current.isDateInToday(game.date)
        return HStack(spacing: DS.Spacing.s16) {
            VStack(spacing: 2) {
                Text(game.date, format: .dateTime.month(.abbreviated))
                    .style(.microSm)
                    .foregroundStyle(DS.Colors.Ink.tertiary)
                    .textCase(.uppercase)
                Text(game.date, format: .dateTime.day())
                    .font(DS.Typography.num(size: 20))
                    .foregroundStyle(DS.Colors.Ink.primary)
            }
            .frame(width: 44, height: 44)
            .background(DS.Colors.Bg.raised)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(DS.Colors.Line.hairline, lineWidth: 1))

            VStack(alignment: .leading, spacing: 2) {
                Text(game.opponent.isEmpty ? "Game" : "vs \(game.opponent)")
                    .style(.title3)
                    .foregroundStyle(DS.Colors.Ink.primary)
                    .lineLimit(1)
                Text(isToday ? "Today" : game.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                    .style(.micro)
                    .foregroundStyle(isToday ? DS.Colors.Ink.primary : DS.Colors.Ink.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(DS.Motion.standardSpring) { delete(game) }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DS.Colors.Ink.quaternary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel("Delete game")
        }
        .padding(.vertical, DS.Spacing.s12)
        .contentShape(Rectangle())
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) { delete(game) } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Data

    private func addGame(date: Date, opponent: String) {
        let entry = GameEntry(date: date, opponent: opponent.trimmingCharacters(in: .whitespacesAndNewlines))
        modelContext.insert(entry)
        try? modelContext.save()
        SyncEngine.shared.enqueueGameEntry(entry)
        NotificationService.shared.scheduleGamePrepReminder(
            gameID: entry.id, gameDate: entry.date, opponent: entry.opponent
        )
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func delete(_ game: GameEntry) {
        NotificationService.shared.cancelGamePrepReminder(gameID: game.id)
        SyncEngine.shared.enqueueGameEntryDeletion(id: game.id)
        modelContext.delete(game)
        try? modelContext.save()
    }
}

// MARK: - Add game sheet

private struct AddGameSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var date: Date = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    @State private var opponent: String = ""

    var onSave: (Date, String) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.s16) {
                HStack {
                    Eyebrow(text: "Add Game")
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(DS.Colors.Ink.tertiary)
                            .frame(width: 32, height: 32)
                            .background(DS.Colors.Bg.raised)
                            .clipShape(Circle())
                    }
                    .buttonStyle(PressableButtonStyle())
                    .accessibilityLabel("Close")
                }
                .padding(.top, DS.Spacing.s20)

                DatePicker(
                    "Game date",
                    selection: $date,
                    in: Calendar.current.startOfDay(for: Date())...,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.graphical)
                .tint(.white)
                .padding(DS.Spacing.s8)
                .background(DS.Colors.Bg.elevated)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))

                VStack(alignment: .leading, spacing: DS.Spacing.s8) {
                    Eyebrow(text: "Opponent (optional)")
                    TextField("e.g. Eagles", text: $opponent)
                        .textInputAutocapitalization(.words)
                        .padding(DS.Spacing.s16)
                        .background(DS.Colors.Bg.elevated)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                        .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(DS.Colors.Line.hairline, lineWidth: 1))
                }

                PrimaryButton(label: "Save game") {
                    onSave(date, opponent)
                    dismiss()
                }
                .padding(.top, DS.Spacing.s8)
            }
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.bottom, DS.Spacing.s32)
        }
        .scrollIndicators(.hidden)
        .background(DS.Colors.Bg.base)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}
