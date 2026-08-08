//
//  CoachScheduleView.swift
//  MFElite
//
//  Coach-side schedule manager: publish practices/games/sessions the whole
//  team sees, and deactivate past or cancelled ones.
//

import SwiftUI

struct CoachScheduleRoute: Hashable {}

struct CoachScheduleView: View {
    @State private var feed = TeamEventsFeed.shared
    @State private var showComposer = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.s16) {
                Eyebrow(text: "Team schedule")
                Text("Practices & games")
                    .style(.title2)
                    .foregroundStyle(DS.Colors.Ink.primary)
                Text("Events you publish appear on the Today and My Games screens of the athletes you send them to. Players can add them to their own calendars.")
                    .style(.foot)
                    .foregroundStyle(DS.Colors.Ink.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                PrimaryButton(label: "Publish an event") { showComposer = true }

                if feed.events.isEmpty {
                    Text("No upcoming events published.")
                        .style(.foot)
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                        .padding(.top, DS.Spacing.s16)
                } else {
                    ForEach(feed.events) { event in
                        eventRow(event)
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.top, DS.Spacing.s16)
            .padding(.bottom, 120)
        }
        .background(DS.Colors.Bg.base)
        .navigationTitle("Schedule")
        .navigationBarTitleDisplayMode(.inline)
        .task { await feed.refresh() }
        .sheet(isPresented: $showComposer) {
            TeamEventComposer()
                .presentationDetents([.large])
        }
    }

    private func eventRow(_ event: TeamEvent) -> some View {
        Card {
            HStack(alignment: .top, spacing: DS.Spacing.s12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.kind.uppercased())
                        .style(.micro)
                        .foregroundStyle(DS.Colors.Gold.textLight)
                    Text(event.title)
                        .style(.body)
                        .foregroundStyle(DS.Colors.Ink.primary)
                    Text(event.startsAt.formatted(date: .abbreviated, time: .shortened))
                        .style(.foot)
                        .foregroundStyle(DS.Colors.Ink.secondary)
                    if !event.location.isEmpty {
                        Text(event.location)
                            .style(.micro)
                            .foregroundStyle(DS.Colors.Ink.tertiary)
                    }
                }
                Spacer()
                Button("Remove") {
                    Task { await feed.deactivate(event) }
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DS.Colors.Ink.tertiary)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
            }
        }
    }
}

// MARK: - Composer

struct TeamEventComposer: View {
    @Environment(\.dismiss) private var dismiss
    @State private var kind = "practice"
    @State private var title = ""
    @State private var startsAt = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    @State private var durationMinutes = 90
    @State private var location = ""
    @State private var notes = ""
    @State private var isPublishing = false
    @State private var failed = false
    @State private var audience = BroadcastAudience()

    private let kinds = ["practice", "game", "session", "other"]

    var body: some View {
        NavigationStack {
            Form {
                Picker("Type", selection: $kind) {
                    ForEach(kinds, id: \.self) { Text($0.capitalized).tag($0) }
                }
                HStack(spacing: DS.Spacing.s8) {
                    TextField("Title (e.g. Tuesday Training)", text: $title)
                    // The only required field on this form — the check confirms
                    // it, so Publish being tappable is never a surprise.
                    ConfirmBadge(isConfirmed: !title.trimmingCharacters(in: .whitespaces).isEmpty,
                                 label: "Set", unconfirmedLabel: "Title needed")
                }
                DatePicker("Starts", selection: $startsAt)
                Stepper("Duration: \(durationMinutes) min", value: $durationMinutes, in: 30...240, step: 15)
                TextField("Location (optional)", text: $location)
                TextField("Notes (optional)", text: $notes, axis: .vertical)

                Section {
                    AudiencePickerSection(audience: $audience)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                }

                if failed {
                    Text("Publish failed — check your connection and try again.")
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle("New event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isPublishing ? "Publishing…" : "Publish") {
                        Task {
                            isPublishing = true
                            failed = false
                            let ends = startsAt.addingTimeInterval(Double(durationMinutes) * 60)
                            let ok = await TeamEventsFeed.shared.publish(
                                kind: kind, title: title, startsAt: startsAt,
                                endsAt: ends, location: location, notes: notes,
                                audience: audience
                            )
                            isPublishing = false
                            if ok { dismiss() } else { failed = true }
                        }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isPublishing || !audience.isValid)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
