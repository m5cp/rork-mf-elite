//
//  MembershipView.swift
//  MFElite
//
//  Settings → Membership: see the current plan, switch weekly/monthly/annual
//  (the App Store handles proration and timing), jump to the MF Store, and
//  manage/cancel honestly via Apple's subscription sheet. No pressure: the
//  screen states plainly that progress is never taken away.
//

import SwiftUI
import RevenueCat

struct MembershipView: View {
    @Environment(SubscriptionService.self) private var subscription
    @Environment(\.dismiss) private var dismiss

    @State private var showStore = false
    @State private var showPurchaseHelp = false

    private var packages: [Package] {
        subscription.offerings?.current?.availablePackages ?? []
    }

    /// Packages other than the one currently active.
    private var switchTargets: [Package] {
        packages.filter { $0.storeProduct.productIdentifier != subscription.activeProductID }
    }

    private var currentPlanName: String {
        switch subscription.activePlanPeriod {
        case .annual: return "ELITE · ANNUAL"
        case .monthly: return "ELITE · MONTHLY"
        case .weekly: return "ELITE · WEEKLY"
        case .unknown: return subscription.isElite ? "ELITE" : "FREE · TRIALIST"
        }
    }

    private var renewalLine: String {
        guard subscription.isElite else {
            return "Training free within Level 1. Everything you earn is yours."
        }
        if let date = subscription.renewalDate {
            return "Renews \(date.formatted(date: .long, time: .omitted))"
        }
        return "Active subscription"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.s16) {
                    currentPlanCard

                    if subscription.isElite && !switchTargets.isEmpty {
                        sectionLabel("SWITCH PLAN — HANDLED BY THE APP STORE")
                        ForEach(switchTargets, id: \.identifier) { package in
                            switchRow(package)
                        }
                    }

                    if !subscription.isElite {
                        FloatingButton(label: "See Elite plans", hint: nil) {
                            dismiss()
                            subscription.presentPaywall()
                        }
                    }

                    sectionLabel("ONE-TIME BOOSTS")
                    navRow(title: "MF Store", detail: "XP packs · streak shields · 2x booster") {
                        showStore = true
                    }

                    if subscription.isElite {
                        sectionLabel("SUBSCRIPTION")
                        navRow(title: "Manage or cancel", detail: "Opens your App Store subscriptions") {
                            subscription.showManageSubscriptions()
                        }
                    }

                    Spacer(minLength: DS.Spacing.s24)

                    (Text("Cancel anytime. ")
                        + Text("Your XP, streak, badges and history are permanently yours").bold()
                        + Text(" — come back and your full rank restores instantly."))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .fixedSize(horizontal: false, vertical: true)

                    GhostButton(label: "Restore Purchases") {
                        Task { await subscription.restorePurchases() }
                    }
                    .frame(maxWidth: .infinity)

                    Button {
                        showPurchaseHelp = true
                    } label: {
                        Text("Purchase problem?")
                            .font(.system(size: 12, weight: .semibold))
                            .underline()
                            .foregroundStyle(DS.Colors.Ink.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .padding(.horizontal, DS.Spacing.s20)
                .padding(.top, DS.Spacing.s8)
                .padding(.bottom, DS.Spacing.s32)
            }
            .background(DS.Colors.Bg.base)
            .scrollIndicators(.hidden)
            .navigationTitle("Membership")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showStore) {
                NavigationStack { MFStoreView() }
            }
            .sheet(isPresented: $showPurchaseHelp) { PurchaseHelpView() }
        }
        .preferredColorScheme(.dark)
    }

    private var currentPlanCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("CURRENT PLAN")
                .font(.system(size: 9, weight: .heavy))
                .tracking(1.8)
                .foregroundStyle(DS.Colors.Gold.textLight)
            Text(currentPlanName)
                .style(.title2)
                .foregroundStyle(DS.Colors.Ink.primary)
            Text(renewalLine)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(DS.Colors.Ink.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.s16)
        .background(DS.Colors.Gold.soft, in: RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .stroke(DS.Colors.Gold.line, lineWidth: 1)
        )
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9.5, weight: .heavy))
            .tracking(1.8)
            .foregroundStyle(DS.Colors.Ink.quaternary)
            .padding(.top, DS.Spacing.s8)
    }

    private func switchRow(_ package: Package) -> some View {
        Button {
            Task { await subscription.purchase(package: package) }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(planTitle(for: package))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(DS.Colors.Ink.primary)
                    Text("Apple applies the switch to your subscription")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                }
                Spacer()
                Text(package.storeProduct.localizedPriceString)
                    .font(DS.Typography.num(size: 15))
                    .foregroundStyle(DS.Colors.Ink.primary)
            }
            .padding(14)
            .frame(minHeight: 44)
            .background(DS.Colors.Bg.raised, in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(subscription.isPurchasing)
    }

    private func planTitle(for package: Package) -> String {
        switch package.packageType {
        case .annual: return "Annual"
        case .monthly: return "Monthly"
        case .weekly: return "Weekly"
        default: return package.storeProduct.localizedTitle
        }
    }

    private func navRow(title: String, detail: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(DS.Colors.Ink.primary)
                    Text(detail)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DS.Colors.Ink.quaternary)
            }
            .padding(14)
            .frame(minHeight: 44)
            .background(DS.Colors.Bg.raised, in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
    }
}
