//
//  LockedContentView.swift
//  MFElite
//
//  A small overlay for locked premium content + a reusable gating modifier.
//

import SwiftUI

/// A semi-transparent lock overlay placed on top of gated content.
struct LockedContentView: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .fill(Color.black.opacity(0.45))

            HStack(spacing: DS.Spacing.s4 + 2) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 11, weight: .bold))
                Text("ELITE")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .tracking(0.8)
            }
            .foregroundStyle(DS.Colors.Ground.primary)
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.pill))
        }
        .allowsHitTesting(false)
    }
}

/// A small circular lock badge for the corner of a locked card. Disappears when
/// the gating condition is false, so it vanishes the moment a player subscribes.
struct LockBadge: View {
    var body: some View {
        Image(systemName: "lock.fill")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(DS.Colors.Ground.primary)
            .padding(7)
            .background(Color.white)
            .clipShape(Circle())
            .allowsHitTesting(false)
    }
}

/// Dims gated content and routes taps to the paywall when locked.
private struct GatedContentModifier: ViewModifier {
    let isLocked: Bool
    @Environment(SubscriptionService.self) private var subscription

    func body(content: Content) -> some View {
        if isLocked {
            content
                .opacity(0.55)
                .overlay { LockedContentView() }
                .contentShape(Rectangle())
                .onTapGesture { subscription.presentPaywall() }
        } else {
            content
        }
    }
}

extension View {
    /// Gate a view behind the elite paywall. When locked, content is dimmed,
    /// a lock overlay appears, and a tap presents the paywall.
    func gated(isLocked: Bool) -> some View {
        modifier(GatedContentModifier(isLocked: isLocked))
    }
}

#Preview {
    ZStack {
        DS.Colors.Bg.base.ignoresSafeArea()
        Card {
            Text("Premium drill")
                .style(.title3)
                .foregroundStyle(DS.Colors.Ink.primary)
        }
        .frame(height: 120)
        .overlay { LockedContentView() }
        .padding()
    }
}
