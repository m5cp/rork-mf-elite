//
//  CoachLockGate.swift
//  MFElite
//
//  Optional Face ID / Touch ID gate in front of Coach Mode. When the coach turns
//  on the lock in Settings, opening the Coach tab requires the phone owner to
//  authenticate first — protecting rostered players' data on a shared device.
//

import SwiftUI

struct CoachLockGate<Content: View>: View {
    @ViewBuilder var content: Content

    @AppStorage("MF_COACH_FACEID_LOCK") private var lockEnabled = false
    @State private var unlocked = false
    @State private var authenticating = false

    var body: some View {
        Group {
            if !lockEnabled || unlocked {
                content
            } else {
                lockScreen
            }
        }
        .task {
            if lockEnabled && !unlocked { await authenticate() }
        }
    }

    private var lockScreen: some View {
        VStack(spacing: DS.Spacing.s20) {
            Spacer()
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(DS.Colors.Ink.secondary)
            VStack(spacing: DS.Spacing.s8) {
                Text("Coach Mode is locked")
                    .style(.title2)
                    .foregroundStyle(DS.Colors.Ink.primary)
                Text("Unlock with \(BiometricLock.biometryLabel) to view your team.")
                    .style(.foot)
                    .foregroundStyle(DS.Colors.Ink.tertiary)
                    .multilineTextAlignment(.center)
            }
            Button {
                Task { await authenticate() }
            } label: {
                Text(authenticating ? "Unlocking…" : "Unlock")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(DS.Colors.Ground.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.white)
                    .clipShape(Capsule())
            }
            .buttonStyle(PressableButtonStyle())
            .disabled(authenticating)
            Spacer()
        }
        .padding(.horizontal, DS.Spacing.s32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DS.Colors.Bg.base)
    }

    private func authenticate() async {
        guard !authenticating else { return }
        authenticating = true
        let ok = await BiometricLock.authenticate(reason: "Unlock Coach Mode to view your team's data.")
        unlocked = ok
        authenticating = false
    }
}
