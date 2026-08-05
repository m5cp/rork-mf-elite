//
//  ShareXPBanner.swift
//  MFElite
//
//  The one "+5 XP per platform" note.
//
//  It used to exist twice, differently: the gallery drew an 11.5pt
//  left-aligned pill on an accent wash, the editor an 11pt centered label with
//  no background. Worse, the gallery version promised XP on a screen where
//  seven of the nine cards earn nothing — only the Player Card and Rep The
//  Badge are eligible (see `ShareXPService.isEligible`).
//
//  This states which cards earn it, and reads its numbers from the service so
//  the copy can't drift from the rules.
//

import SwiftUI

struct ShareXPBanner: View {
    /// When set, the banner describes only this card and hides itself entirely
    /// for cards that earn nothing. When nil (the gallery), it names the two
    /// eligible cards instead of implying every card pays out.
    var kind: ShareMomentKind?

    private var isHidden: Bool {
        guard let kind else { return false }
        return !ShareXPService.isEligible(kind)
    }

    private var message: String {
        let xp = ShareXPService.xpPerShare
        if kind != nil {
            return "+\(xp) XP per platform — first share on each app, daily."
        }
        return "+\(xp) XP per platform when you share your Player Card or Rep The Badge — first share on each app, daily."
    }

    var body: some View {
        if !isHidden {
            Label(message, systemImage: "bolt.fill")
                .style(.cap)
                .foregroundStyle(DS.Colors.Gold.textLight)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, DS.Spacing.s12)
                .padding(.vertical, DS.Spacing.s8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    DS.Colors.Gold.faint,
                    in: RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                )
                .accessibilityLabel(message)
        }
    }
}

#Preview {
    ZStack {
        DS.Colors.Bg.base.ignoresSafeArea()
        VStack(spacing: DS.Spacing.s16) {
            ShareXPBanner()
            ShareXPBanner(kind: .playerCard)
            ShareXPBanner(kind: .streak) // hidden — earns nothing
        }
        .padding()
    }
}
