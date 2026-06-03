//
//  ProgressSyncService.swift
//  MFElite
//
//  Pushes/pulls player progress to/from Supabase. Pushes are fire-and-forget;
//  failures are logged but never block the player (the local SwiftData store
//  remains the immediate source of truth).
//

import Foundation
import SwiftData
import Observation
import Supabase

@MainActor
@Observable
final class ProgressSyncService {
    static let shared = ProgressSyncService()

    private init() {}

    private var playerID: String? {
        guard SupabaseService.shared.isConfigured else { return nil }
        return AuthService.shared.user?.id
    }

    private static let isoDate: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f
    }()

    // MARK: - Push

    /// Upsert a single drill's progress for the current player.
    func pushDrillCompletion(drillID: String, passesLogged: Int, isMastered: Bool) {
        guard let playerID else { return }
        let payload = PlayerProgressUpsert(
            playerId: playerID,
            drillId: drillID,
            passesLogged: passesLogged,
            isMastered: isMastered,
            lastLoggedAt: Date()
        )
        Task {
            do {
                try await SupabaseService.shared.client
                    .from("player_progress")
                    .upsert(payload, onConflict: "player_id,drill_id")
                    .execute()
            } catch {
                print("[ProgressSync] pushDrillCompletion failed: \(error)")
            }
        }
    }

    /// Upsert the player's aggregate state (xp, streak, freezes).
    func pushPlayerState(xp: Int, streak: Int, freezes: Int, lastTrained: Date?, streakPB: Int) {
        guard let playerID else { return }
        let payload = PlayerStateUpsert(
            playerId: playerID,
            xp: xp,
            streak: streak,
            freezesRemaining: freezes,
            lastTrainedDate: lastTrained.map { Self.isoDate.string(from: $0) },
            streakPb: streakPB
        )
        Task {
            do {
                try await SupabaseService.shared.client
                    .from("player_state")
                    .upsert(payload, onConflict: "player_id")
                    .execute()
            } catch {
                print("[ProgressSync] pushPlayerState failed: \(error)")
            }
        }
    }

    /// Record an earned certification.
    func pushCertification(categoryID: String) {
        guard let playerID else { return }
        let payload = CertificationInsert(playerId: playerID, categoryId: categoryID)
        Task {
            do {
                try await SupabaseService.shared.client
                    .from("certifications")
                    .upsert(payload, onConflict: "player_id,category_id")
                    .execute()
            } catch {
                print("[ProgressSync] pushCertification failed: \(error)")
            }
        }
    }

    // MARK: - Pull

    /// Fetch all drill progress for the current player and merge into SwiftData.
    func pullPlayerProgress(context: ModelContext) async {
        guard let playerID else { return }
        do {
            let rows: [PlayerProgressRow] = try await SupabaseService.shared.client
                .from("player_progress")
                .select()
                .eq("player_id", value: playerID)
                .execute()
                .value

            let existing = Dictionary(
                (try context.fetch(FetchDescriptor<DrillProgress>())).map { ($0.drillID, $0) },
                uniquingKeysWith: { a, _ in a }
            )
            for row in rows {
                if let local = existing[row.drillId] {
                    // Server wins only when it is further along.
                    if row.passesLogged >= local.passesLogged {
                        local.passesLogged = row.passesLogged
                        local.isMastered = row.isMastered
                        local.lastLoggedAt = row.lastLoggedAt
                    }
                } else {
                    context.insert(DrillProgress(
                        drillID: row.drillId,
                        passesLogged: row.passesLogged,
                        lastLoggedAt: row.lastLoggedAt,
                        isMastered: row.isMastered
                    ))
                }
            }
            try context.save()
        } catch {
            print("[ProgressSync] pullPlayerProgress failed: \(error)")
        }
    }

    /// Fetch the player's aggregate state and merge into SwiftData.
    func pullPlayerState(context: ModelContext) async {
        guard let playerID else { return }
        do {
            let rows: [PlayerStateRow] = try await SupabaseService.shared.client
                .from("player_state")
                .select()
                .eq("player_id", value: playerID)
                .limit(1)
                .execute()
                .value
            guard let row = rows.first else { return }

            let player = (try? context.fetch(FetchDescriptor<PlayerState>()))?.first
                ?? {
                    let new = PlayerState(playerID: playerID)
                    context.insert(new)
                    return new
                }()
            // Take the higher of local/remote so we never regress progress.
            player.playerID = playerID
            player.xp = max(player.xp, row.xp)
            player.streak = max(player.streak, row.streak)
            player.freezesRemaining = max(player.freezesRemaining, row.freezesRemaining)
            if let dateString = row.lastTrainedDate, let date = Self.isoDate.date(from: dateString) {
                if let current = player.lastTrainedDate {
                    player.lastTrainedDate = max(current, date)
                } else {
                    player.lastTrainedDate = date
                }
            }
            try context.save()
        } catch {
            print("[ProgressSync] pullPlayerState failed: \(error)")
        }
    }
}
