//
//  AchievementBadge.swift
//  MFElite
//
//  Achievement badges awarded for training milestones, mastery, streaks, and
//  special moments. Earned state is persisted in UserDefaults via AchievementStore.
//

import Foundation

enum AchievementBadge: String, CaseIterable, Identifiable {
    // Training milestones
    case firstDrill = "first_drill"
    case tenDrills = "ten_drills"
    case fiftyDrills = "fifty_drills"
    case hundredDrills = "hundred_drills"

    // Mastery milestones
    case firstMastery = "first_mastery"
    case tenMastered = "ten_mastered"
    case fiftyMastered = "fifty_mastered"

    // Streak milestones
    case weekStreak = "week_streak"
    case monthStreak = "month_streak"
    case fiftyDayStreak = "fifty_day_streak"
    case hundredDayStreak = "hundred_day_streak"

    // Special
    case perfectWeek = "perfect_week"
    case firstCert = "first_cert"
    case earlyBird = "early_bird"
    case nightOwl = "night_owl"

    // Perfect days (all three daily rings closed)
    case perfectDay = "perfect_day"
    case perfectDay7 = "perfect_day_7"
    case perfectDay30 = "perfect_day_30"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .firstDrill: return "First Rep"
        case .tenDrills: return "Getting Started"
        case .fiftyDrills: return "Committed"
        case .hundredDrills: return "Century"
        case .firstMastery: return "First Mastery"
        case .tenMastered: return "Sharpening"
        case .fiftyMastered: return "Elite Form"
        case .weekStreak: return "Week One"
        case .monthStreak: return "The Month"
        case .fiftyDayStreak: return "Fifty"
        case .hundredDayStreak: return "Centurion"
        case .perfectWeek: return "Perfect Week"
        case .firstCert: return "Certified"
        case .earlyBird: return "Early Bird"
        case .nightOwl: return "Night Owl"
        case .perfectDay: return "Perfect Day"
        case .perfectDay7: return "Seven Perfect"
        case .perfectDay30: return "Thirty Perfect"
        }
    }

    var detail: String {
        switch self {
        case .firstDrill: return "Complete your first drill"
        case .tenDrills: return "Complete 10 drills"
        case .fiftyDrills: return "Complete 50 drills"
        case .hundredDrills: return "Complete 100 drills"
        case .firstMastery: return "Master your first drill"
        case .tenMastered: return "Master 10 drills"
        case .fiftyMastered: return "Master 50 drills"
        case .weekStreak: return "7-day training streak"
        case .monthStreak: return "30-day training streak"
        case .fiftyDayStreak: return "50-day training streak"
        case .hundredDayStreak: return "100-day training streak"
        case .perfectWeek: return "Train every day for a full week"
        case .firstCert: return "Earn your first certification"
        case .earlyBird: return "Train before 7:00 AM"
        case .nightOwl: return "Train after 9:00 PM"
        case .perfectDay: return "Close all three daily rings"
        case .perfectDay7: return "Close all rings on 7 days"
        case .perfectDay30: return "Close all rings on 30 days"
        }
    }

    var icon: String {
        switch self {
        case .firstDrill: return "play.circle"
        case .tenDrills: return "10.circle"
        case .fiftyDrills: return "star.circle"
        case .hundredDrills: return "crown"
        case .firstMastery: return "checkmark.seal"
        case .tenMastered: return "checkmark.seal.fill"
        case .fiftyMastered: return "trophy"
        case .weekStreak: return "flame"
        case .monthStreak: return "flame.fill"
        case .fiftyDayStreak: return "bolt.circle"
        case .hundredDayStreak: return "bolt.circle.fill"
        case .perfectWeek: return "calendar.badge.checkmark"
        case .firstCert: return "rosette"
        case .earlyBird: return "sunrise"
        case .nightOwl: return "moon.stars"
        case .perfectDay: return "circle.circle"
        case .perfectDay7: return "circle.circle.fill"
        case .perfectDay30: return "circle.hexagongrid.circle.fill"
        }
    }

    /// Game Center achievement identifier for this badge. Must match the IDs
    /// configured in App Store Connect. Reporting no-ops safely until they exist.
    var gameCenterID: String {
        "mf.elite.achievement.\(rawValue)"
    }

    /// Check threshold for drill-count badges
    static func drillCountBadges(for count: Int) -> [AchievementBadge] {
        var earned: [AchievementBadge] = []
        if count >= 1 { earned.append(.firstDrill) }
        if count >= 10 { earned.append(.tenDrills) }
        if count >= 50 { earned.append(.fiftyDrills) }
        if count >= 100 { earned.append(.hundredDrills) }
        return earned
    }

    /// Check threshold for mastery badges
    static func masteryBadges(for count: Int) -> [AchievementBadge] {
        var earned: [AchievementBadge] = []
        if count >= 1 { earned.append(.firstMastery) }
        if count >= 10 { earned.append(.tenMastered) }
        if count >= 50 { earned.append(.fiftyMastered) }
        return earned
    }

    /// Check threshold for perfect-day count badges (days with all rings closed).
    static func perfectDayBadges(for count: Int) -> [AchievementBadge] {
        var earned: [AchievementBadge] = []
        if count >= 1 { earned.append(.perfectDay) }
        if count >= 7 { earned.append(.perfectDay7) }
        if count >= 30 { earned.append(.perfectDay30) }
        return earned
    }

    /// Check threshold for streak badges
    static func streakBadges(for streak: Int) -> [AchievementBadge] {
        var earned: [AchievementBadge] = []
        if streak >= 7 { earned.append(.weekStreak) }
        if streak >= 30 { earned.append(.monthStreak) }
        if streak >= 50 { earned.append(.fiftyDayStreak) }
        if streak >= 100 { earned.append(.hundredDayStreak) }
        return earned
    }
}

/// Persists earned achievement badge IDs in UserDefaults.
enum AchievementStore {
    private static let key = "MF_EARNED_BADGES"

    static var earnedIDs: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
    }

    static func isEarned(_ badge: AchievementBadge) -> Bool {
        earnedIDs.contains(badge.rawValue)
    }

    static func earn(_ badge: AchievementBadge) {
        let alreadyEarned = earnedIDs.contains(badge.rawValue)
        var ids = earnedIDs
        ids.insert(badge.rawValue)
        UserDefaults.standard.set(Array(ids), forKey: key)
        if !alreadyEarned {
            GameCenterService.shared.reportAchievement(badge.gameCenterID)
            Task { @MainActor in SyncEngine.shared.enqueueBadge(badgeID: badge.rawValue) }
        }
    }

    static func earnAll(_ badges: [AchievementBadge]) {
        let existing = earnedIDs
        var ids = existing
        for badge in badges {
            ids.insert(badge.rawValue)
        }
        UserDefaults.standard.set(Array(ids), forKey: key)
        let newlyEarned = badges.filter { !existing.contains($0.rawValue) }
        if !newlyEarned.isEmpty {
            GameCenterService.shared.report(newlyEarned.map { ($0.gameCenterID, 100.0) })
        }
        for badge in newlyEarned {
            Task { @MainActor in SyncEngine.shared.enqueueBadge(badgeID: badge.rawValue) }
        }
    }

    /// Apply badge IDs pulled from the cloud during restore. No Game Center
    /// re-report and no re-enqueue — these were already earned on another device.
    static func applyRemote(_ ids: [String]) {
        guard !ids.isEmpty else { return }
        var merged = earnedIDs
        for id in ids { merged.insert(id) }
        UserDefaults.standard.set(Array(merged), forKey: key)
    }

    /// Forget every earned badge. Account deletion only — badges are the
    /// previous account's, and without this they were inherited by whoever
    /// signed in next on this device.
    static func reset() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    static var earnedCount: Int {
        earnedIDs.count
    }
}
