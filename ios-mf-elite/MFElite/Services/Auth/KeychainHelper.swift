//
//  KeychainHelper.swift
//  MFElite
//
//  Minimal Keychain wrapper for storing the Rork Auth tokens.
//

import Foundation
import Security

/// Stores small secrets (auth tokens) in the iOS Keychain.
/// Marked `nonisolated` so it can be read from the synchronous Supabase
/// `accessToken` closure, which may run off the main actor.
nonisolated enum KeychainHelper {
    static func set(_ key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func get(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}

/// Nonisolated access to the current Rork access token. On the iOS Simulator
/// the token is injected into `UserDefaults`; on device it lives in Keychain.
/// Reading happens off the main actor inside the Supabase client closure.
nonisolated enum AuthTokenStore {
    static let accessTokenKey = "access_token"
    static let refreshTokenKey = "refresh_token"

    static func currentAccessToken() -> String? {
        #if targetEnvironment(simulator)
        if let injected = UserDefaults.standard.string(forKey: "RORK_AUTH_ACCESS_TOKEN") {
            return injected
        }
        #endif
        return KeychainHelper.get(accessTokenKey)
    }

    static func currentRefreshToken() -> String? {
        #if targetEnvironment(simulator)
        if let injected = UserDefaults.standard.string(forKey: "RORK_AUTH_REFRESH_TOKEN") {
            return injected
        }
        #endif
        return KeychainHelper.get(refreshTokenKey)
    }
}
