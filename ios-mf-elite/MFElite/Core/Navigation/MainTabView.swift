//
//  MainTabView.swift
//  MFElite
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: AppTab = .today
    @State private var subscription = SubscriptionService.shared
    @State private var router = AppActionRouter.shared
    @State private var importPayload: WorkoutShare.Payload?

    var body: some View {
        @Bindable var subscription = subscription
        return ZStack(alignment: .bottom) {
            DS.Colors.Bg.base.ignoresSafeArea()

            tabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .adaptiveContentWidth()

            CustomTabBar(selectedTab: $selectedTab)
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
        .fullScreenCover(isPresented: $subscription.showPaywall) {
            PaywallView()
                .environment(subscription)
        }
        .fullScreenCover(isPresented: $subscription.showPremiumWelcome) {
            PremiumWelcomeView()
        }
        .sheet(item: $importPayload) { payload in
            WorkoutImportView(payload: payload)
        }
        .onOpenURL { url in
            guard let payload = WorkoutShare.decode(url) else { return }
            importPayload = payload
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .today:    AcademyTodayView()
        case .hub:      AcademyHubView()
        case .progress: ProgressTabView()
        case .profile:  ProfileTabView()
        }
    }
}

#Preview {
    MainTabView()
        .preferredColorScheme(.dark)
}
