//
//  AuthService.swift
//  MFElite
//
//  Rork Auth (Sign in with Apple) integration. Rork Auth is a third-party
//  OAuth provider — Supabase's native auth is NOT used. The Rork JWT is handed
//  to the Supabase client so RLS `user_id()` resolves to the Rork user id.
//

import SwiftUI
import AuthenticationServices
import CryptoKit
import Observation
import Supabase

@Observable
@MainActor
final class AuthService {
    static let shared = AuthService()

    // MARK: - Public state

    var user: User?
    var isLoading: Bool = true
    var isSigningIn: Bool = false
    var isCoach: Bool = false
    /// 'coach' | 'head_coach' when `isCoach`, else nil.
    var coachRole: String?
    /// Display name from the coaches table (used for the minimal coach profile).
    var coachDisplayName: String?
    var showError: Bool = false
    var errorMessage: String = ""

    /// Head coaches can manage the team (add / deactivate other coaches).
    var isHeadCoach: Bool { isCoach && coachRole == "head_coach" }

    var isAuthenticated: Bool { user != nil }

    // MARK: - Config

    private let authURL = Config.EXPO_PUBLIC_RORK_AUTH_URL
    private let appKey = Config.EXPO_PUBLIC_RORK_APP_KEY
    private let projectID = Config.EXPO_PUBLIC_PROJECT_ID

    private var codeVerifier: String?
    private var webAuthSession: ASWebAuthenticationSession?

    private var developerHint: String? {
        UserDefaults.standard.string(forKey: "RORK_DEVELOPER_HINT")
    }

    nonisolated struct User: Codable, Sendable {
        let id: String
        let email: String
        let name: String?
        let picture: String?
    }

    private init() {}

    // MARK: - Token access (nonisolated for the Supabase client closure)

    nonisolated func getAccessToken() -> String? {
        AuthTokenStore.currentAccessToken()
    }

    // MARK: - Session restore

    /// Restore a session on launch (Keychain → refresh fallback).
    func checkSession() async {
        defer { isLoading = false }
        if let token = AuthTokenStore.currentAccessToken(), let restored = userFromToken(token) {
            user = restored
            await afterSignIn()
            return
        }
        if AuthTokenStore.currentRefreshToken() != nil {
            await refreshToken()
            if user != nil { await afterSignIn() }
        }
    }

    // MARK: - Sign in

    /// Sign in with Apple via Rork Auth.
    func signInWithApple() async {
        await signIn(provider: "apple")
    }

    func signIn(provider: String) async {
        isSigningIn = true
        defer { isSigningIn = false }
        do {
            let verifier = generateCodeVerifier()
            codeVerifier = verifier
            let challenge = generateCodeChallenge(from: verifier)

            guard let url = URL(string: "\(authURL)/oauth/initiate") else {
                setError("Invalid auth URL")
                return
            }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            var body: [String: String] = [
                "app_key": appKey,
                "provider": provider,
                "code_challenge": challenge,
                "target": "swift",
                "env": authEnv
            ]
            if authEnv == "simulator", let hint = developerHint {
                body["developer_hint"] = hint
            }
            request.httpBody = try JSONEncoder().encode(body)

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                setError("Sign in failed (\((response as? HTTPURLResponse)?.statusCode ?? -1))")
                return
            }
            let initiate = try JSONDecoder().decode(InitiateResponse.self, from: data)

            let code: String
            if initiate.flow == "popup" {
                do {
                    code = try await pollForCode(state: initiate.state)
                } catch AuthFlowError.cancelledByUser {
                    code = try await runWebAuthSession(authURL: initiate.auth_url)
                }
            } else {
                code = try await runWebAuthSession(authURL: initiate.auth_url)
            }

            await exchangeCode(code)
            if user != nil { await afterSignIn() }
        } catch let error as ASWebAuthenticationSessionError where error.code == .canceledLogin {
            return
        } catch {
            setError(error.localizedDescription)
        }
    }

    // MARK: - Sign out

    func signOut() async {
        KeychainHelper.delete(AuthTokenStore.accessTokenKey)
        KeychainHelper.delete(AuthTokenStore.refreshTokenKey)
        UserDefaults.standard.removeObject(forKey: "RORK_AUTH_REFRESH_TOKEN")
        UserDefaults.standard.removeObject(forKey: "RORK_AUTH_ACCESS_TOKEN")
        user = nil
        isCoach = false
        coachRole = nil
        coachDisplayName = nil
    }

    // MARK: - Account deletion

    /// Permanently removes the player's remote records, then signs out.
    /// Local SwiftData + the onboarding flag are cleared by the caller.
    func deleteAccount() async {
        if SupabaseService.shared.isConfigured, let userID = user?.id {
            do {
                try await SupabaseService.shared.client
                    .from("player_progress")
                    .delete()
                    .eq("player_id", value: userID)
                    .execute()
                try await SupabaseService.shared.client
                    .from("player_state")
                    .delete()
                    .eq("player_id", value: userID)
                    .execute()
                try await SupabaseService.shared.client
                    .from("player_profiles")
                    .delete()
                    .eq("id", value: userID)
                    .execute()
            } catch {
                // Non-fatal — RLS or offline. The sign-out still proceeds.
                print("[AuthService] account deletion failed: \(error)")
            }
        }
        await signOut()
    }

    // MARK: - Coach role

    /// Determine coach access from the `coaches` table. First match by `user_id`
    /// (already linked); otherwise match by email and stamp `user_id` so future
    /// checks resolve by id even if the coach later hides their email.
    func checkCoachRole() async {
        guard SupabaseService.shared.isConfigured, let user else {
            clearCoachState(); return
        }
        let client = SupabaseService.shared.client
        do {
            // 1. Already linked by user_id.
            let byID: [CoachRow] = try await client
                .from("coaches")
                .select()
                .eq("user_id", value: user.id)
                .eq("is_active", value: true)
                .execute()
                .value
            if let row = byID.first {
                applyCoach(row)
                return
            }

            // 2. Match by email, then self-link the user_id.
            let email = user.email.lowercased()
            guard !email.isEmpty else { clearCoachState(); return }
            let byEmail: [CoachRow] = try await client
                .from("coaches")
                .select()
                .eq("email", value: email)
                .eq("is_active", value: true)
                .execute()
                .value
            guard let row = byEmail.first else { clearCoachState(); return }

            do {
                try await client
                    .from("coaches")
                    .update(CoachLinkUpdate(userId: user.id))
                    .eq("id", value: row.id)
                    .execute()
            } catch {
                // Non-fatal — RLS may reject the link, but access still applies
                // for this session via the email match below.
                print("[AuthService] coach self-link failed: \(error)")
            }
            applyCoach(row)
        } catch {
            // Default to non-coach on failure; not fatal.
            clearCoachState()
        }
    }

    private func applyCoach(_ row: CoachRow) {
        isCoach = true
        coachRole = row.role ?? "coach"
        coachDisplayName = row.displayName
    }

    private func clearCoachState() {
        isCoach = false
        coachRole = nil
        coachDisplayName = nil
    }

    // MARK: - Post-sign-in housekeeping

    private func afterSignIn() async {
        await syncProfile()
        await checkCoachRole()
    }

    /// Upsert the canonical `profiles` row so Supabase has the user on record.
    private func syncProfile() async {
        guard SupabaseService.shared.isConfigured, let user else { return }
        do {
            try await SupabaseService.shared.client
                .from("profiles")
                .upsert(ProfileUpsert(id: user.id, email: user.email, name: user.name))
                .execute()
        } catch {
            // Non-fatal — RLS or offline. Surfaced in logs only.
            print("[AuthService] profile upsert failed: \(error)")
        }
    }

    // MARK: - Token exchange / refresh

    private func exchangeCode(_ code: String) async {
        guard let verifier = codeVerifier else { return }
        codeVerifier = nil
        guard let url = URL(string: "\(authURL)/oauth/token") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode([
            "app_key": appKey,
            "code": code,
            "code_verifier": verifier
        ])
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                setError("Sign in failed (\((response as? HTTPURLResponse)?.statusCode ?? -1))")
                return
            }
            let token = try JSONDecoder().decode(TokenResponse.self, from: data)
            KeychainHelper.set(AuthTokenStore.accessTokenKey, value: token.access_token)
            KeychainHelper.set(AuthTokenStore.refreshTokenKey, value: token.refresh_token)
            user = token.user
        } catch {
            setError("Sign in failed: \(error.localizedDescription)")
        }
    }

    private func refreshToken() async {
        guard let refresh = AuthTokenStore.currentRefreshToken(),
              let url = URL(string: "\(authURL)/oauth/refresh") else {
            user = nil
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode([
            "app_key": appKey,
            "refresh_token": refresh
        ])
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                await signOut()
                return
            }
            let refreshed = try JSONDecoder().decode(RefreshResponse.self, from: data)
            KeychainHelper.set(AuthTokenStore.accessTokenKey, value: refreshed.access_token)
            user = userFromToken(refreshed.access_token)
        } catch {
            await signOut()
        }
    }

    // MARK: - Helpers

    private var authEnv: String {
        #if targetEnvironment(simulator)
        return "simulator"
        #else
        return "native"
        #endif
    }

    private func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return base64URL(Data(bytes))
    }

    private func generateCodeChallenge(from verifier: String) -> String {
        base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
    }

    private func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func userFromToken(_ token: String) -> User? {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return nil }
        var base64 = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64.append("=") }
        guard let data = Data(base64Encoded: base64) else { return nil }

        struct Payload: Codable {
            let sub: String
            let email: String?
            let name: String?
            let picture: String?
            let exp: TimeInterval?
        }
        guard let payload = try? JSONDecoder().decode(Payload.self, from: data) else { return nil }
        if let exp = payload.exp, Date(timeIntervalSince1970: exp) < Date() { return nil }
        return User(id: payload.sub, email: payload.email ?? "", name: payload.name, picture: payload.picture)
    }

    private func pollForCode(state: String) async throws -> String {
        guard let url = URL(string: "\(authURL)/oauth/poll-code") else { throw AuthFlowError.invalidURL }
        let deadline = Date().addingTimeInterval(5 * 60)
        while Date() < deadline {
            try await Task.sleep(for: .milliseconds(1500))
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(["app_key": appKey, "state": state])
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { continue }
            guard let poll = try? JSONDecoder().decode(PollCodeResponse.self, from: data) else { continue }
            if poll.status == "cancelled" { throw AuthFlowError.cancelledByUser }
            if poll.status == "ready", let code = poll.code { return code }
        }
        throw AuthFlowError.popupTimeout
    }

    private func runWebAuthSession(authURL authURLString: String) async throws -> String {
        let scheme = "rork-\(projectID)"
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            guard let url = URL(string: authURLString) else {
                continuation.resume(throwing: AuthFlowError.invalidURL)
                return
            }
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: scheme) { [weak self] callbackURL, error in
                self?.webAuthSession = nil
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let callbackURL,
                      let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                      let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
                    continuation.resume(throwing: AuthFlowError.noCode)
                    return
                }
                continuation.resume(returning: code)
            }
            self.webAuthSession = session
            session.presentationContextProvider = WebAuthPresentationContext.shared
            session.prefersEphemeralWebBrowserSession = false
            session.start()
        }
    }

    private func setError(_ message: String) {
        errorMessage = message
        showError = true
    }
}

// MARK: - Response types

private struct InitiateResponse: Codable {
    let auth_url: String
    let state: String
    let flow: String?
}

private struct PollCodeResponse: Codable {
    let status: String
    let code: String?
}

private struct TokenResponse: Codable {
    let access_token: String
    let refresh_token: String
    let user: AuthService.User
}

private struct RefreshResponse: Codable {
    let access_token: String
    let expires_in: Int
}

nonisolated struct CoachRow: Codable, Sendable, Identifiable {
    let id: String
    let email: String?
    let displayName: String?
    let role: String?
    let userId: String?
    let isActive: Bool?

    enum CodingKeys: String, CodingKey {
        case id, email, role
        case displayName = "display_name"
        case userId = "user_id"
        case isActive = "is_active"
    }
}

nonisolated struct CoachLinkUpdate: Encodable, Sendable {
    let userId: String
    enum CodingKeys: String, CodingKey { case userId = "user_id" }
}

enum AuthFlowError: LocalizedError {
    case noCode, invalidURL, popupTimeout, cancelledByUser

    var errorDescription: String? {
        switch self {
        case .noCode: return "No authorization code received"
        case .invalidURL: return "Invalid URL"
        case .popupTimeout: return "Sign-in timed out — please try again"
        case .cancelledByUser: return "Sign-in cancelled"
        }
    }
}

final class WebAuthPresentationContext: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = WebAuthPresentationContext()
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}
