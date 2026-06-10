//
//  ParentGate.swift
//  MFElite
//
//  A lightweight parental gate. When enabled, parent-only actions (managing or
//  buying a subscription, restoring purchases, changing family settings) require
//  a 4-digit passcode the parent sets. The passcode itself lives in the Keychain;
//  only the enabled flag is stored in UserDefaults.
//
//  This is intentionally app-local — it is NOT a substitute for Apple's
//  Screen Time / Ask to Buy, but gives a parent a simple lock for in-app actions
//  reachable by a child sharing the device.
//

import Foundation
import Security
import Observation

@Observable
@MainActor
final class ParentGate {
    static let shared = ParentGate()

    /// Number of digits in the passcode.
    static let pinLength = 4

    private enum Keys {
        static let enabled = "MF_PARENT_GATE_ENABLED"
    }

    private static let keychainService = "app.rork.mfelite.parentgate"
    private static let keychainAccount = "parent.pin"

    private let defaults = UserDefaults.standard

    /// When true, protected actions must be unlocked with the passcode.
    var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Keys.enabled) }
    }

    /// True once a passcode has been stored in the Keychain.
    private(set) var hasPIN: Bool

    private init() {
        isEnabled = defaults.bool(forKey: Keys.enabled)
        hasPIN = Self.readPIN() != nil
    }

    // MARK: - Public API

    /// Store a new passcode and turn the gate on.
    func setPIN(_ pin: String) {
        guard pin.count == Self.pinLength else { return }
        Self.writePIN(pin)
        hasPIN = true
        isEnabled = true
    }

    /// Check a candidate passcode against the stored one.
    func verify(_ pin: String) -> Bool {
        guard let stored = Self.readPIN() else { return false }
        return stored == pin
    }

    /// Turn the gate off and erase the stored passcode.
    func disable() {
        Self.deletePIN()
        hasPIN = false
        isEnabled = false
    }

    // MARK: - Keychain (pure, isolation-free)

    nonisolated private static func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
    }

    nonisolated private static func writePIN(_ pin: String) {
        guard let data = pin.data(using: .utf8) else { return }
        SecItemDelete(baseQuery() as CFDictionary)
        var query = baseQuery()
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        SecItemAdd(query as CFDictionary, nil)
    }

    nonisolated private static func readPIN() -> String? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let pin = String(data: data, encoding: .utf8) else {
            return nil
        }
        return pin
    }

    nonisolated private static func deletePIN() {
        SecItemDelete(baseQuery() as CFDictionary)
    }
}
