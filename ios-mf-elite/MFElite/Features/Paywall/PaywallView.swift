//
//  PaywallView.swift
//  MFElite
//
//  The primary conversion surface, redesigned: photo-forward hero (real brand
//  assets), Ballon d'Or-led benefits, honest Free vs Elite comparison, 3-up
//  plan grid, and a reassuring no-pressure dismissal. Presented from ONE place
//  (MainTabView fullScreenCover) so every entry point shows this same view.
//

import SwiftUI
import RevenueCat

struct PaywallView: View {
    @Environment(SubscriptionService.self) private var subscription
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var selectedPackageID: String?
    @State private var showTierCompare = false
    @State private var showTerms = false
    @State private var showPrivacy = false

    private let supportEmail = "mf.elitetraining@gmail.com"

    // MARK: - Content

    private let bullets: [(icon: String, title: String, detail: String)] = [
        ("trophy.fill", "Ballon d'Or eligible",
         "Only Elite players can reach Captain — the rank that unlocks the invite-only Ballon d'Or."),
        ("soccerball", "All 216 drills · every level",
         "The complete curriculum with coach film, photos & certifications."),
        ("chart.line.uptrend.xyaxis", "Rise through every rank",
         "Prospect, First Eleven, Captain — with routines & programs built for each.")
    ]

    /// The honest, code-verified Free vs Elite comparison.
    /// free: nil = not included ("—"), "1" = limited, "check" = included.
    private let comparison: [(label: String, free: String?, elite: Bool)] = [
        ("Daily training, streaks & rings", "check", true),
        ("Level 1 drills — every category", "check", true),
        ("MF Combine tests + score history", "check", true),
        ("Apple Watch workouts & run tracker", "check", true),
        ("Share cards, player card & colors", "check", true),
        ("Custom workout builder", "1", true),
        ("Levels 2–5 · all 216 drills", nil, true),
        ("Curated routines & programs", nil, true),
        ("Ranks III–V + certifications", nil, true),
        ("Ballon d'Or eligibility", nil, true)
    ]

    // MARK: - Packages

    private var packages: [Package] {
        subscription.offerings?.current?.availablePackages ?? []
    }

    private var selectedPackage: Package? {
        packages.first { $0.identifier == selectedPackageID }
            ?? annualPackage
            ?? packages.first
    }

    private var annualPackage: Package? { packages.first { $0.packageType == .annual } }
    private var monthlyPackage: Package? { packages.first { $0.packageType == .monthly } }
    private var weeklyPackage: Package? { packages.first { $0.packageType == .weekly } }

    private var annualSavingsVsMonthlyPercent: Int? {
        guard let annual = annualPackage?.storeProduct.price,
              let monthly = monthlyPackage?.storeProduct.price,
              monthly > 0 else { return nil }
        let yearAtMonthly = monthly * 12
        guard yearAtMonthly > annual else { return nil }
        let pct = (yearAtMonthly - annual) / yearAtMonthly * 100
        return Int((pct as NSDecimalNumber).doubleValue.rounded())
    }

    private var annualPerMonthString: String? {
        guard let annual = annualPackage else { return nil }
        let perMonth = annual.storeProduct.price / 12
        if let formatter = annual.storeProduct.priceFormatter,
           let text = formatter.string(from: perMonth as NSDecimalNumber) {
            return "\(text) / mo"
        }
        return nil
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                hero
                VStack(alignment: .leading, spacing: DS.Spacing.s16) {
                    Text("Unlock the full academy")
                        .style(.title1)
                        .textCase(.uppercase)
                        .foregroundStyle(DS.Colors.Ink.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    bulletList
                    comparisonTable
                    planGrid
                    subscribeCTA
                    keepLine
                    legalFooter
                }
                .padding(.horizontal, DS.Spacing.s20)
                .padding(.top, DS.Spacing.s16)
                .padding(.bottom, DS.Spacing.s32)
            }
        }
        .background(DS.Colors.Bg.base)
        .scrollIndicators(.hidden)
        .ignoresSafeArea(edges: .top)
        .overlay(alignment: .topTrailing) { closeButton }
        .onAppear {
            if selectedPackageID == nil { selectedPackageID = annualPackage?.identifier }
        }
        .onChange(of: subscription.isElite) { _, isElite in
            if isElite { dismiss() }
        }
    }

    // MARK: - Hero (real brand assets; swap to training photo/film when available)

    private var hero: some View {
        ZStack(alignment: .bottomTrailing) {
            LinearGradient(
                colors: [Color(hex: "#161A13"), Color(hex: "#0B0E0A"), .black],
                startPoint: .top, endPoint: .bottom
            )
            RadialGradient(
                colors: [DS.Colors.Gold.base.opacity(0.28), .clear],
                center: .init(x: 0.72, y: 0.0), startRadius: 10, endRadius: 320
            )
            pitchLines.opacity(0.4)

            Image("SoccerBall")
                .resizable()
                .scaledToFit()
                .frame(width: 220)
                .offset(x: 44, y: 56)
                .shadow(color: .black.opacity(0.65), radius: 22, y: 12)

            LinearGradient(
                colors: [.black.opacity(0.15), .clear, .black.opacity(0.55), .black],
                startPoint: .top, endPoint: .bottom
            )
        }
        .frame(height: 250)
        .clipped()
        .overlay(alignment: .topLeading) {
            Image("mf-logo-white")
                .resizable()
                .scaledToFit()
                .frame(width: 52)
                .shadow(color: .black.opacity(0.6), radius: 6, y: 2)
                .padding(.leading, DS.Spacing.s20)
                .padding(.top, 58)
        }
    }

    private var pitchLines: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            Path { p in
                p.move(to: .init(x: -40, y: h)); p.addLine(to: .init(x: w * 0.42, y: h * 0.18))
                p.move(to: .init(x: w * 0.2, y: h)); p.addLine(to: .init(x: w * 0.55, y: h * 0.18))
                p.move(to: .init(x: w * 0.58, y: h)); p.addLine(to: .init(x: w * 0.68, y: h * 0.18))
                p.move(to: .init(x: w * 0.92, y: h)); p.addLine(to: .init(x: w * 0.82, y: h * 0.18))
                p.move(to: .init(x: 0, y: h * 0.60)); p.addLine(to: .init(x: w, y: h * 0.53))
                p.move(to: .init(x: 0, y: h * 0.83)); p.addLine(to: .init(x: w, y: h * 0.78))
            }
            .stroke(Color.white.opacity(0.14), lineWidth: 1.5)
        }
    }

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 44, height: 44)
                .background(.black.opacity(0.45), in: Circle())
        }
        .accessibilityLabel("Close")
        .padding(.trailing, DS.Spacing.s12)
        .padding(.top, 52)
    }

    // MARK: - Benefits

    private var bulletList: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s12) {
            ForEach(bullets, id: \.title) { bullet in
                HStack(alignment: .top, spacing: DS.Spacing.s12) {
                    Image(systemName: bullet.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DS.Colors.Gold.base)
                        .frame(width: 30, height: 30)
                        .background(
                            DS.Colors.Gold.soft,
                            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .stroke(DS.Colors.Gold.line, lineWidth: 1)
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(bullet.title)
                            .font(.system(size: 13.5, weight: .bold))
                            .foregroundStyle(DS.Colors.Ink.primary)
                        Text(bullet.detail)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(DS.Colors.Ink.tertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    // MARK: - Comparison

    private var comparisonTable: some View {
        VStack(spacing: 0) {
            HStack {
                Text("EVERYTHING IN THE APP")
                Spacer()
                Text("FREE").frame(width: 48)
                Text("ELITE").frame(width: 48).foregroundStyle(DS.Colors.Gold.textLight)
            }
            .font(.system(size: 9.5, weight: .heavy))
            .tracking(1.2)
            .foregroundStyle(DS.Colors.Ink.quaternary)
            .padding(.horizontal, DS.Spacing.s16)
            .padding(.vertical, DS.Spacing.s12)
            Hairline()

            ForEach(Array(comparison.enumerated()), id: \.offset) { index, row in
                HStack {
                    Text(row.label)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(DS.Colors.Ink.secondary)
                    Spacer()
                    freeMarker(row.free).frame(width: 48)
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(DS.Colors.Gold.base)
                        .frame(width: 48)
                }
                .padding(.horizontal, DS.Spacing.s16)
                .padding(.vertical, 9)
                if index < comparison.count - 1 { Hairline() }
            }
        }
        .background(DS.Colors.Bg.raised, in: RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .stroke(DS.Colors.Line.subtle, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func freeMarker(_ value: String?) -> some View {
        switch value {
        case "check":
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(DS.Colors.Gold.base)
        case .some(let text):
            Text(text)
                .font(.system(size: 10.5, weight: .bold))
                .foregroundStyle(DS.Colors.Ink.secondary)
        case nil:
            Text("—")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(DS.Colors.Ink.quaternary)
        }
    }

    // MARK: - Plans (3-up grid, annual centered + preselected; NO checkmark badge)

    private var planGrid: some View {
        Group {
            if packages.isEmpty {
                HStack(spacing: DS.Spacing.s12) {
                    ProgressView().tint(DS.Colors.Gold.base)
                    Text("Loading plans…")
                        .style(.foot)
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.s24)
            } else {
                HStack(spacing: 8) {
                    if let weekly = weeklyPackage { planCell(weekly, periodLabel: "WEEKLY", subLabel: perPeriodLabel(weekly)) }
                    if let annual = annualPackage {
                        planCell(annual, periodLabel: "12 MONTHS", subLabel: annualPerMonthString ?? perPeriodLabel(annual), emphasized: true)
                    }
                    if let monthly = monthlyPackage { planCell(monthly, periodLabel: "MONTHLY", subLabel: perPeriodLabel(monthly)) }
                }
                .padding(.top, DS.Spacing.s8)
            }
        }
    }

    private func perPeriodLabel(_ package: Package) -> String {
        "per \(periodWord(for: package))"
    }

    private func planCell(_ package: Package, periodLabel: String, subLabel: String, emphasized: Bool = false) -> some View {
        let isSelected = selectedPackage?.identifier == package.identifier
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            selectedPackageID = package.identifier
        } label: {
            VStack(spacing: 3) {
                Text(periodLabel)
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(1.3)
                    .foregroundStyle(isSelected ? DS.Colors.Gold.textLight : DS.Colors.Ink.quaternary)
                Text(package.storeProduct.localizedPriceString)
                    .font(DS.Typography.num(size: 20))
                    .foregroundStyle(DS.Colors.Ink.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(subLabel)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(isSelected ? DS.Colors.Gold.textLight : DS.Colors.Ink.tertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 74)
            .padding(.vertical, DS.Spacing.s12)
            .background(
                isSelected ? AnyShapeStyle(DS.Colors.Gold.soft) : AnyShapeStyle(DS.Colors.Bg.raised),
                in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .stroke(isSelected ? DS.Colors.Gold.base : DS.Colors.Line.subtle,
                            lineWidth: isSelected ? 1.5 : 1)
            )
            .overlay(alignment: .top) {
                if emphasized, let pct = annualSavingsVsMonthlyPercent {
                    Text("BEST VALUE · SAVE \(pct)%")
                        .font(.system(size: 8, weight: .heavy))
                        .tracking(0.8)
                        .foregroundStyle(DS.Colors.Gold.inkOnGold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(DS.Colors.Gold.base, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .offset(y: -9)
                        .lineLimit(1)
                        .fixedSize()
                }
            }
            .scaleEffect(emphasized ? 1.03 : 1)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel("\(periodLabel) plan, \(package.storeProduct.localizedPriceString)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - CTA + dismissal reassurance

    private var subscribeCTA: some View {
        FloatingButton(
            label: subscription.isPurchasing ? "Processing…" : "Start Elite",
            hint: trialHint
        ) {
            guard let package = selectedPackage else { return }
            Task { await subscription.purchase(package: package) }
        }
        .disabled(subscription.isPurchasing || selectedPackage == nil)
        .opacity(subscription.isPurchasing ? 0.7 : 1)
        .padding(.top, DS.Spacing.s8)
    }

    private var trialHint: String? {
        guard let intro = selectedPackage?.storeProduct.introductoryDiscount,
              intro.paymentMode == .freeTrial else { return nil }
        return "\(intro.subscriptionPeriod.value)-DAY FREE TRIAL"
    }

    private var keepLine: some View {
        (Text("Not ready? Train for free within Level 1 — ")
            + Text("everything you earn stays yours, always.").bold())
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(DS.Colors.Ink.tertiary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Legal

    private var legalFooter: some View {
        VStack(spacing: DS.Spacing.s12) {
            HStack(spacing: DS.Spacing.s20) {
                GhostButton(label: "Restore Purchases") {
                    Task { await subscription.restorePurchases() }
                }
                GhostButton(label: "Redeem Code") {
                    Purchases.shared.presentCodeRedemptionSheet()
                }
            }

            HStack(spacing: DS.Spacing.s20) {
                GhostButton(label: "Terms") { showTerms = true }
                GhostButton(label: "Privacy") { showPrivacy = true }
                GhostButton(label: "Support") {
                    if let url = URL(string: "mailto:\(supportEmail)") { openURL(url) }
                }
            }

            Button {
                showTierCompare = true
            } label: {
                Text("Compare plans")
                    .font(.system(size: 13, weight: .semibold))
                    .underline()
                    .foregroundStyle(DS.Colors.Ink.secondary)
            }
            .frame(minHeight: 44)

            Text(autoRenewalTerms)
                .style(.microSm)
                .foregroundStyle(DS.Colors.Ink.quaternary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, DS.Spacing.s8)
        .sheet(isPresented: $showTierCompare) { TierCompareView() }
        .sheet(isPresented: $showTerms) { NavigationStack { TermsOfUseView() } }
        .sheet(isPresented: $showPrivacy) { NavigationStack { PrivacyPolicyView() } }
    }

    /// Auto-renewal terms built from the selected package's live RevenueCat pricing.
    private var autoRenewalTerms: String {
        guard let package = selectedPackage else {
            return "Payment is charged to your Apple ID at confirmation of purchase. Subscription automatically renews unless canceled at least 24 hours before the end of the current period. Manage or cancel anytime in your App Store account settings."
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
