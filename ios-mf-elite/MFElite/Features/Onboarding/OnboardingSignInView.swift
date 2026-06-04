//
//  OnboardingSignInView.swift
//  MFElite
//
//  The gateway shown right after "The Code". Players continue with no sign-in
//  and go straight into building their profile. Only MF Elite coaches sign in
//  — with Google, so the resolved Gmail matches the authorized coaches list.
//

import SwiftUI

struct OnboardingSignInView: View {
    let state: OnboardingState
    /// Continue as a player — no account, no email. Advances the cinematic flow.
    let onContinueAsPlayer: () -> Void
    /// Called after a coach sign-in completes. The coordinator decides routing.
    let onAuthenticated: () -> Void

    @State private var auth = AuthService.shared
    @State private var legalURL: IdentifiableURL?

    private let privacyURL = URL(string: "https://m5cairio.com/mfelite/privacy")!

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            DiagonalStripes(opacity: 0.35)

            VStack(spacing: 0) {
                Image("mf-logo-white")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 44)
                    .padding(.top, DS.Spacing.s24)
                    .accessibilityLabel("MF Elite")

                Spacer()

                VStack(spacing: DS.Spacing.s12) {
                    Eyebrow(text: "Join the Academy")
                    Text("Claim your place")
                        .style(.title1)
                        .foregroundStyle(DS.Colors.Ink.primary)
                        .multilineTextAlignment(.center)
                    Text("No account needed — set up your profile and start training in seconds.")
                        .style(.body)
                        .foregroundStyle(DS.Colors.Ink.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 300)
                }

                Spacer()

                VStack(spacing: DS.Spacing.s16) {
                    PrimaryButton(label: "Continue as a player") {
                        onContinueAsPlayer()
                    }

                    coachSignInButton

                    legalConsent

                    StepBar(filled: 1, total: OnboardingStep.stepTotal)
                }
                .padding(.bottom, DS.Spacing.s24)
            }
            .padding(.horizontal, DS.Spacing.s20)
        }
        .sheet(item: $legalURL) { item in
            SafariView(url: item.url).ignoresSafeArea()
        }
        .alert("Sign in failed", isPresented: $auth.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(auth.errorMessage)
        }
    }

    /// Coach-only entry point. Uses Google so the email matches the coaches table.
    private var coachSignInButton: some View {
        Button {
            Task {
                await auth.signInWithGoogle()
                if auth.isAuthenticated { onAuthenticated() }
            }
        } label: {
            HStack(spacing: DS.Spacing.s8) {
                if auth.isSigningIn {
                    ProgressView()
                        .tint(DS.Colors.Ink.primary)
                } else {
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: 14, weight: .semibold))
                    Text("MF Elite Coach? Sign in")
                        .font(.system(size: 15, weight: .semibold))
                }
            }
            .foregroundStyle(DS.Colors.Ink.secondary)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .overlay(
                Capsule().stroke(DS.Colors.Line.subtle, lineWidth: 1)
            )
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(auth.isSigningIn)
        .accessibilityLabel("MF Elite coach sign in with Google")
    }

    private var legalConsent: some View {
        (
            Text("By continuing you agree to our ")
                .foregroundColor(DS.Colors.Ink.quaternary)
            + Text("Terms of Service")
                .foregroundColor(DS.Colors.Ink.secondary)
                .underline()
            + Text(" and ")
                .foregroundColor(DS.Colors.Ink.quaternary)
            + Text("Privacy Policy")
                .foregroundColor(DS.Colors.Ink.secondary)
                .underline()
        )
        .style(.micro)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { legalURL = IdentifiableURL(url: privacyURL) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("View Terms of Service and Privacy Policy")
    }
}

#Preview {
    OnboardingSignInView(state: OnboardingState(), onContinueAsPlayer: {}, onAuthenticated: {})
        .preferredColorScheme(.dark)
}
