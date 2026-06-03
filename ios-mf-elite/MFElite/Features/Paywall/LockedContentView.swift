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

            VStack(spacing: DS.Spacing.s4 + 2) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(DS.Colors.Ink.primary)
                Text("Elite")
                    .style(.micro)
                    .foregroundStyle(DS.Colors.Ink.primary)
            }
        }
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
