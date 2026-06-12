//
//  SyncRestore.swift
//  MFElite
//
//  Coordinates the one-time "Restore your progress" prompt shown after a fresh
//  install signs in and the cloud turns out to hold more progress than the local
//  device. Observed at the app root, which presents RestoreProgressView when
//  `pending` is set. Everything fails soft — if anything goes wrong the player
//  simply continues with local data.
//

import Foundation
import SwiftData
import Observation

@Observable
@MainActor
final class SyncRestore {
    static let shared = SyncRestore()

    /// Remote state awaiting a restore decision; non-nil drives the prompt.
    private(set) var pending: RemotePlayerState?

    private init() {}

    /// After a successful sign-in, check whether the cloud holds more progress
    /// than this (fresh) device. If so, surface the restore prompt.
    func checkForRestore(context: ModelContext) {
        Task {
            guard let remote = await SyncEngine.shared.fetchRemotePlayerState() else { return }
            let player = try? context.fetch(FetchDescriptor<PlayerState>()).first
            let localXP = player?.xp ?? 0
            // Only prompt when local looks fresh and remote clearly has more.
            if localXP == 0 && remote.xp > 0 {
                pending = remote
            }
        }
    }

    /// Pull remote state + progress, then dismiss the prompt.
    func restore() {
        let remote = pending
        pending = nil
        guard remote != nil else { return }
        Task { await SyncEngine.shared.restoreFromRemote() }
    }

    /// Keep this device's fresh local state; overwrite the cloud with it.
    func startFresh(context: ModelContext) {
        pending = nil
        let player = try? context.fetch(FetchDescriptor<PlayerState>()).first
        if let player { SyncEngine.shared.enqueuePlayerState(player) }
    }

    /// Dismiss the prompt without a decision (treated as keeping local data).
    func dismissPending() {
        pending = nil
    }
}

/// Identifiable wrapper so the restore prompt can drive a `fullScreenCover(item:)`.
struct RemotePlayerStateItem: Identifiable {
    let id = UUID()
    let state: RemotePlayerState

    init(_ state: RemotePlayerState) { self.state = state }
}
