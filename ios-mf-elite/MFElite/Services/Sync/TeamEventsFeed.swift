//
//  TeamEventsFeed.swift
//  MFElite
//
//  Fetches coach-published team events (practices, games, sessions) from the
//  team_events table, and lets coaches create/deactivate them. Players get
//  read-only upcoming events; coaches write (RLS-enforced server-side).
//

import Foundation
import EventKit

struct TeamEvent: Identifiable, Equatable {
    let id: String
    let kind: String        // practice | game | session | other
    let title: String
    let startsAt: Date
    let endsAt: Date?
    let location: String
    let notes: String
    let active: Bool
}

@MainActor
@Observable
final class TeamEventsFeed {
    static let shared = TeamEventsFeed()
    private init() {}

    private(set) var events: [TeamEvent] = []
    private(set) var lastFetched: Date?

    private static let iso: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static func parseDate(_ string: String) -> Date? {
        if let d = iso.date(from: string) { return d }
        let plain = ISO8601DateFormatter()
        return plain.date(from: string)
    }

    /// Upcoming active events, soonest first.
    func refresh() async {
        guard let rows = await SupabaseClient.shared.get(
            table: "team_events",
            query: [
                URLQueryItem(name: "active", value: "eq.true"),
                URLQueryItem(name: "order", value: "starts_at.asc"),
                URLQueryItem(name: "starts_at", value: "gte.\(Self.iso.string(from: Date().addingTimeInterval(-3600)))")
            ]
        ) else { return }
        let myTeams = await MyTeamsStore.shared.currentTeamIDs()
        let addressed = rows.filter { MyTeamsStore.isVisibleToMe(row: $0, myTeamIDs: myTeams) }
        events = addressed.compactMap { row in
            guard let id = row["id"] as? String,
                  let title = row["title"] as? String,
                  let startString = row["starts_at"] as? String,
                  let starts = Self.parseDate(startString) else { return nil }
            return TeamEvent(
                id: id,
                kind: row["kind"] as? String ?? "practice",
                title: title,
                startsAt: starts,
                endsAt: (row["ends_at"] as? String).flatMap(Self.parseDate),
                location: row["location"] as? String ?? "",
                notes: row["notes"] as? String ?? "",
                active: true
            )
        }
        lastFetched = Date()
    }

    /// Coach: publish a new event to a chosen audience. Returns true on success.
    func publish(kind: String, title: String, startsAt: Date, endsAt: Date?, location: String, notes: String, audience: BroadcastAudience = BroadcastAudience()) async -> Bool {
        var row: [String: Any] = [
            "kind": kind,
            "title": title,
            "starts_at": Self.iso.string(from: startsAt),
            "location": location,
            "notes": notes,
            "active": true
        ]
        if let endsAt { row["ends_at"] = Self.iso.string(from: endsAt) }
        if let userID = SupabaseAuth.shared.userID { row["created_by"] = userID }
        audience.apply(to: &row)
        let ok = await SupabaseClient.shared.insert(table: "team_events", values: row)
        if ok { await refresh() }
        return ok
    }

    /// Coach: deactivate (soft-delete) an event.
    func deactivate(_ event: TeamEvent) async {
        _ = await SupabaseClient.shared.update(
            table: "team_events",
            values: ["active": false],
            match: [URLQueryItem(name: "id", value: "eq.\(event.id)")]
        )
        await refresh()
    }

    // MARK: - Device calendar export (player-side)

    /// Add a team event to the player's device calendar (write-only access).
    func addToDeviceCalendar(_ event: TeamEvent) async -> Bool {
        let store = EKEventStore()
        guard (try? await store.requestWriteOnlyAccessToEvents()) == true else { return false }
        let ekEvent = EKEvent(eventStore: store)
        ekEvent.title = "\(event.kind.capitalized): \(event.title)"
        ekEvent.startDate = event.startsAt
        ekEvent.endDate = event.endsAt ?? event.startsAt.addingTimeInterval(90 * 60)
        ekEvent.location = event.location.isEmpty ? nil : event.location
        ekEvent.notes = event.notes.isEmpty ? nil : event.notes
        ekEvent.calendar = store.defaultCalendarForNewEvents
        ekEvent.addAlarm(EKAlarm(relativeOffset: -3600))
        do {
            try store.save(ekEvent, span: .thisEvent)
            return true
        } catch {
            return false
        }
    }
}
