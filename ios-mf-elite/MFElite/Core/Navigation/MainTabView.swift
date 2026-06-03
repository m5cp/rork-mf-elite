//
//  MainTabView.swift
//  MFElite
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: AppTab = .today
    @State private var subscription = SubscriptionService.shared

    var body: some View {
        @Bindable var subscription = subscription
        return ZStack(alignment: .bottom) {
            DS.Colors.Bg.base.ignoresSafeArea()

            tabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            CustomTabBar(selectedTab: $selectedTab)
        }
        .preferredColorScheme(.dark)
        .environment(subscription)
        .fullScreenCover(isPresented: $subscription.showPaywall) {
            PaywallView()
                .environment(subscription)
        }
        .fullScreenCover(isPresented: $subscription.showPremiumWelcome) {
            PremiumWelcomeView()
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
