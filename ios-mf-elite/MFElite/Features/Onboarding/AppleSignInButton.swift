//
//  AppleSignInButton.swift
//  MFElite
//
//  Reusable "Sign in with Apple" control that runs the native AuthenticationServices
//  flow with a nonce, then exchanges the Apple identity token for a Supabase
//  session. Used in onboarding and Settings. Fails soft — cancellation/errors are
//  logged and ignored.
//

import SwiftUI
import AuthenticationServices

struct AppleSignInButton: View {
    /// Called on the main actor after a successful sign-in.
    var onSignedIn: () -> Void = {}

    @State private var currentNonce: String = ""

    var body: some View {
        SignInWithAppleButton(.signIn) { request in
            let nonce = SupabaseAuth.randomNonceString()
            currentNonce = nonce
            request.requestedScopes = [.fullName, .email]
            request.nonce = SupabaseAuth.sha256(nonce)
        } onCompletion: { result in
            handle(result)
        }
        .signInWithAppleButtonStyle(.white)
        .frame(height: 52)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    private func handle(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let idToken = String(data: tokenData, encoding: .utf8)
            else {
                print("[AppleSignInButton] Missing Apple identity token")
                return
            }
            let fullName = credential.fullName
            let nonce = currentNonce
            Task {
                let ok = await SupabaseAuth.shared.exchangeAppleToken(
                    idToken: idToken,
                    rawNonce: nonce,
                    fullName: fullName
                )
                if ok {
                    SyncEngine.shared.handleSignIn()
                    onSignedIn()
                }
            }
        case .failure(let error):
            print("[AppleSignInButton] Sign-in cancelled or failed: \(error.localizedDescription)")
        }
    }
}
