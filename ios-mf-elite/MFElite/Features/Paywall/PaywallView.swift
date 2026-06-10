//
//  PaywallView.swift
//  MFElite
//
//  The primary conversion surface — feature comparison + pricing + subscribe.
//

import SwiftUI
import RevenueCat
import MessageUI

struct PaywallView: View {
    @Environment(SubscriptionService.self) private var subscription
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPackageID: String?
    @State private var mailRequest: MailRequest?
    @State private var showMailUnavailable = false

    private let supportEmail = "mf.elitetraining@gmail.com"

    private let features: [(label: String, free: Bool, elite: Bool)] = [
        ("4 disciplines, Level 1 drills", true, true),
        ("Train daily & track streaks", true, true),
        ("All 216 drills, every level", false, true),
        ("Full academy curriculum", false, true),
        ("Earn certifications & rank up", false, true),
        ("Streak freeze protection", false, true),
        ("Achievement badges", false, true),
        ("10 curated training routines", false, true),
    ]

    private var packages: [Package] {
        subscription.offerings?.current?.availablePackages ?? []
    }

    private var selectedPackage: Package? {
        packages.first { $0.identifier == selectedPackageID } ?? packages.first
    }

    var body: some View {
        ZStack(alignment: .top) {
            DS.Colors.Bg.base.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    if packages.isEmpty { pricingPreview }
                    savingsCallout
                    comparison
                    pricing
                    subscribeCTA
                    legalFooter
                }
                .padding(.bottom, 48)
            }
            .scrollIndicators(.hidden)

            closeButton
        }
        .onAppear {
            if selectedPackageID == nil {
                selectedPackageID = (packages.first { $0.packageType == .annual } ?? packages.first)?.identifier
            }
        }
        .alert("Something went wrong", isPresented: .init(
            get: { subscription.error != nil },
            set: { if !$0 { subscription.error = nil } }
        )) {
            Button("OK") { subscription.error = nil }
        } message: {
            Text(subscription.error ?? "")
        }
        .sheet(item: $mailRequest) { request in
            MailComposeView(request: request).ignoresSafeArea()
        }
        .alert("Email not set up", isPresented: $showMailUnavailable) {
            Button("Copy address") { UIPasteboard.general.string = supportEmail }
            Button("OK", role: .cancel) {}
        } message: {
            Text("Reach us at \(supportEmail)")
        }
    }

    private func contactSupport() {
        if MFMailComposeViewController.canSendMail() {
            mailRequest = MailRequest(
                recipient: supportEmail,
                subject: "MF Elite Support — Billing",
                body: MailRequest.supportBody()
            )
        } else {
            showMailUnavailable = true
        }
    }

    // MARK: - Close

    private var closeButton: some View {
        HStack {
            Spacer()
            IconButton(systemName: "xmark", size: 36) { dismiss() }
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s12)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: "MF Elite")
            Text("Go Elite.\nTrain like a pro.")
                .style(.hero)
                .foregroundStyle(DS.Colors.Ink.primary)
                .lineSpacing(-6)
                .padding(.top, DS.Spacing.s8)
            Text("You have access to Level 1. Go Elite to unlock all 216 drills, every level, certifications, achievement badges, and curated training routines.")
                .style(.body)
                .foregroundStyle(DS.Colors.Ink.secondary)
                .frame(maxWidth: 320, alignment: .leading)
                .padding(.top, DS.Spacing.s12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s48 + DS.Spacing.s4)
    }

    // MARK: - Pricing preview

    private var pricingPreview: some View {
        HStack(spacing: DS.Spacing.s16) {
            pricingChip(period: "YEAR", price: "$299.99", note: "Best value", highlight: true)
            pricingChip(period: "MONTH", price: "$39.99", note: "", highlight: false)
            pricingChip(period: "WEEK", price: "$12.99", note: "", highlight: false)
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s20)
    }

    private func pricingChip(period: String, price: String, note: String, highlight: Bool) -> some View {
        VStack(spacing: DS.Spacing.s4) {
            Text(period)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(highlight ? DS.Colors.Ground.primary : DS.Colors.Ink.tertiary)
            Text(price)
                .font(DS.Typography.num(size: 18))
                .tracking(-0.5)
                .foregroundStyle(highlight ? DS.Colors.Ground.primary : DS.Colors.Ink.primary)
            if !note.isEmpty {
                Text(note)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(highlight ? DS.Colors.Ground.secondary : DS.Colors.Ink.quaternary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.s12)
        .background(highlight ? Color.white : DS.Colors.Bg.card)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .stroke(highlight ? Color.white : DS.Colors.Line.hairline, lineWidth: highlight ? 2 : 1)
        )
    }

    private var savingsCallout: some View {
        Text("Annual saves over 60% vs monthly")
            .style(.foot)
            .foregroundStyle(DS.Colors.Ink.tertiary)
            .frame(maxWidth: .infinity)
            .padding(.top, DS.Spacing.s8)
            .padding(.horizontal, DS.Spacing.s20)
    }

    // MARK: - Feature comparison

    private var comparison: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Text("Free")
                    .style(.micro)
                    .foregroundStyle(DS.Colors.Ink.secondary)
                    .frame(width: 52)
                Text("Elite")
                    .style(.micro)
                    .foregroundStyle(DS.Colors.Ground.primary)
                    .frame(width: 52, height: 22)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xs))
            }
            .padding(.bottom, DS.Spacing.s8)

            ForEach(Array(features.enumerated()), id: \.offset) { _, feature in
                VStack(spacing: 0) {
                    Hairline()
                    HStack {
                        Text(feature.label)
                            .style(.callout)
                            .foregroundStyle(DS.Colors.Ink.primary)
                        Spacer()
                        marker(feature.free).frame(width: 52)
                        marker(feature.elite).frame(width: 52)
                    }
                    .padding(.vertical, DS.Spacing.s12 + 2)
                }
            }
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s24 + 4)
    }

    private func marker(_ included: Bool) -> some View {
        Image(systemName: included ? "checkmark" : "xmark")
            .font(.system(size: 14, weight: .heavy))
            .foregroundStyle(included ? DS.Colors.Ink.primary : Color.white.opacity(0.25))
    }

    // MARK: - Pricing

    @ViewBuilder
    private var pricing: some View {
        if packages.isEmpty {
            VStack(spacing: DS.Spacing.s12) {
                ProgressView()
                    .tint(DS.Colors.Ink.tertiary)
                Text("Loading plans…")
                    .style(.foot)
                    .foregroundStyle(DS.Colors.Ink.tertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, DS.Spacing.s32)
        } else {
            VStack(spacing: DS.Spacing.s12) {
                ForEach(packages, id: \.identifier) { package in
                    PricingCard(
                        package: package,
                        isSelected: selectedPackage?.identifier == package.identifier,
                        isBestValue: package.packageType == .annual
                    ) {
                        withAnimation(DS.Motion.standardSpring) {
                            selectedPackageID = package.identifier
                        }
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.top, DS.Spacing.s24 + 4)
        }
    }

    // MARK: - Subscribe

    private var subscribeCTA: some View {
        VStack(spacing: 0) {
            FloatingButton(
                label: subscription.isPurchasing ? "Processing…" : "Go Elite",
                hint: trialHint
            ) {
                guard let package = selectedPackage else { return }
                Task { await subscription.purchase(package: package) }
            }
            .disabled(subscription.isPurchasing || selectedPackage == nil)
            .opacity(subscription.isPurchasing ? 0.7 : 1)
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s24 + 4)
    }

    private var trialHint: String? {
        guard let intro = selectedPackage?.storeProduct.introductoryDiscount,
              intro.paymentMode == .freeTrial else { return nil }
        return "\(intro.subscriptionPeriod.value)-DAY FREE TRIAL"
    }

    // MARK: - Legal

    private var legalFooter: some View {
        VStack(spacing: DS.Spacing.s12) {
            Text(autoRenewalTerms)
                .style(.microSm)
                .foregroundStyle(DS.Colors.Ink.quaternary)
                .multilineTextAlignment(.center)

            HStack(spacing: DS.Spacing.s24) {
                GhostButton(label: "Restore Purchases") {
                    Task { await subscription.restorePurchases() }
                }
                GhostButton(label: "Redeem Code") {
                    Purchases.shared.presentCodeRedemptionSheet()
                }
            }

            GhostButton(label: "Having trouble? Contact support") {
                contactSupport()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s16)
    }

    /// Auto-renewal terms built from the selected package's live RevenueCat pricing.
    private var autoRenewalTerms: String {
        guard let package = selectedPackage else {
            return "Plans start at $299.99/year (best value), $39.99/month, or $12.99/week. Payment is charged to your Apple ID at confirmation of purchase. Subscription automatically renews unless canceled at least 24 hours before the end of the current period. Manage or cancel anytime in your App Store account settings."
        }
        let price = package.storeProduct.localizedPriceString
        let period = periodWord(for: package)
        return "Payment of \(price) will be charged to your Apple ID account at confirmation of purchase. Subscription automatically renews at \(price)/\(period) unless canceled at least 24 hours before the end of the current period. Manage or cancel anytime in your App Store account settings. See Terms & Privacy Policy."
    }

    private func periodWord(for package: Package) -> String {
        switch package.packageType {
        case .weekly: return "week"
        case .monthly: return "month"
        case .annual: return "year"
        case .twoMonth: return "2 months"
        case .threeMonth: return "3 months"
        case .sixMonth: return "6 months"
        default: return "period"
        }
    }
}

// MARK: - PricingCard

private struct PricingCard: View {
    let package: Package
    let isSelected: Bool
    let isBestValue: Bool
    let action: () -> Void

    private var product: StoreProduct { package.storeProduct }

    private var periodLabel: String {
        switch package.packageType {
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .annual: return "Annual"
        case .twoMonth: return "2 Months"
        case .threeMonth: return "3 Months"
        case .sixMonth: return "6 Months"
        case .lifetime: return "Lifetime"
        default: return product.localizedTitle
        }
    }

    private var perPeriod: String {
        switch package.packageType {
        case .weekly: return "per week"
        case .monthly: return "per month"
        case .annual: return "per year"
        default: return "one-time"
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: DS.Spacing.s12) {
                VStack(alignment: .leading, spacing: DS.Spacing.s4) {
                    HStack(spacing: DS.Spacing.s8) {
                        Text(periodLabel)
                            .style(.title3)
                            .foregroundStyle(isSelected ? DS.Colors.Ground.primary : DS.Colors.Ink.primary)
                        if isBestValue {
                            Text("Best Value")
                                .style(.microSm)
                                .foregroundStyle(isSelected ? Color.white : DS.Colors.Ground.primary)
                                .padding(.vertical, 3)
                                .padding(.horizontal, 7)
                                .background(isSelected ? DS.Colors.Ground.primary : Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.pill))
                        }
                    }
                    Text(perPeriod)
                        .style(.foot)
                        .foregroundStyle(isSelected ? DS.Colors.Ground.secondary : DS.Colors.Ink.tertiary)
                }

                Spacer(minLength: DS.Spacing.s8)

                Text(product.localizedPriceString)
                    .font(DS.Typography.num(size: 24))
                    .tracking(-1)
                    .foregroundStyle(isSelected ? DS.Colors.Ground.primary : DS.Colors.Ink.primary)
            }
            .padding(DS.Spacing.s16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Color.white : DS.Colors.Bg.card)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .stroke(isSelected ? Color.white : DS.Colors.Line.hairline, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(PressableButtonStyle())
    }
}
