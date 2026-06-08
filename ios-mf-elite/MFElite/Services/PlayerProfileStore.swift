//
//  PlayerProfileStore.swift
//  MFElite
//
//  Lightweight, UserDefaults-backed store for the player's identity captured
//  during onboarding (name, initials, kit number, position) plus the
//  onboarding-complete flag. This is the only source of truth for the player's
//  identity — V1 is fully local, on-device.
//

import SwiftUI
import UIKit
import Observation

/// The player's chosen avatar: none (fall back to monogram), a built-in MF
/// design referenced by id, or a custom photo stored on-device.
enum AvatarSelection: Equatable {
    case none
    case builtin(String)
    case photo
}

@Observable
@MainActor
final class PlayerProfileStore {
    static let shared = PlayerProfileStore()

    /// Identifiers for the built-in MF avatar set rendered by `AvatarView`.
    static let builtinAvatarIDs: [String] = [
        "crest", "slash", "flame", "shield", "target", "bolt",
        "star", "crown", "trophy", "diamond", "globe", "moon",
        "flag", "heart", "leaf", "sun", "mountain", "lion"
    ]

    private enum Keys {
        static let completed = "MF_ONBOARDING_COMPLETE"
        static let name = "MF_PLAYER_NAME"
        static let username = "MF_PLAYER_USERNAME"
        static let kit = "MF_PLAYER_KIT"
        static let position = "MF_PLAYER_POSITION"
        static let skipped = "MF_ONBOARDING_SKIPPED"
        static let promptDismissed = "MF_PROFILE_PROMPT_DISMISSED"
        static let sessionCount = "MF_SESSION_COUNT"
        static let avatarKind = "MF_AVATAR_KIND"
        static let avatarBuiltin = "MF_AVATAR_BUILTIN"
    }

    private static let photoFileName = "player_avatar.jpg"

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

    /// The currently selected avatar. Persisted across launches.
    private(set) var avatar: AvatarSelection = .none
    /// Loaded custom photo, when `avatar == .photo`. Bumped on change so views refresh.
    private(set) var avatarPhoto: UIImage?

    private init() {
        hasCompletedOnboarding = defaults.bool(forKey: Keys.completed)
        displayName = defaults.string(forKey: Keys.name) ?? "Player"
        username = defaults.string(forKey: Keys.username) ?? ""
        kitNumber = defaults.string(forKey: Keys.kit) ?? ""
        position = defaults.string(forKey: Keys.position) ?? ""
        onboardingSkipped = defaults.bool(forKey: Keys.skipped)
        profilePromptDismissed = defaults.bool(forKey: Keys.promptDismissed)
        sessionCount = defaults.integer(forKey: Keys.sessionCount)
        loadAvatar()
    }

    // MARK: - Avatar

    private static var photoURL: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent(photoFileName)
    }

    private func loadAvatar() {
        switch defaults.string(forKey: Keys.avatarKind) {
        case "builtin":
            let id = defaults.string(forKey: Keys.avatarBuiltin) ?? Self.builtinAvatarIDs[0]
            avatar = .builtin(id)
        case "photo":
            if let data = try? Data(contentsOf: Self.photoURL), let image = UIImage(data: data) {
                avatarPhoto = image
                avatar = .photo
            } else {
                avatar = .none
            }
        default:
            avatar = .none
        }
    }

    /// Choose one of the built-in MF avatars.
    func setBuiltinAvatar(_ id: String) {
        avatar = .builtin(id)
        avatarPhoto = nil
        defaults.set("builtin", forKey: Keys.avatarKind)
        defaults.set(id, forKey: Keys.avatarBuiltin)
        try? FileManager.default.removeItem(at: Self.photoURL)
    }

    /// Store a custom photo as the avatar (downscaled for storage).
    func setPhotoAvatar(_ image: UIImage) {
        let resized = image.mf_resized(maxDimension: 512)
        guard let data = resized.jpegData(compressionQuality: 0.85) else { return }
        try? data.write(to: Self.photoURL, options: .atomic)
        avatarPhoto = resized
        avatar = .photo
        defaults.set("photo", forKey: Keys.avatarKind)
    }

    /// Clear any chosen avatar, reverting to the initials monogram.
    func clearAvatar() {
        avatar = .none
        avatarPhoto = nil
        defaults.removeObject(forKey: Keys.avatarKind)
        defaults.removeObject(forKey: Keys.avatarBuiltin)
        try? FileManager.default.removeItem(at: Self.photoURL)
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

    /// Reset for testing.
    func reset() {
        hasCompletedOnboarding = false
        displayName = "Player"
        username = ""
        kitNumber = ""
        position = ""
        onboardingSkipped = false
        profilePromptDismissed = false
        clearAvatar()
    }
}

extension UIImage {
    /// Downscale so the longest edge is at most `maxDimension`, preserving aspect.
    func mf_resized(maxDimension: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maxDimension else { return self }
        let scale = maxDimension / longest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
