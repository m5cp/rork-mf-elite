//
//  FloatingSearchVisibility.swift
//  MFElite
//
//  Keeps the floating search button out of the way of pinned CTAs.
//
//  The magnifier in `MainTabView` sits at `DS.tabBarClearance + 12` on the
//  trailing edge — exactly the band a few screens reserve for their own
//  full-width pinned button ("Start drill", "Start test"). Those screens push
//  on top of a tab, so the overlay would land on the right end of their CTA.
//
//  Rather than guess an offset, the screens that pin something declare it, and
//  the button steps aside while they are up. A registry of live tokens is used
//  instead of a preference key because SwiftUI does not reliably propagate
//  custom preferences out of a pushed `NavigationStack` destination to an
//  ancestor, and a Set rather than a counter so a duplicated or out-of-order
//  `onAppear` during a push can't drive the count negative.
//
//  A Set does *not* protect against a dropped `onDisappear` — a leaked token
//  would hide the button for the rest of the session, and the button is the
//  only way into global search. `MainTabView` therefore calls `releaseAll()`
//  whenever the tab changes, which is exactly when SwiftUI tears down the
//  outgoing tab's whole navigation stack and the risk exists.
//

import Foundation
import Observation
import SwiftUI

@Observable
@MainActor
final class FloatingSearchVisibility {
    static let shared = FloatingSearchVisibility()

    /// One token per on-screen view asking the button to stand down.
    private var suppressors: Set<UUID> = []

    /// True when nothing on screen has claimed the bottom-trailing corner.
    var isVisible: Bool { suppressors.isEmpty }

    func suppress(_ id: UUID) { suppressors.insert(id) }
    func release(_ id: UUID) { suppressors.remove(id) }

    /// Recovery hatch. Switching tabs destroys the outgoing tab's stack, so
    /// nothing that was suppressing can still be on screen — any token still
    /// held at that point leaked and would hide the button permanently.
    func releaseAll() { suppressors.removeAll() }

    private init() {}
}

private struct SuppressesFloatingSearch: ViewModifier {
    /// One identity per view instance, stable across body re-evaluations.
    @State private var token = UUID()

    func body(content: Content) -> some View {
        content
            .onAppear { FloatingSearchVisibility.shared.suppress(token) }
            .onDisappear { FloatingSearchVisibility.shared.release(token) }
    }
}

extension View {
    /// Hides the app-wide floating search button while this screen is on
    /// screen. Use it on any screen that pins its own control above the tab
    /// bar, so the two don't stack on top of each other.
    func suppressesFloatingSearch() -> some View {
        modifier(SuppressesFloatingSearch())
    }
}
