//
//  CoachPINStore.swift
//  MFElite
//
//  Stores the coach workspace PIN as a SHA256 hash in the Keychain. The default
//  PIN (1234) only works until the coach sets a custom one on first login.
//

import Foundation
import CryptoKit

/// Manages the coach workspace PIN. A SHA256 hash is persisted in the Keychain
/// under `mf.coach.pin`; the raw PIN is never stored.
enum CoachPINStore {
    static let keychainKey = "mf.coach.pin"

    /// The bootstrap PIN accepted only while no custom PIN exists.
    static let defaultPIN = "1234"

    /// True once the coach has set their own PIN.
    static var hasCustomPIN: Bool {
        KeychainHelper.get(keychainKey) != nil
    }

    /// Hashes a PIN with SHA256 and returns a lowercase hex string.
    static func hash(_ pin: String) -> String {
        let digest = SHA256.hash(data: Data(pin.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// Persists a new custom PIN.
    static func setPIN(_ pin: String) {
        KeychainHelper.set(keychainKey, value: hash(pin))
    }

    /// Validates an entered PIN against either the custom hash or the default.
    static func validate(_ pin: String) -> Bool {
        if let stored = KeychainHelper.get(keychainKey) {
            return stored == hash(pin)
        }
        return pin == defaultPIN
    }

    /// Clears the custom PIN (returns to the default 1234 gate).
    static func reset() {
        KeychainHelper.delete(keychainKey)
    }
}
