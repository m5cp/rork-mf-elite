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
    @State private var importPayload: WorkoutShare.Payload?
    @State private var dismissedStoreWarning = false

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
