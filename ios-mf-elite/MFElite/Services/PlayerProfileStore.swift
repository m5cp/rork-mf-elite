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
        static let skipped = "MF_ONBOARDING_SKIPPED"
        static let promptDismissed = "MF_PROFILE_PROMPT_DISMISSED"
        static let sessionCount = "MF_SESSION_COUNT"
        static let memberNumber = "MF_PLAYER_MEMBER_NUMBER"
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
    /// True when the player bypassed onboarding and is running on defaults.
    var onboardingSkipped: Bool {
        didSet { defaults.set(onboardingSkipped, forKey: Keys.skipped) }
    }
    /// True once the player permanently dismisses the "complete your profile" prompt.
    var profilePromptDismissed: Bool {
        didSet { defaults.set(profilePromptDismissed, forKey: Keys.promptDismissed) }
    }
    /// Number of app launches, used to limit the re-engagement banner.
    var sessionCount: Int {
        didSet { defaults.set(sessionCount, forKey: Keys.sessionCount) }
    }
    /// The player's real, sequential member number (issued by Supabase). Nil
    /// until it has been successfully claimed.
    var memberNumber: Int? {
        didSet {
            if let memberNumber {
                defaults.set(memberNumber, forKey: Keys.memberNumber)
            } else {
                defaults.removeObject(forKey: Keys.memberNumber)
            }
        }
    }

    private init() {
        hasCompletedOnboarding = defaults.bool(forKey: Keys.completed)
        displayName = defaults.string(forKey: Keys.name) ?? "Player"
        username = defaults.string(forKey: Keys.username) ?? ""
        kitNumber = defaults.string(forKey: Keys.kit) ?? ""
        position = defaults.string(forKey: Keys.position) ?? ""
        onboardingSkipped = defaults.bool(forKey: Keys.skipped)
        profilePromptDismissed = defaults.bool(forKey: Keys.promptDismissed)
        sessionCount = defaults.integer(forKey: Keys.sessionCount)
        memberNumber = defaults.object(forKey: Keys.memberNumber) as? Int
    }

    /// Show the Today "complete your profile" banner only to skippers, for the
    /// first three sessions, until they explicitly dismiss it.
    var shouldPromptProfileCompletion: Bool {
        onboardingSkipped && !profilePromptDismissed && sessionCount <= 3
    }

    func incrementSession() { sessionCount += 1 }

    /// Initials derived from the display name (max two letters, uppercased).
    var initials: String {
        let parts = displayName
            .split(separator: " ")
            .map { String($0) }
            .filter { !$0.isEmpty }
        guard let first = parts.first?.first else { return "P" }
        if parts.count >= 2, let second = parts[1].first {
            return "\(first)\(second)".uppercased()
        }
        return String(first).uppercased()
    }

    /// Persist the onboarding result and mark the flow complete.
    func complete(name: String, username: String = "", kit: String, position: String, skipped: Bool = false) {
        displayName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !username.isEmpty { self.username = username }
        kitNumber = kit
        self.position = position
        onboardingSkipped = skipped
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
        displayName = "Player"
        username = ""
        kitNumber = ""
        position = ""
        onboardingSkipped = false
        profilePromptDismissed = false
        memberNumber = nil
    }
}
