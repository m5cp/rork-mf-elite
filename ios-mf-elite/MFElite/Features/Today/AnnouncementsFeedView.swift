//
//  AnnouncementsFeedView.swift
//  MFElite
//
//  Player-side feed of recent coach announcements. Reads the locally cached
//  announcements (populated by AnnouncementFeed) and lets the player filter
//  them by All / Team / General with a segmented control. Read-only — nothing
//  here touches curriculum, progress, or history.
//

import SwiftUI
import SwiftData

/// Navigation route to the player's announcement feed.
struct AnnouncementsFeedRoute: Hashable {}

struct AnnouncementsFeedView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Announcement.createdAt, order: .reverse) private var announcements: [Announcement]
    @State private var filter: AnnouncementFilter = .all

    /// The three feed buckets exposed by the segmented control.
    private enum AnnouncementFilter: String, CaseIterable, Identifiable {
        case all, team, general
        var id: String { rawValue }

        var label: String {
            switch self {
            case .all: return "All"
            case .team: return "Team"
            case .general: return "General"
            }
        }
    }

    /// Announcements matching the active filter.
    private var filtered: [Announcement] {
        switch filter {
        case .all: return announcements
        case .team: return announcements.filter(\.isTeamTargeted)
        case .general: return announcements.filter { !$0.isTeamTargeted }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: DS.Spacing.s8) {
                    Eyebrow(text: "From your coach")
                    Text("Announcements")
                        .style(.hero)
                        .foregroundStyle(DS.Colors.Ink.primary)
                }
                .padding(.top, DS.Spacing.s16)

                filterPicker
                    .padding(.top, DS.Spacing.s20)

                if filtered.isEmpty {
                    emptyState
                        .padding(.top, DS.Spacing.s20)
                } else {
                    VStack(spacing: DS.Spacing.s12) {
                        ForEach(filtered) { announcement in
                            announcementCard(announcement)
                        }
                    }
                    .padding(.top, DS.Spacing.s16)
                }
            }
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.bottom, 120)
        }
        .background(DS.Colors.Bg.base)
        .scrollIndicators(.hidden)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task { await AnnouncementFeed.refresh(context: modelContext) }
    }

    // MARK: - Filter

    private var filterPicker: some View {
        HStack(spacing: DS.Spacing.s8) {
            ForEach(AnnouncementFilter.allCases) { option in
                let selected = filter == option
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(DS.Motion.standardSpring) { filter = option }
                } label: {
                    Text(option.label)
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

    // MARK: - Card

    private func announcementCard(_ announcement: Announcement) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s8) {
            HStack(spacing: DS.Spacing.s8) {
                audiencePill(announcement)
                Spacer(minLength: 0)
                Text(announcement.createdAt.formatted(.dateTime.month(.abbreviated).day()))
                    .style(.microSm)
                    .foregroundStyle(DS.Colors.Ink.tertiary)
            }

            Text(announcement.title)
                .style(.title3)
                .foregroundStyle(DS.Colors.Ink.primary)
                .fixedSize(horizontal: false, vertical: true)

            if !announcement.body.isEmpty {
                Text(announcement.body)
                    .style(.callout)
                    .foregroundStyle(DS.Colors.Ink.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(DS.Spacing.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.Colors.Bg.elevated)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.lg).stroke(DS.Colors.Line.hairline, lineWidth: 1))
    }

    private func audiencePill(_ announcement: Announcement) -> some View {
        let isTeam = announcement.isTeamTargeted
        return HStack(spacing: DS.Spacing.s8 / 2) {
            Image(systemName: isTeam ? "person.3.fill" : "megaphone.fill")
                .font(.system(size: 10, weight: .bold))
            Text(isTeam ? "TEAM" : "GENERAL")
                .style(.microSm)
        }
        .foregroundStyle(isTeam ? DS.Colors.Gold.textLight : DS.Colors.Ink.tertiary)
        .padding(.horizontal, DS.Spacing.s8)
        .padding(.vertical, 4)
        .background(
            (isTeam ? AnyShapeStyle(DS.Colors.Gold.base.opacity(0.15)) : AnyShapeStyle(DS.Colors.Bg.raised)),
            in: Capsule()
        )
    }

    // MARK: - Empty state

    private var emptyState: some View {
        Card(padding: DS.Spacing.s16) {
            VStack(alignment: .leading, spacing: DS.Spacing.s8) {
                Eyebrow(text: "Nothing here yet")
                Text(filter == .all
                     ? "When your coach posts an announcement, it'll show up here."
                     : "No \(filter.label.lowercased()) announcements right now.")
                    .style(.callout)
                    .foregroundStyle(DS.Colors.Ink.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
