//
//  CelebrationShare.swift
//  MFElite
//
//  Builds the share payload for celebration screens: the player's rendered
//  Player Card (same exporter the Player Card screen uses) when one is
//  configured, otherwise a plain text line — sharing never blocks on card
//  setup.
//

import SwiftUI
import UIKit

@MainActor
enum CelebrationShare {
    /// True when there's a card worth rendering — the player has saved a card
    /// design at least once or has a profile photo to feature.
    static var hasConfiguredCard: Bool {
        PlayerCardStore.shared.hasSavedDesign || PlayerProfileStore.shared.avatarPhoto != nil
    }

    /// The rendered Player Card image (export resolution, first-name only), or
    /// `fallbackText` when the player has never configured a card.
    static func items(player: PlayerState?, fallbackText: String) -> [Any] {
        guard hasConfiguredCard else { return [fallbackText] }

        let profile = PlayerProfileStore.shared
        let xp = player?.xp ?? 0
        let rank = AcademyRank.unlockedRank(
            for: player?.rankXP ?? 0,
            hasFullAccess: SubscriptionService.shared.hasFullAccess
        )
        let info = CardPlayerInfo(
            name: profile.displayName,
            rankNumeral: rank.numeral,
            rankTitle: rank.title,
            xp: xp,
            streak: player?.streak ?? 0,
            position: profile.position,
            positionCode: profile.positionCode,
            kitNumber: profile.kitNumber,
            foot: profile.foot,
            classYearText: profile.classYearText,
            academy: "MF Elite",
            initials: profile.initials,
            avatar: profile.avatar
        )
        let image = CardExporter.render(
            design: PlayerCardStore.shared.design,
            photo: profile.avatarPhoto,
            player: info
        )
        guard let image else { return [fallbackText] }
        return [image]
    }
}
