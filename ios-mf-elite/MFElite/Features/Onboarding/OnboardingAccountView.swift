//
//  OnboardingAccountView.swift
//  MFElite
//
//  Optional account step shown right after The Pledge. Offers Sign in with Apple
//  to back up progress to the cloud, or "train offline" to continue without an
//  account. Signing in is never required — the app is fully usable signed out.
//

import SwiftUI

struct OnboardingAccountView: View {
    let state: OnboardingState

    @State private var auth = SupabaseAuth.shared
    @State private var showEmailSignIn = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Eyebrow(text: "Optional")
                    .padding(.top, DS.Spacing.s12)

                Text("Keep your progress safe.")
                    .font(.system(size: 38, weight: .heavy))
                    .tracking(-1.4)
                    .foregroundStyle(DS.Colors.Ink.primary)
                    .padding(.top, DS.Spacing.s12)

                Text("Sign in to back up your card, streak and history — and pick up right where you left off on any device. You can always do this later in Settings.")
                    .style(.body)
                    .foregroundStyle(DS.Colors.Ink.secondary)
                    .padding(.top, DS.Spacing.s12)

                Spacer()

                benefits

                Spacer()

                footer
            }
            .padding(.horizontal, DS.Spacing.s20)
        }
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s16) {
            benefitRow(icon: "icloud", text: "Back up your progress to the cloud")
            benefitRow(icon: "arrow.triangle.2.circlepath", text: "Restore everything on a new device")
            benefitRow(icon: "lock.shield", text: "Private — secured by Sign in with Apple")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func benefitRow(icon: String, text: String) -> some View {
        HStack(spacing: DS.Spacing.s16) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(DS.Colors.Ink.primary)
                .frame(width: 36, height: 36)
                .background(DS.Colors.Bg.raised)
                .clipShape(Circle())
            Text(text)
                .style(.callout)
                .foregroundStyle(DS.Colors.Ink.secondary)
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var footer: some View {
        VStack(spacing: DS.Spacing.s12) {
            if auth.isSignedIn {
                HStack(spacing: DS.Spacing.s8) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.white)
                    Text(auth.email.map { "Signed in as \($0)" } ?? "Signed in")
                        .style(.callout)
                        .foregroundStyle(DS.Colors.Ink.secondary)
                }
                PrimaryButton(label: "Continue") {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    state.advance()
                }
            } else {
                AppleSignInButton {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    state.advance()
                }
                SecondaryButton(label: "Continue with email") {
                    showEmailSignIn = true
                }
                GhostButton(label: "Not now — train offline") {
                    state.advance()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.bottom, DS.Spacing.s24)
        .sheet(isPresented: $showEmailSignIn) {
            EmailSignInView {
                state.advance()
            }
            .presentationDetents([.medium, .large])
            .preferredColorScheme(.dark)
        }
    }
}

#Preview {
    OnboardingAccountView(state: OnboardingState())
        .preferredColorScheme(.dark)
}
