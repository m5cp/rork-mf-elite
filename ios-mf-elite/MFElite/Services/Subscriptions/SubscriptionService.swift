//
//  SubscriptionService.swift
//  MFElite
//
//  RevenueCat-backed subscription state + paywall presentation coordinator.
//

import Foundation
import Observation
import RevenueCat

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
            isElite = info.entitlements[entitlementID]?.isActive == true
        }
    }

    // MARK: - Status / offerings

    func checkSubscriptionStatus() async {
        do {
            let info = try await Purchases.shared.customerInfo()
            isElite = info.entitlements[entitlementID]?.isActive == true
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

    // MARK: - Purchase / restore

    func purchase(package: Package) async {
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let result = try await Purchases.shared.purchase(package: package)
            if !result.userCancelled {
                let active = result.customerInfo.entitlements[entitlementID]?.isActive == true
                isElite = active
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
            let active = info.entitlements[entitlementID]?.isActive == true
            isElite = active
            if active { showPaywall = false }
        } catch {
            self.error = error.localizedDescription
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
