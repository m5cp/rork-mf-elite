//
//  SubscriptionService.swift
//  MFElite
//
//  RevenueCat-backed subscription state + paywall presentation coordinator.
//

import Foundation
import Observation
import RevenueCat
import UIKit

/// The single source of truth for the player's "elite" entitlement and the
/// app-wide paywall presentation flags. Shared across every screen.
@Observable
@MainActor
final class SubscriptionService {
    static let shared = SubscriptionService()

    /// RevenueCat entitlement identifier configured in the dashboard.
    private let entitlementID = "elite"

    // MARK: - Subscription state

    var isElite: Bool = false
    /// Product identifier of the active elite subscription, if any.
    private(set) var activeProductID: String?
    /// Renewal/expiration date of the active entitlement, if any.
    private(set) var renewalDate: Date?
    /// True when the signed-in account is an authorized coach. Coaches get full,
    /// free access everywhere and never see a paywall. Set by `SupabaseAuth`.
    var isCoach: Bool = false
    /// Server-reported coach role ("head_coach" | "coach") from the
    /// `my_coach_role()` RPC, or nil when unknown. Set by `SupabaseAuth`.
    /// `isCoach` remains the boolean every gate uses — this is display-only.
    var coachRole: String? = nil
    var offerings: Offerings?
    var isLoading: Bool = false
    var isPurchasing: Bool = false
    var error: String?

    // MARK: - App-wide presentation flags

    /// When true, the root presents the paywall as a full-screen cover.
    var showPaywall: Bool = false
    /// When true, the root presents the post-purchase welcome cover.
    var showPremiumWelcome: Bool = false

    private var configured: Bool = false

    private init() {}

    // MARK: - Configuration

    /// Configure the RevenueCat SDK once, at launch, from the App `init()`.
    func configure() {
        guard !configured else { return }
        configured = true

        #if DEBUG
        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: Config.EXPO_PUBLIC_REVENUECAT_TEST_API_KEY)
        #else
        Purchases.configure(withAPIKey: Config.EXPO_PUBLIC_REVENUECAT_IOS_API_KEY)
        #endif

        Task { await listenForUpdates() }
        Task { await fetchOfferings() }
        Task { await checkSubscriptionStatus() }
    }

    private func listenForUpdates() async {
        for await info in Purchases.shared.customerInfoStream {
            applyCustomerInfo(info)
        }
    }

    /// Applies entitlement state from a RevenueCat `CustomerInfo` payload —
    /// the single place `isElite`, `activeProductID`, and `renewalDate` are set.
    private func applyCustomerInfo(_ info: CustomerInfo) {
        let entitlement = info.entitlements[entitlementID]
        let active = entitlement?.isActive == true
        isElite = active
        activeProductID = active ? entitlement?.productIdentifier : nil
        renewalDate = active ? entitlement?.expirationDate : nil
    }

    // MARK: - Status / offerings

    func checkSubscriptionStatus() async {
        do {
            let info = try await Purchases.shared.customerInfo()
            applyCustomerInfo(info)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func fetchOfferings() async {
        isLoading = true
        do {
            offerings = try await Purchases.shared.offerings()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Parental gate

    /// A parent-gate challenge that a host view (MainTabView) presents. The
    /// gate used to be applied per button in Settings, which meant the paywall
    /// CTA, the Membership plan switcher and the paywall's Restore button — all
    /// reachable by tapping any lock badge in the app — were never gated at
    /// all. Routing purchase entry points through the service closes that.
    struct GateRequest: Identifiable {
        let id = UUID()
        let title: String
        let action: () -> Void
    }

    var gateRequest: GateRequest?

    /// Run a parent-only action, challenging for the passcode when the gate is
    /// on. Calls straight through when it isn't.
    func withParentApproval(_ title: String, _ action: @escaping () -> Void) {
        let gate = ParentGate.shared
        if gate.isEnabled && gate.hasPIN {
            gateRequest = GateRequest(title: title, action: action)
        } else {
            action()
        }
    }

    /// Gated entry point for buying a subscription. Views should call this
    /// rather than `purchase(package:)` directly.
    func requestPurchase(package: Package) {
        withParentApproval("Unlock to subscribe") { [weak self] in
            Task { await self?.purchase(package: package) }
        }
    }

    /// Entry point for restoring purchases. Deliberately NOT behind the parent
    /// gate: App Review expects restore to be reachable, it costs nothing, and
    /// a passcode the parent has forgotten must never be able to strand a
    /// paying customer on a new device.
    func requestRestore() {
        Task { await restorePurchases() }
    }

    // MARK: - Purchase / restore

    func purchase(package: Package) async {
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let result = try await Purchases.shared.purchase(package: package)
            if !result.userCancelled {
                applyCustomerInfo(result.customerInfo)
                let active = isElite
                if active {
                    showPaywall = false
                    showPremiumWelcome = true
                }
            }
        } catch ErrorCode.purchaseCancelledError {
            // User cancelled — not an error.
        } catch ErrorCode.paymentPendingError {
            // Awaiting parental approval / extra auth — not a failure.
        } catch {
            self.error = error.localizedDescription
        }
    }

    func restorePurchases() async {
        do {
            let info = try await Purchases.shared.restorePurchases()
            applyCustomerInfo(info)
            if isElite { showPaywall = false }
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Plan info

    /// Billing period of the active plan, classified by matching the active
    /// product against the current offering's packages. Never hardcodes IDs.
    enum ActivePlanPeriod { case weekly, monthly, annual, unknown }

    var activePlanPeriod: ActivePlanPeriod {
        guard let pid = activeProductID,
              let packages = offerings?.current?.availablePackages else { return .unknown }
        switch packages.first(where: { $0.storeProduct.productIdentifier == pid })?.packageType {
        case .annual: return .annual
        case .monthly: return .monthly
        case .weekly: return .weekly
        default: return .unknown
        }
    }

    /// Present Apple's native manage-subscriptions sheet (change plan / cancel).
    /// Falls back to the App Store subscriptions URL if the sheet API fails.
    func showManageSubscriptions() {
        Task {
            do {
                try await Purchases.shared.showManageSubscriptions()
            } catch {
                if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                    _ = await UIApplication.shared.open(url)
                }
            }
        }
    }

    // MARK: - Gating helpers

    /// True when the user has full access to all content — via an active Elite
    /// subscription or because they are an authorized coach.
    var hasFullAccess: Bool {
        isElite || isCoach
    }

    /// A level is locked when it is beyond the free tier and the user lacks full access.
    func isLevelLocked(_ level: MasteryLevel) -> Bool {
        level.number > ProgressionRules.freeLevels && !hasFullAccess
    }

    /// True when a level number is locked for the current user.
    func isLevelNumberLocked(_ number: Int) -> Bool {
        number > ProgressionRules.freeLevels && !hasFullAccess
    }

    /// Number of drills that stay free inside a level of `total` drills. Roughly
    /// the first 40% are free (always at least one); full-access users get them all.
    func freeDrillCount(total: Int) -> Int {
        guard !hasFullAccess else { return total }
        guard total > 0 else { return 0 }
        return max(1, Int((Double(total) * 0.4).rounded()))
    }

    /// True when the drill at `index` (0-based, in display order) within a level of
    /// `total` drills is members-only. The first ~40% are free; the rest are locked
    /// unless the user has full access.
    func isDrillLocked(index: Int, total: Int) -> Bool {
        guard !hasFullAccess else { return false }
        return index >= freeDrillCount(total: total)
    }

    /// True when an academy rank (pathway level) is locked because it requires an
    /// active Elite subscription the user does not currently have. The final
    /// three ranks are members-only; XP is still earned and retained, but the
    /// rank itself only unlocks while subscribed.
    func isRankLocked(_ rank: AcademyRank) -> Bool {
        rank.requiresSubscription && !hasFullAccess
    }

    /// Present the paywall from anywhere in the app. No-op for users who already
    /// have full access, so they never see a purchase prompt.
    func presentPaywall() {
        guard !hasFullAccess else { return }
        showPaywall = true
    }
}
