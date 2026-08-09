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

/// An undoable capture of the avatar, including the photo itself.
///
/// Avatar changes are applied to the shared store the instant they are made so
/// the card preview updates live. That means a screen offering Cancel has to be
/// able to put the old one back — and because `clearAvatar()` deletes the file
/// on disk, remembering the selection alone isn't enough.
struct AvatarSnapshot {
    let selection: AvatarSelection
    let photo: UIImage?
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
        static let positionCode = "MF_PLAYER_POSITION_CODE"
        static let foot = "MF_PLAYER_FOOT"
        static let classYear = "MF_PLAYER_CLASS_YEAR"
        static let birthYear = "MF_PLAYER_BIRTH_YEAR"
        static let gender = "MF_PLAYER_GENDER"
        static let trainingLevel = "MF_PLAYER_TRAINING_LEVEL"
        static let skipped = "MF_ONBOARDING_SKIPPED"
        static let promptDismissed = "MF_PROFILE_PROMPT_DISMISSED"
        static let sessionCount = "MF_SESSION_COUNT"
        static let avatarKind = "MF_AVATAR_KIND"
        static let avatarBuiltin = "MF_AVATAR_BUILTIN"
        static let accent = AppAccent.storageKey
        static let symbolStyle = SymbolStyle.storageKey
        static let ringStyle = RingStyle.storageKey
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
    /// Short position code shown on the player card (e.g. "ST", "CM", "GK").
    var positionCode: String {
        didSet { defaults.set(positionCode, forKey: Keys.positionCode) }
    }
    /// Preferred foot ("Right", "Left", "Both").
    var foot: String {
        didSet { defaults.set(foot, forKey: Keys.foot) }
    }
    /// Graduation class year. 0 means unset.
    var classYear: Int {
        didSet { defaults.set(classYear, forKey: Keys.classYear) }
    }
    /// Year of birth, used to derive age for age-appropriate guidance and
    /// parental-control decisions. 0 means unset.
    var birthYear: Int {
        didSet { defaults.set(birthYear, forKey: Keys.birthYear) }
    }
    /// Grading gender for combine benchmarks: "male", "female", or "" (unspecified).
    /// "" and "male" grade on the male scale; "female" grades on the female scale.
    var gender: String {
        didSet { defaults.set(gender, forKey: Keys.gender) }
    }
    /// Self-reported starting skill level captured at onboarding. Empty when unset.
    /// Biases the default recommendation and session generator; never locks content.
    var trainingLevel: String {
        didSet { defaults.set(trainingLevel, forKey: Keys.trainingLevel) }
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

    /// The selected app accent color id ("gold", "silver", "royal", "crimson",
    /// "pitch"). Observed by the root view so an accent change re-renders the
    /// whole UI live.
    var accentID: String {
        didSet { defaults.set(accentID, forKey: Keys.accent) }
    }

    /// Whether identity symbols and avatars take the accent, or stay
    /// monochrome. Observed by the root view (same as `accentID`) so a change
    /// re-renders the whole UI live.
    var symbolStyleID: String {
        didSet { defaults.set(symbolStyleID, forKey: Keys.symbolStyle) }
    }

    /// Whether the daily training rings take the accent or stay white.
    /// Observed by the root view like `accentID`, so a change re-renders live.
    var ringStyleID: String {
        didSet { defaults.set(ringStyleID, forKey: Keys.ringStyle) }
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
        positionCode = defaults.string(forKey: Keys.positionCode) ?? ""
        foot = defaults.string(forKey: Keys.foot) ?? "Right"
        classYear = defaults.integer(forKey: Keys.classYear)
        birthYear = defaults.integer(forKey: Keys.birthYear)
        gender = defaults.string(forKey: Keys.gender) ?? ""
        trainingLevel = defaults.string(forKey: Keys.trainingLevel) ?? ""
        onboardingSkipped = defaults.bool(forKey: Keys.skipped)
        profilePromptDismissed = defaults.bool(forKey: Keys.promptDismissed)
        sessionCount = defaults.integer(forKey: Keys.sessionCount)
        accentID = defaults.string(forKey: Keys.accent) ?? AppAccent.gold.rawValue
        symbolStyleID = defaults.string(forKey: Keys.symbolStyle) ?? SymbolStyle.accent.rawValue
        ringStyleID = defaults.string(forKey: Keys.ringStyle) ?? RingStyle.accent.rawValue
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

    /// Capture the current avatar so it can be restored if the user cancels.
    func avatarSnapshot() -> AvatarSnapshot {
        AvatarSnapshot(selection: avatar, photo: avatarPhoto)
    }

    /// Put back an avatar captured with `avatarSnapshot()`, rewriting the photo
    /// file if it was removed in the meantime. No-op when nothing changed.
    func restoreAvatar(_ snapshot: AvatarSnapshot) {
        // Compared by identity as well as by case: `AvatarSelection` carries no
        // photo identity, so `.photo != .photo` is false even when the player
        // swapped one photo for another — which is the common way into this.
        guard snapshot.selection != avatar || snapshot.photo !== avatarPhoto else { return }
        switch snapshot.selection {
        case .photo:
            if let photo = snapshot.photo {
                setPhotoAvatar(photo)
            } else {
                clearAvatar()
            }
        case .builtin(let id):
            setBuiltinAvatar(id)
        case .none:
            clearAvatar()
        }
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

    /// The lowest mastery-level number the plan should bias toward when the player
    /// has no progress yet, derived from the captured training level. Defaults to
    /// 1 (no bias) when unset. Lower content is never locked.
    var startingLevelBias: Int {
        TrainingLevel(rawValue: trainingLevel)?.startingLevelBias ?? 1
    }

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
    func complete(
        name: String,
        username: String = "",
        kit: String,
        position: String,
        positionCode: String = "",
        foot: String = "Right",
        classYear: Int = 0,
        birthYear: Int = 0,
        trainingLevel: TrainingLevel? = nil,
        skipped: Bool = false
    ) {
        displayName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !username.isEmpty { self.username = username }
        kitNumber = kit
        self.position = position
        self.positionCode = positionCode
        self.foot = foot
        self.classYear = classYear
        if birthYear > 0 { self.birthYear = birthYear }
        if let trainingLevel { self.trainingLevel = trainingLevel.rawValue }
        onboardingSkipped = skipped
        hasCompletedOnboarding = true
    }

    /// Class year text shown on the card; "—" when unset.
    var classYearText: String { classYear > 0 ? String(classYear) : "—" }

    /// Derived age from `birthYear`, or nil when unset.
    var age: Int? {
        guard birthYear > 0 else { return nil }
        let currentYear = Calendar.current.component(.year, from: Date())
        let value = currentYear - birthYear
        return (value >= 4 && value <= 99) ? value : nil
    }

    /// Whether combine results grade on the female benchmark scale. Male and
    /// unspecified ("prefer not to say") both use the male scale by design.
    var gradesFemale: Bool { gender == "female" }

    /// True when the player is known to be under 13 (COPPA-relevant).
    var isLikelyUnder13: Bool {
        guard let age else { return false }
        return age < 13
    }

    /// Reset for testing.
    func reset() {
        hasCompletedOnboarding = false
        displayName = "Player"
        username = ""
        kitNumber = ""
        position = ""
        positionCode = ""
        foot = "Right"
        classYear = 0
        birthYear = 0
        trainingLevel = ""
        onboardingSkipped = false
        profilePromptDismissed = false
        // Both are `didSet`-persisted, so clearing their UserDefaults keys from
        // outside wouldn't stick — the next write puts the old value back.
        // `gender` in particular sets the combine benchmark scale.
        gender = ""
        sessionCount = 0
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
