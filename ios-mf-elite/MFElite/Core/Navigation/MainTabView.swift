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
        case .train:    TrainView()
        case .hub:      AcademyHubView()
        case .progress: ProgressTabView()
        case .profile:  ProfileTabView()
        case .coach:    CoachView()
        }
    }
}

#Preview {
    MainTabView()
        .preferredColorScheme(.dark)
}
