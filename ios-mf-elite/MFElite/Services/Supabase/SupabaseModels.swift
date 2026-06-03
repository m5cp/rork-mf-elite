//
//  SupabaseModels.swift
//  MFElite
//
//  Codable DTOs mapping Supabase rows (snake_case) to Swift. These are decoded
//  off the main actor by PostgREST, so every type is `nonisolated` + `Sendable`.
//

import Foundation

// MARK: - Profile

nonisolated struct ProfileUpsert: Encodable, Sendable {
    let id: String
    let email: String
    let name: String?
}

nonisolated struct PlayerProfileUpsert: Encodable, Sendable {
    let id: String
    let accountId: String
    let username: String
    let displayName: String
    let initials: String
    let kitNumber: String
    let position: String

    enum CodingKeys: String, CodingKey {
        case id, username, position
        case accountId = "account_id"
        case displayName = "display_name"
        case initials
        case kitNumber = "kit_number"
    }
}

/// Shareable roster row a coach (or owner) can read. Contains NO private data
/// — no email, sign-in identity, or billing. Mirrors the `player_profiles`
/// columns the RLS layer exposes.
nonisolated struct PlayerProfileRow: Codable, Sendable, Identifiable {
    let id: String
    let accountId: String?
    let username: String?
    let displayName: String?
    let initials: String?
    let kitNumber: String?
    let position: String?
    let managed: Bool?
    let isExample: Bool?

    enum CodingKeys: String, CodingKey {
        case id, username, position, managed, initials
        case accountId = "account_id"
        case displayName = "display_name"
        case kitNumber = "kit_number"
        case isExample = "is_example"
    }
}

/// Coach edit of a player's shareable roster fields (never the username).
nonisolated struct PlayerRosterUpdate: Encodable, Sendable {
    let displayName: String
    let initials: String
    let kitNumber: String
    let position: String

    enum CodingKeys: String, CodingKey {
        case position, initials
        case displayName = "display_name"
        case kitNumber = "kit_number"
    }
}

// MARK: - Roster invites (coach-issued codes)

nonisolated struct RosterInviteInsert: Encodable, Sendable {
    let code: String
    let coachId: String
    let displayName: String?
    let kitNumber: String?
    let position: String?
    let isExample: Bool

    enum CodingKeys: String, CodingKey {
        case code, position
        case coachId = "coach_id"
        case displayName = "display_name"
        case kitNumber = "kit_number"
        case isExample = "is_example"
    }
}

nonisolated struct RosterInviteRow: Codable, Sendable, Identifiable {
    let id: String
    let code: String
    let displayName: String?
    let kitNumber: String?
    let position: String?
    let status: String

    enum CodingKeys: String, CodingKey {
        case id, code, status, position
        case displayName = "display_name"
        case kitNumber = "kit_number"
    }
}

nonisolated struct ClaimInviteParams: Encodable, Sendable {
    let inviteCode: String
    let pUsername: String

    enum CodingKeys: String, CodingKey {
        case inviteCode = "invite_code"
        case pUsername = "p_username"
    }
}

nonisolated struct UsernameAvailableParams: Encodable, Sendable {
    let candidate: String
}

// MARK: - Curriculum (read)

nonisolated struct SupabaseDiscipline: Codable, Sendable, Identifiable {
    let id: String
    let number: String
    let name: String
    let mark: String
    let tagline: String?
    let blurb: String?
    let media: String?
    let sortIndex: Int

    enum CodingKeys: String, CodingKey {
        case id, number, name, mark, tagline, blurb, media
        case sortIndex = "sort_index"
    }
}

nonisolated struct SupabaseCategory: Codable, Sendable, Identifiable {
    let id: String
    let disciplineId: String
    let letter: String
    let name: String
    let focus: String?
    let certName: String?
    let sortIndex: Int

    enum CodingKeys: String, CodingKey {
        case id, letter, name, focus
        case disciplineId = "discipline_id"
        case certName = "cert_name"
        case sortIndex = "sort_index"
    }
}

nonisolated struct SupabaseLevel: Codable, Sendable, Identifiable {
    let id: String
    let categoryId: String
    let number: Int
    let name: String
    let theme: String?
    let sortIndex: Int

    enum CodingKeys: String, CodingKey {
        case id, number, name, theme
        case categoryId = "category_id"
        case sortIndex = "sort_index"
    }
}

nonisolated struct SupabaseDrill: Codable, Sendable, Identifiable {
    let id: String
    let levelId: String
    let title: String
    let focus: String?
    let how: String?
    let videoUrl: String?
    let durationSec: Int
    let sets: Int
    let coachingPoints: [String]
    let sortIndex: Int

    enum CodingKeys: String, CodingKey {
        case id, title, focus, how, sets
        case levelId = "level_id"
        case videoUrl = "video_url"
        case durationSec = "duration_sec"
        case coachingPoints = "coaching_points"
        case sortIndex = "sort_index"
    }
}

// MARK: - Curriculum (write)

nonisolated struct SupabaseDrillInsert: Encodable, Sendable {
    let levelId: String
    let title: String
    let focus: String
    let how: String
    let videoUrl: String?
    let durationSec: Int
    let sets: Int
    let coachingPoints: [String]
    let sortIndex: Int

    enum CodingKeys: String, CodingKey {
        case title, focus, how, sets
        case levelId = "level_id"
        case videoUrl = "video_url"
        case durationSec = "duration_sec"
        case coachingPoints = "coaching_points"
        case sortIndex = "sort_index"
    }
}

nonisolated struct SupabaseCategoryInsert: Encodable, Sendable {
    let disciplineId: String
    let letter: String
    let name: String
    let focus: String
    let certName: String
    let sortIndex: Int

    enum CodingKeys: String, CodingKey {
        case letter, name, focus
        case disciplineId = "discipline_id"
        case certName = "cert_name"
        case sortIndex = "sort_index"
    }
}

// MARK: - Progression rules

nonisolated struct SupabaseProgressionRules: Codable, Sendable, Identifiable {
    let id: String
    let xpPerDrill: Int
    let xpLevelBonus: Int
    let xpCategoryCert: Int
    let xpDisciplineDiploma: Int
    let freeLevels: Int
    let masteryPasses: Int

    enum CodingKeys: String, CodingKey {
        case id
        case xpPerDrill = "xp_per_drill"
        case xpLevelBonus = "xp_level_bonus"
        case xpCategoryCert = "xp_category_cert"
        case xpDisciplineDiploma = "xp_discipline_diploma"
        case freeLevels = "free_levels"
        case masteryPasses = "mastery_passes"
    }
}

nonisolated struct SupabaseProgressionRulesUpdate: Encodable, Sendable {
    let xpPerDrill: Int
    let xpLevelBonus: Int
    let xpCategoryCert: Int
    let xpDisciplineDiploma: Int
    let freeLevels: Int
    let masteryPasses: Int

    enum CodingKeys: String, CodingKey {
        case xpPerDrill = "xp_per_drill"
        case xpLevelBonus = "xp_level_bonus"
        case xpCategoryCert = "xp_category_cert"
        case xpDisciplineDiploma = "xp_discipline_diploma"
        case freeLevels = "free_levels"
        case masteryPasses = "mastery_passes"
    }
}

// MARK: - Quotes / announcements

nonisolated struct SupabaseQuote: Codable, Sendable, Identifiable {
    let id: String
    let quote: String
    let sortIndex: Int
    let active: Bool

    enum CodingKeys: String, CodingKey {
        case id, quote, active
        case sortIndex = "sort_index"
    }
}

nonisolated struct SupabaseQuoteInsert: Encodable, Sendable {
    let quote: String
    let sortIndex: Int
    let active: Bool

    enum CodingKeys: String, CodingKey {
        case quote, active
        case sortIndex = "sort_index"
    }
}

nonisolated struct SupabaseAnnouncement: Codable, Sendable, Identifiable {
    let id: String
    let title: String
    let body: String?
    let active: Bool

    enum CodingKeys: String, CodingKey {
        case id, title, body, active
    }
}

// MARK: - Player state / progress / certs

nonisolated struct PlayerStateUpsert: Encodable, Sendable {
    let playerId: String
    let xp: Int
    let streak: Int
    let freezesRemaining: Int
    let lastTrainedDate: String?
    let streakPb: Int

    enum CodingKeys: String, CodingKey {
        case xp, streak
        case playerId = "player_id"
        case freezesRemaining = "freezes_remaining"
        case lastTrainedDate = "last_trained_date"
        case streakPb = "streak_pb"
    }
}

nonisolated struct PlayerStateRow: Codable, Sendable {
    let playerId: String
    let xp: Int
    let streak: Int
    let freezesRemaining: Int
    let lastTrainedDate: String?
    let streakPb: Int

    enum CodingKeys: String, CodingKey {
        case xp, streak
        case playerId = "player_id"
        case freezesRemaining = "freezes_remaining"
        case lastTrainedDate = "last_trained_date"
        case streakPb = "streak_pb"
    }
}

nonisolated struct PlayerProgressUpsert: Encodable, Sendable {
    let playerId: String
    let drillId: String
    let passesLogged: Int
    let isMastered: Bool
    let lastLoggedAt: Date?

    enum CodingKeys: String, CodingKey {
        case playerId = "player_id"
        case drillId = "drill_id"
        case passesLogged = "passes_logged"
        case isMastered = "is_mastered"
        case lastLoggedAt = "last_logged_at"
    }
}

nonisolated struct PlayerProgressRow: Codable, Sendable {
    let drillId: String
    let passesLogged: Int
    let isMastered: Bool
    let lastLoggedAt: Date?

    enum CodingKeys: String, CodingKey {
        case drillId = "drill_id"
        case passesLogged = "passes_logged"
        case isMastered = "is_mastered"
        case lastLoggedAt = "last_logged_at"
    }
}

nonisolated struct CertificationInsert: Encodable, Sendable {
    let playerId: String
    let categoryId: String

    enum CodingKeys: String, CodingKey {
        case playerId = "player_id"
        case categoryId = "category_id"
    }
}
