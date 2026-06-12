//
//  AccountSyncSignInSheet.swift
//  MFElite
//
//  Sheet presented from Settings to sign in with Apple after onboarding. Backs
//  up progress to Supabase. Dismisses itself on successful sign-in.
//

import SwiftUI

struct AccountSyncSignInSheet: View {
    let onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s16) {
            Eyebrow(text: "Sync")
                .padding(.top, DS.Spacing.s24)

            Text("Back up your progress")
                .style(.title2)
                .foregroundStyle(DS.Colors.Ink.primary)

            Text("Sign in with Apple to save your card, streak and history to the cloud and restore them on another device. Your training data stays on this device too.")
                .style(.body)
                .foregroundStyle(DS.Colors.Ink.secondary)

            Spacer()

            AppleSignInButton { onDone() }

            GhostButton(label: "Not now") { onDone() }
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.bottom, DS.Spacing.s24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.Colors.Bg.base)
    }
}

#Preview {
    AccountSyncSignInSheet(onDone: {})
        .preferredColorScheme(.dark)
}
