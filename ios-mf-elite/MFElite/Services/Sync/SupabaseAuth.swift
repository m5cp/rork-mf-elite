//
//  SupabaseAuth.swift
//  MFElite
//
//  Native Supabase authentication backed by Sign in with Apple. The Apple
//  identity token is exchanged for a Supabase session (access + refresh tokens),
//  which is persisted in the Keychain and auto-refreshed before expiry / on 401.
//
//  Everything here fails soft: the app remains fully usable signed out and
//  offline. Sign-in is an optional enhancement layered on top of local data.
//

import Foundation
import Security
import CryptoKit
import AuthenticationServices
import Observation

/// Errors surfaced internally; never crash the app — all are logged and swallowed.
nonisolated enum SupabaseAuthError: Error {
    case missingToken
    case badResponse(Int)
    case decodeFailed
}

/// Supabase token endpoint response shape.
nonisolated private struct SupabaseTokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Double
    let user: SupabaseUser

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case user
    }
}

nonisolated private struct SupabaseUser: Decodable {
    let id: String
    let email: String?
}

@Observable
@MainActor
final class SupabaseAuth {
    static let shared = SupabaseAuth()

    /// True when a Supabase session is present.
    private(set) var isSignedIn: Bool
    /// Email of the signed-in account, when known.
    private(set) var email: String?
    /// Supabase user UUID (text) of the signed-in account.
    private(set) var userID: String?
    /// True when the signed-in account is on the active coach allow-list. Never
    /// cached across sign-outs — re-checked on every sign-in / launch.
    private(set) var isCoach: Bool = false

    private var accessToken: String?
    private var refreshToken: String?
    private var expiresAt: Date?

    private enum DefaultsKeys {
        static let email = "MF_SUPABASE_EMAIL"
        static let appleName = "MF_SUPABASE_APPLE_NAME"
    }

    private let defaults = UserDefaults.standard

    private init() {
        let storedAccess = Keychain.read(.accessToken)
        let storedRefresh = Keychain.read(.refreshToken)
        let storedUserID = Keychain.read(.userID)
        accessToken = storedAccess
        refreshToken = storedRefresh
        userID = storedUserID
        email = defaults.string(forKey: DefaultsKeys.email)
        if let raw = Keychain.read(.expiresAt), let epoch = Double(raw) {
            expiresAt = Date(timeIntervalSince1970: epoch)
        }
        isSignedIn = storedAccess != nil && storedRefresh != nil && storedUserID != nil
    }

    // MARK: - Sign in with Apple

    /// Exchange a verified Apple identity token for a Supabase session.
    /// Returns true on success. Captures the Apple full name (only provided on
    /// the FIRST authorization) for the profile upsert.
    @discardableResult
    func exchangeAppleToken(idToken: String, rawNonce: String, fullName: PersonNameComponents?) async -> Bool {
        if let name = Self.formattedName(fullName), !name.isEmpty {
            defaults.set(name, forKey: DefaultsKeys.appleName)
        }

        guard var components = URLComponents(string: "\(SupabaseConfig.url)/auth/v1/token") else { return false }
        components.queryItems = [URLQueryItem(name: "grant_type", value: "id_token")]
        guard let url = components.url else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseConfig.apiKey, forHTTPHeaderField: "apikey")
        let body: [String: String] = ["provider": "apple", "id_token": idToken, "nonce": rawNonce]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                print("[SupabaseAuth] Token exchange failed: HTTP \(code)")
                return false
            }
            let token = try JSONDecoder().decode(SupabaseTokenResponse.self, from: data)
            applySession(token)
            await syncProfilesAfterSignIn()
            await refreshCoachStatus()
            return true
        } catch {
            print("[SupabaseAuth] Token exchange error: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Token lifecycle

    /// A valid access token, refreshing first if it is missing or near expiry.
    func validAccessToken() async -> String? {
        guard let token = accessToken else { return nil }
        if let expiresAt, Date() >= expiresAt.addingTimeInterval(-60) {
            return await forceRefresh()
        }
        return token
    }

    /// Force a refresh-token exchange. Returns the new access token, or nil.
    @discardableResult
    func forceRefresh() async -> String? {
        guard let refreshToken else { return nil }
        guard var components = URLComponents(string: "\(SupabaseConfig.url)/auth/v1/token") else { return nil }
        components.queryItems = [URLQueryItem(name: "grant_type", value: "refresh_token")]
        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseConfig.apiKey, forHTTPHeaderField: "apikey")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["refresh_token": refreshToken])

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                print("[SupabaseAuth] Refresh failed: HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                return nil
            }
            let token = try JSONDecoder().decode(SupabaseTokenResponse.self, from: data)
            applySession(token)
            return token.accessToken
        } catch {
            print("[SupabaseAuth] Refresh error: \(error.localizedDescription)")
            return nil
        }
    }

    private func applySession(_ token: SupabaseTokenResponse) {
        accessToken = token.accessToken
        refreshToken = token.refreshToken
        userID = token.user.id
        expiresAt = Date().addingTimeInterval(token.expiresIn)
        if let mail = token.user.email { email = mail }

        Keychain.write(.accessToken, token.accessToken)
        Keychain.write(.refreshToken, token.refreshToken)
        Keychain.write(.userID, token.user.id)
        Keychain.write(.expiresAt, String(expiresAt?.timeIntervalSince1970 ?? 0))
        defaults.set(email, forKey: DefaultsKeys.email)
        isSignedIn = true
    }

    /// Clear the Supabase session. ALL local training data is preserved.
    func signOut() {
        accessToken = nil
        refreshToken = nil
        userID = nil
        expiresAt = nil
        email = nil
        isSignedIn = false
        setCoach(false)
        // Ballon d'Or approval is account-specific server state — reset it so it
        // is re-pulled fresh on the next sign-in (never inherited across accounts).
        BallonDorStore.shared.reset()
        SyncEngine.shared.handleSignOut()
        Keychain.delete(.accessToken)
        Keychain.delete(.refreshToken)
        Keychain.delete(.userID)
        Keychain.delete(.expiresAt)
        defaults.removeObject(forKey: DefaultsKeys.email)
    }

    // MARK: - Coach allow-list

    /// Re-check whether this account is an active coach. If so, stamp the coach
    /// row's `user_id` once (required for the data-access policies). Fails soft:
    /// any error leaves `isCoach` false and never blocks the app.
    func refreshCoachStatus() async {
        guard isSignedIn, let mail = email, !mail.isEmpty else {
            setCoach(false)
            return
        }
        let rows = await SupabaseClient.shared.get(
            table: "coaches",
            query: [
                URLQueryItem(name: "email", value: "ilike.\(mail)"),
                URLQueryItem(name: "is_active", value: "eq.true"),
                URLQueryItem(name: "limit", value: "1")
            ]
        )
        guard let row = rows?.first else {
            setCoach(false)
            return
        }
        setCoach(true)

        // Self-link: stamp our UUID onto the coach row once so RLS resolves by
        // user_id thereafter. The database permits this self-link a single time.
        if let userID, (row["user_id"] as? String) != userID {
            await SupabaseClient.shared.update(
                table: "coaches",
                values: ["user_id": userID],
                match: [URLQueryItem(name: "email", value: "ilike.\(mail)")]
            )
        }
    }

    /// Update both the local flag and the app-wide entitlement mirror.
    private func setCoach(_ value: Bool) {
        isCoach = value
        SubscriptionService.shared.isCoach = value
    }

    // MARK: - Profile sync

    /// Upsert the owner profile and player profile after sign-in. Idempotent.
    func syncProfilesAfterSignIn() async {
        guard let userID else { return }
        let profile = PlayerProfileStore.shared
        let appleName = defaults.string(forKey: DefaultsKeys.appleName)
        let name = (appleName?.isEmpty == false ? appleName : nil) ?? profile.displayName

        var profileRow: [String: Any] = ["id": userID, "name": name]
        if let email, !email.isEmpty { profileRow["email"] = email }
        await SupabaseClient.shared.upsert(table: "profiles", values: profileRow, onConflict: "id")

        await syncPlayerProfile()
    }

    /// Upsert the shareable player_profiles row from local identity. Idempotent;
    /// safe to call again after onboarding fills in more details.
    func syncPlayerProfile() async {
        guard let userID, isSignedIn else { return }
        let profile = PlayerProfileStore.shared
        var row: [String: Any] = [
            "id": userID,
            "account_id": userID,
            "display_name": profile.displayName,
            "position": profile.position,
            "kit_number": profile.kitNumber
        ]
        if profile.classYear > 0 { row["class_year"] = profile.classYear }
        await SupabaseClient.shared.upsert(table: "player_profiles", values: row, onConflict: "id")
    }

    // MARK: - Helpers

    private static func formattedName(_ components: PersonNameComponents?) -> String? {
        guard let components else { return nil }
        let formatter = PersonNameComponentsFormatter()
        let value = formatter.string(from: components).trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    /// Cryptographically-random nonce for the Apple request.
    static func randomNonceString(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var random: UInt8 = 0
            let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            if status != errSecSuccess { random = UInt8.random(in: 0...255) }
            if random < charset.count {
                result.append(charset[Int(random)])
                remaining -= 1
            }
        }
        return result
    }

    /// SHA-256 hex digest, sent to Apple as the request nonce.
    static func sha256(_ input: String) -> String {
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Keychain

/// Tiny generic-password Keychain store for Supabase session tokens.
nonisolated private enum Keychain {
    enum Item: String {
        case accessToken = "supabase.accessToken"
        case refreshToken = "supabase.refreshToken"
        case userID = "supabase.userID"
        case expiresAt = "supabase.expiresAt"
    }

    private static let service = "app.rork.mfelite.supabase"

    private static func baseQuery(_ item: Item) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: item.rawValue
        ]
    }

    static func write(_ item: Item, _ value: String) {
        guard let data = value.data(using: .utf8) else { return }
        SecItemDelete(baseQuery(item) as CFDictionary)
        var query = baseQuery(item)
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(query as CFDictionary, nil)
    }

    static func read(_ item: Item) -> String? {
        var query = baseQuery(item)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        return value
    }

    static func delete(_ item: Item) {
        SecItemDelete(baseQuery(item) as CFDictionary)
    }
}
