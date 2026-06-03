//
//  ProfileValidation.swift
//  MFElite
//
//  Single source of truth for player-profile field rules, reused by BOTH the
//  player onboarding flow and the coach admin so nothing can ever be stored in
//  the wrong shape. Username is the only uniqueness-enforced field (checked
//  remotely); everything here is pure, synchronous format validation.
//

import Foundation

nonisolated enum ProfileValidation {

    // MARK: - Constants

    /// Allowed playing positions — fixed set shared across player + coach paths.
    static let positions: [String] = [
        "Goalkeeper", "Defender", "Midfielder", "Forward", "Winger", "No preference"
    ]

    static let usernameMinLength = 3
    static let usernameMaxLength = 20
    static let nameMaxLength = 40
    static let kitNumberRange = 1...99

    // MARK: - Username

    /// Normalised, storable form of a username (trimmed, lowercased for matching
    /// is done server-side; we preserve the user's casing for display).
    static func normalizedUsername(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    enum UsernameError: LocalizedError, Equatable {
        case tooShort, tooLong, invalidCharacters, taken

        var errorDescription: String? {
            switch self {
            case .tooShort: return "Username must be at least \(usernameMinLength) characters."
            case .tooLong: return "Username must be \(usernameMaxLength) characters or fewer."
            case .invalidCharacters: return "Use letters, numbers, underscores or periods only."
            case .taken: return "That username is already taken — choose another."
            }
        }
    }

    /// Validate the FORMAT of a username (does not check remote availability).
    static func validateUsernameFormat(_ raw: String) -> UsernameError? {
        let value = normalizedUsername(raw)
        if value.count < usernameMinLength { return .tooShort }
        if value.count > usernameMaxLength { return .tooLong }
        let allowed = CharacterSet(charactersIn:
            "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.")
        if value.unicodeScalars.contains(where: { !allowed.contains($0) }) {
            return .invalidCharacters
        }
        return nil
    }

    /// True when a candidate is at least format-valid.
    static func isUsernameFormatValid(_ raw: String) -> Bool {
        validateUsernameFormat(raw) == nil
    }

    // MARK: - Display name

    static func normalizedName(_ raw: String) -> String {
        String(raw.trimmingCharacters(in: .whitespacesAndNewlines).prefix(nameMaxLength))
    }

    static func isNameValid(_ raw: String) -> Bool {
        !normalizedName(raw).isEmpty
    }

    /// Initials derived from a display name (max two letters, uppercased).
    static func initials(from name: String) -> String {
        let parts = normalizedName(name)
            .split(separator: " ")
            .map(String.init)
            .filter { !$0.isEmpty }
        guard let first = parts.first?.first else { return "P1" }
        if parts.count >= 2, let second = parts[1].first {
            return "\(first)\(second)".uppercased()
        }
        return String(first).uppercased()
    }

    // MARK: - Kit number

    /// Clamp + zero-pad to the canonical two-digit stored form ("07", "23").
    static func normalizedKitNumber(_ raw: String) -> String {
        let digits = raw.filter(\.isNumber)
        let value = min(max(Int(digits) ?? 1, kitNumberRange.lowerBound), kitNumberRange.upperBound)
        return String(format: "%02d", value)
    }

    static func isKitNumberValid(_ raw: String) -> Bool {
        guard let value = Int(raw.filter(\.isNumber)) else { return false }
        return kitNumberRange.contains(value)
    }

    // MARK: - Position

    static func isPositionValid(_ raw: String) -> Bool {
        positions.contains(raw)
    }

    // MARK: - Invite code

    /// Coach invite codes are 6 chars, A–Z/0–9, matching the onboarding code box.
    static let inviteCodeLength = 6

    static func normalizedInviteCode(_ raw: String) -> String {
        String(raw.uppercased().filter { $0.isLetter || $0.isNumber }.prefix(inviteCodeLength))
    }

    static func isInviteCodeValid(_ raw: String) -> Bool {
        normalizedInviteCode(raw).count == inviteCodeLength
    }

    /// Generate a fresh random 6-char invite code (coach setup / add player).
    static func generateInviteCode() -> String {
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789") // no ambiguous 0/O/1/I
        return String((0..<inviteCodeLength).map { _ in alphabet.randomElement() ?? "M" })
    }
}
