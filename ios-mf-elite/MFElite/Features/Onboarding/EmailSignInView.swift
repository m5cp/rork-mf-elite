//
//  EmailSignInView.swift
//  MFElite
//
//  Secondary email + password sign-in, presented from the same surfaces as
//  Sign in with Apple. Toggles between creating an account and signing in, and
//  routes success through the exact same path as a successful Apple sign-in.
//  Fails soft — all errors are mapped to friendly inline copy.
//

import SwiftUI

struct EmailSignInView: View {
    /// Called on the main actor after a successful sign-in. Mirrors AppleSignInButton.
    var onSignedIn: () -> Void = {}

    @Environment(\.dismiss) private var dismiss

    @State private var isCreatingAccount: Bool = true
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var errorMessage: String?
    @State private var isWorking: Bool = false

    private var canSubmit: Bool {
        email.contains("@") && password.count >= 6 && !isWorking
    }

    private var ctaLabel: String {
        isCreatingAccount ? "Create account" : "Sign in"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s16) {
            Eyebrow(text: isCreatingAccount ? "New account" : "Welcome back")
                .padding(.top, DS.Spacing.s24)

            Text(isCreatingAccount ? "Create your account" : "Sign in")
                .style(.title2)
                .foregroundStyle(DS.Colors.Ink.primary)

            Text("Use your email to back up your card, streak and history to the cloud.")
                .style(.body)
                .foregroundStyle(DS.Colors.Ink.secondary)

            VStack(spacing: DS.Spacing.s12) {
                field(
                    placeholder: "Email",
                    text: $email,
                    keyboard: .emailAddress,
                    isSecure: false
                )
                field(
                    placeholder: "Password",
                    text: $password,
                    keyboard: .default,
                    isSecure: true
                )
            }
            .padding(.top, DS.Spacing.s8)

            if let errorMessage {
                HStack(spacing: DS.Spacing.s8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 13, weight: .semibold))
                    Text(errorMessage)
                        .style(.foot)
                }
                .foregroundStyle(Color(hex: "#FF453A"))
                .transition(.opacity)
            }

            Spacer()

            PrimaryButton(label: isWorking ? "Please wait…" : ctaLabel) {
                submit()
            }
            .disabled(!canSubmit)
            .opacity(canSubmit ? 1 : 0.5)

            GhostButton(label: isCreatingAccount ? "Already have an account? Sign in" : "Need an account? Create one") {
                withAnimation(DS.Motion.standardSpring) {
                    isCreatingAccount.toggle()
                    errorMessage = nil
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.bottom, DS.Spacing.s24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.Colors.Bg.base)
    }

    private func field(placeholder: String, text: Binding<String>, keyboard: UIKeyboardType, isSecure: Bool) -> some View {
        Group {
            if isSecure {
                SecureField("", text: text, prompt: Text(placeholder).foregroundColor(DS.Colors.Ink.disabled))
            } else {
                TextField("", text: text, prompt: Text(placeholder).foregroundColor(DS.Colors.Ink.disabled))
                    .keyboardType(keyboard)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
            }
        }
        .font(.system(size: 17, weight: .semibold))
        .foregroundStyle(DS.Colors.Ink.primary)
        .tint(.white)
        .padding(.horizontal, DS.Spacing.s16)
        .frame(height: 52)
        .background(DS.Colors.Bg.raised)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .stroke(DS.Colors.Line.subtle, lineWidth: 1)
        )
    }

    private func submit() {
        guard canSubmit else { return }
        isWorking = true
        errorMessage = nil
        let trimmedEmail = email
        let pw = password
        let creating = isCreatingAccount

        Task {
            let result = creating
                ? await SupabaseAuth.shared.signUpEmail(email: trimmedEmail, password: pw)
                : await SupabaseAuth.shared.signInEmail(email: trimmedEmail, password: pw)

            isWorking = false
            switch result {
            case .success:
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                SyncEngine.shared.handleSignIn()
                onSignedIn()
                dismiss()
            case .emailInUse:
                withAnimation { errorMessage = "That email is already in use. Try signing in instead." }
            case .invalidCredentials:
                withAnimation { errorMessage = "Wrong email or password. Please try again." }
            case .weakPassword:
                withAnimation { errorMessage = "Password must be at least 6 characters." }
            case .failed:
                withAnimation { errorMessage = "Something went wrong. Please try again." }
            }
        }
    }
}

#Preview {
    EmailSignInView()
        .preferredColorScheme(.dark)
}
