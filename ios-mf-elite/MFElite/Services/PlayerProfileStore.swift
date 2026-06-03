//
//  PlayerProfileStore.swift
//  MFElite
//
//  Lightweight, UserDefaults-backed store for the player's identity captured
//  during onboarding (name, initials, kit number, position) plus the
//  onboarding-complete flag. This is the local source of truth for display;
//  Supabase `player_profiles` is the remote mirror created on completion.
//

import SwiftUI
import Observation

@Observable
@MainActor
final class PlayerProfileStore {
    static let shared = PlayerProfileStore()

    private enum Keys {
        static let completed = "MF_ONBOARDING_COMPLETE"
        static let name = "MF_PLAYER_NAME"
        static let username = "MF_PLAYER_USERNAME"
        static let kit = "MF_PLAYER_KIT"
        static let position = "MF_PLAYER_POSITION"
    }

    private let defaults = UserDefaults.standard

    var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Keys.completed) }
    }
    var displayName: String {
        didSet { defaults.set(displayName, forKey: Keys.name) }
    }
    var username: String {
        didSet { defaults.set(username, forKey: Keys.username) }
    }
    var kitNumber: String {
        didSet { defaults.set(kitNumber, forKey: Keys.kit) }
    }
    var position: String {
        didSet { defaults.set(position, forKey: Keys.position) }
    }

    private init() {
        hasCompletedOnboarding = defaults.bool(forKey: Keys.completed)
        displayName = defaults.string(forKey: Keys.name) ?? "Player One"
        username = defaults.string(forKey: Keys.username) ?? ""
        kitNumber = defaults.string(forKey: Keys.kit) ?? "09"
        position = defaults.string(forKey: Keys.position) ?? ""
    }

    /// Initials derived from the display name (max two letters, uppercased).
    var initials: String {
        let parts = displayName
            .split(separator: " ")
            .map { String($0) }
            .filter { !$0.isEmpty }
        guard let first = parts.first?.first else { return "P1" }
        if parts.count >= 2, let second = parts[1].first {
            return "\(first)\(second)".uppercased()
        }
        return String(first).uppercased()
    }

    /// Persist the onboarding result and mark the flow complete.
    func complete(name: String, username: String = "", kit: String, position: String) {
        displayName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !username.isEmpty { self.username = username }
        kitNumber = kit
        self.position = position
        hasCompletedOnboarding = true
    }

    /// Merge shareable fields returned after redeeming a coach invite code.
    func applyRosterMerge(name: String?, kit: String?, position: String?) {
        if let name, !name.isEmpty { displayName = name }
        if let kit, !kit.isEmpty { kitNumber = kit }
        if let position, !position.isEmpty { self.position = position }
    }

    /// Reset for testing / sign-out.
    func reset() {
        hasCompletedOnboarding = false
        displayName = "Player One"
        username = ""
        kitNumber = "09"
        position = ""
    }
}
