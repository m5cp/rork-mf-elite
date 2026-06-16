//
//  SyncStatusChip.swift
//  MFElite
//
//  A small, always-honest status pill so logging never feels risky on bad
//  field signal. Reflects the live SyncEngine + auth state: data is saved on
//  device immediately, uploads when online, and confirms once backed up.
//

import SwiftUI

struct SyncStatusChip: View {
    @State private var sync = SyncEngine.shared
    @State private var auth = SupabaseAuth.shared

    /// When true, render a compact pill (icon + short word) for tight spaces.
    var compact: Bool = false

    private enum SyncState {
        case onDevice      // signed out — local only, never lost
        case savedOffline  // signed in, changes queued, no connection
        case syncing       // signed in, changes uploading
        case backedUp      // signed in, nothing pending

        var icon: String {
            switch self {
            case .onDevice:     return "iphone"
            case .savedOffline: return "icloud.slash"
            case .syncing:      return "arrow.triangle.2.circlepath"
            case .backedUp:     return "checkmark.icloud"
            }
        }

        var short: String {
            switch self {
            case .onDevice:     return "Saved"
            case .savedOffline: return "Saved"
            case .syncing:      return "Syncing"
            case .backedUp:     return "Backed up"
            }
        }

        var full: String {
            switch self {
            case .onDevice:     return "Saved on this device"
            case .savedOffline: return "Saved — will back up when online"
            case .syncing:      return "Backing up…"
            case .backedUp:     return "Backed up"
            }
        }
    }

    private var state: SyncState {
        guard auth.isSignedIn else { return .onDevice }
        if sync.pendingCount > 0 {
            return sync.isOnline ? .syncing : .savedOffline
        }
        return .backedUp
    }

    var body: some View {
        let state = self.state
        HStack(spacing: DS.Spacing.s8 - 2) {
            Image(systemName: state.icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(DS.Colors.Ink.tertiary)
            Text(compact ? state.short : state.full)
                .style(.micro)
                .foregroundStyle(DS.Colors.Ink.tertiary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, DS.Spacing.s12)
        .background(DS.Colors.Bg.raised)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.pill))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.pill)
                .stroke(DS.Colors.Line.hairline, lineWidth: 1)
        )
        .accessibilityElement()
        .accessibilityLabel("Sync status: \(state.full)")
    }
}

#Preview {
    ZStack {
        DS.Colors.Bg.base.ignoresSafeArea()
        VStack(spacing: 16) {
            SyncStatusChip()
            SyncStatusChip(compact: true)
        }
    }
    .preferredColorScheme(.dark)
}
