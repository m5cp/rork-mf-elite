//
//  MainTabView.swift
//  MFElite
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: AppTab = .today
    @State private var subscription = SubscriptionService.shared
    @State private var router = AppActionRouter.shared
    @State private var restore = SyncRestore.shared
    @State private var searchVisibility = FloatingSearchVisibility.shared
    @State private var importPayload: WorkoutShare.Payload?
    @State private var dismissedStoreWarning = false
    @State private var showSearch = false

    var body: some View {
        @Bindable var subscription = subscription
        return ZStack(alignment: .bottom) {
            DS.Colors.Bg.base.ignoresSafeArea()

            tabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .adaptiveContentWidth()

            CustomTabBar(selectedTab: $selectedTab, tabs: visibleTabs)
                .frame(maxWidth: AdaptiveLayout.maxContentWidth)
                .frame(maxWidth: .infinity)
        }
        // Overlay rather than a ZStack child: expanding the button itself to
        // fill the screen would make the whole screen tappable.
        .overlay(alignment: .bottomTrailing) {
            // Screens that pin their own full-width CTA in this band ask the
            // button to stand down — see `suppressesFloatingSearch()`.
            //
            // The animation is scoped to this Group rather than the whole
            // stack: attached outside the overlay it would spring every
            // animatable change in the entire tab tree on each push and pop.
            Group {
                if searchVisibility.isVisible {
                    searchButton
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(DS.Motion.standardSpring, value: searchVisibility.isVisible)
        }
        .overlay(alignment: .top) {
            if MFEliteApp.isRunningOnFallbackStore && !dismissedStoreWarning {
                fallbackStoreBanner
            }
        }
        .preferredColorScheme(.dark)
        .mfDynamicTypeClamp()
        .environment(subscription)
        .onChange(of: router.pendingTab) { _, tab in
            guard let tab else { return }
            withAnimation(DS.Motion.standardSpring) { selectedTab = tab }
            router.pendingTab = nil
        }
        .onChange(of: selectedTab) { _, _ in
            // Switching tabs destroys the outgoing tab's whole stack, so any
            // suppression token still held at this point leaked and would hide
            // the search button for the rest of the session.
            searchVisibility.releaseAll()
        }
        .onChange(of: subscription.isCoach) { _, isCoach in
            // If a coach signs out while on the Coach tab, fall back to Today.
            if !isCoach && selectedTab == .coach {
                withAnimation(DS.Motion.standardSpring) { selectedTab = .today }
            }
        }
        .fullScreenCover(isPresented: $subscription.showPaywall) {
            PaywallView()
                .environment(subscription)
        }
        .fullScreenCover(isPresented: $subscription.showPremiumWelcome) {
            PremiumWelcomeView()
        }
        .fullScreenCover(isPresented: $showSearch, onDismiss: {
            // Search pushes the same detail screens, which suppress the button
            // while they're up. Nothing behind this cover can still be
            // suppressing once it closes, so clear any token it left behind.
            searchVisibility.releaseAll()
        }) {
            GlobalSearchView()
                .environment(subscription)
        }
        .fullScreenCover(item: restorePresentation) { item in
            RestoreProgressView(remote: item.state)
        }
        .sheet(item: $importPayload) { payload in
            WorkoutImportView(payload: payload)
        }
        .onOpenURL { url in
            guard let payload = WorkoutShare.decode(url) else { return }
            importPayload = payload
        }
    }

    /// Floating search, sitting just above the tab bar on the trailing side.
    ///
    /// Every list in the app was previously its own island — the curriculum
    /// search only found drills, and there was no way to find a *screen* at
    /// all. This finds drills, screens, badges and combine tests at once.
    private var searchButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            showSearch = true
        } label: {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(DS.Colors.Gold.inkOnGold)
                .frame(width: 52, height: 52)
                .background(DS.Colors.Gold.base)
                .clipShape(Circle())
                .overlay(
                    Circle().stroke(DS.Colors.Ground.primary.opacity(0.25), lineWidth: 1)
                )
                .floatingElevation()
                .contentShape(Circle())
        }
        .buttonStyle(PressableButtonStyle())
        .padding(.trailing, DS.Spacing.s20)
        .padding(.bottom, DS.tabBarClearance + DS.Spacing.s12)
        .accessibilityLabel("Search")
        .accessibilityHint("Find drills, screens and badges")
    }

    /// Shown when the on-disk store could not be opened and this session is
    /// running on a temporary in-memory one. Training logged now will not
    /// survive, and syncing is paused so the blank state can't overwrite the
    /// player's cloud data — so say so rather than losing their work quietly.
    private var fallbackStoreBanner: some View {
        HStack(alignment: .top, spacing: DS.Spacing.s8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13, weight: .bold))
            VStack(alignment: .leading, spacing: 2) {
                Text("Training won't be saved")
                    .font(.system(size: 13, weight: .bold))
                Text("MF Elite couldn't open your saved data. Restart the app before training — your history is still on this device.")
                    .font(.system(size: 11, weight: .medium))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: DS.Spacing.s8)
            Button {
                withAnimation(DS.Motion.standardSpring) { dismissedStoreWarning = true }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(DS.Colors.Ground.primary)
        .padding(DS.Spacing.s12)
        .background(Color(hex: "#E5A400"))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
        .padding(.horizontal, DS.Spacing.s16)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    /// Binds the restore prompt to the coordinator's pending remote state.
    private var restorePresentation: Binding<RemotePlayerStateItem?> {
        Binding(
            get: { restore.pending.map(RemotePlayerStateItem.init) },
            set: { if $0 == nil { restore.dismissPending() } }
        )
    }

    /// Tabs shown for the current role — players never see the Coach tab.
    private var visibleTabs: [AppTab] {
        AppTab.visible(isCoach: subscription.isCoach)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .today:    AcademyTodayView()
        case .hub:      AcademyHubView()
        case .progress: ProgressTabView()
        case .profile:  ProfileTabView()
        case .coach:    CoachLockGate { CoachView() }
        }
    }
}

#Preview {
    MainTabView()
        .preferredColorScheme(.dark)
}
