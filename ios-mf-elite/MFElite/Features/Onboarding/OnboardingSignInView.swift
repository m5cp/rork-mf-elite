//
//  OnboardingSignInView.swift
//  MFElite
//
//  Step 2 — Sign in with Apple. Triggered right after "The Code". Authenticates
//  the user up-front so coaches can be detected and routed straight to the
//  academy, while players continue the cinematic admission flow.
//

import SwiftUI

struct OnboardingSignInView: View {
    let state: OnboardingState
    /// Called after a successful sign-in. The coordinator decides routing.
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
                    Text("Sign in to continue")
                        .style(.title1)
                        .foregroundStyle(DS.Colors.Ink.primary)
                        .multilineTextAlignment(.center)
                    Text("Use your Apple ID to secure your academy profile.")
                        .style(.body)
                        .foregroundStyle(DS.Colors.Ink.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 300)
                }

                Spacer()

                VStack(spacing: DS.Spacing.s16) {
                    appleButton

                    Text("Coaches: choose “Share My Email” to verify your access.")
                        .style(.micro)
                        .foregroundStyle(DS.Colors.Ink.quaternary)
                        .multilineTextAlignment(.center)

                    legalConsent

                    StepBar(filled: 2, total: 7)
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

    private var appleButton: some View {
        Button {
            Task {
                await auth.signInWithApple()
                if auth.isAuthenticated { onAuthenticated() }
            }
        } label: {
            HStack(spacing: DS.Spacing.s8) {
                if auth.isSigningIn {
                    ProgressView()
                        .tint(DS.Colors.Ground.primary)
                } else {
                    Image(systemName: "apple.logo")
                        .font(.system(size: 18, weight: .medium))
                    Text("Sign in with Apple")
                        .font(.system(size: 18, weight: .semibold))
                }
            }
            .foregroundStyle(DS.Colors.Ground.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.white)
            .clipShape(Capsule())
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(auth.isSigningIn)
        .accessibilityLabel("Sign in with Apple")
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
    OnboardingSignInView(state: OnboardingState(), onAuthenticated: {})
        .preferredColorScheme(.dark)
}
