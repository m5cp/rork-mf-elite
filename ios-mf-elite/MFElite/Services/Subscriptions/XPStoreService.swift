//
//  XPStoreService.swift
//  MFElite
//
//  RevenueCat-backed consumables: XP packs (dual-ledger — purchased XP counts
//  toward rank only), streak freezes (capped at 3), and the 2x weekend booster
//  (multiplies EARNED XP for 48h — it rewards more training, never replaces it).
//
//  Payments and reporting flow through RevenueCat (same pipeline as the elite
//  subscription), so every sale lands in one dashboard. Reward-granting stays
//  in-app, because these are one-time consumables RevenueCat cannot auto-unlock.
//

import Foundation
import RevenueCat
import StoreKit
import SwiftData

@MainActor
@Observable
final class XPStoreService {
    static let shared = XPStoreService()
    private init() {}

    enum ProductID: String, CaseIterable {
        case xp100 = "com.mfelite.xp.100"
        case xp300 = "com.mfelite.xp.300"
        case xp750 = "com.mfelite.xp.750"
        case streakFreeze = "com.mfelite.streakfreeze"
        case booster48h = "com.mfelite.booster.48h"

        var xpAmount: Int {
            switch self {
            case .xp100: return 100
            case .xp300: return 300
            case .xp750: return 750
            default: return 0
            }
        }
    }

    static let maxFreezes = 3
    /// XP credited instead when a purchased streak freeze would exceed
    /// `maxFreezes`, so a paid shield is never silently dropped.
    static let freezeConsolationXP = 100
    /// Hard ceiling on purchased XP per calendar month (economy guardrail).
    static let monthlyXPCap = 2000
    /// Booster purchases allowed per calendar month.
    static let boosterMonthlyCap = 6
    /// Shield purchases allowed per calendar month = days in that month.
    static var shieldMonthlyCap: Int {
        Calendar.current.range(of: .day, in: .month, for: Date())?.count ?? 30
    }
    private static let boosterKey = "MF_BOOSTER_UNTIL"
    private static let monthlyXPKey = "MF_PURCHASED_XP_MONTH" // "yyyy-MM|total"
    private static let monthlyShieldKey = "MF_SHIELDS_MONTH" // "yyyy-MM|count"
    private static let monthlyBoosterKey = "MF_BOOSTER_MONTH" // "yyyy-MM|count"
    private static let processedKey = "MF_PROCESSED_TX" // idempotency guard
    /// Purchases that were paid for but could not be credited yet, stored as
    /// "productID|transactionID" so they can be retried on a later launch.
    private static let pendingGrantsKey = "MF_PENDING_GRANTS"

    private(set) var products: [StoreProduct] = []
    private(set) var lastError: String?
    private var context: ModelContext?

    func configure(context: ModelContext) {
        self.context = context
        retryPendingGrants()
        Task { await loadProducts() }
        Task { await listenForTransactions() }
    }

    // MARK: - Deferred grants

    /// Retry purchases that were charged but couldn't be credited at the time —
    /// typically because `PlayerState` didn't exist yet (a fresh install where
    /// onboarding hasn't run, or a launch on the in-memory fallback store).
    ///
    /// RevenueCat finishes StoreKit transactions itself, so StoreKit will never
    /// re-deliver these to us. If the app doesn't remember them, nobody does,
    /// and the player is simply out the money.
    private func retryPendingGrants() {
        let pending = UserDefaults.standard.stringArray(forKey: Self.pendingGrantsKey) ?? []
        guard !pending.isEmpty else { return }
        var stillPending: [String] = []
        for entry in pending {
            let parts = entry.split(separator: "|", maxSplits: 1).map(String.init)
            guard let productID = parts.first else { continue }
            // An empty tail means the original had no transaction id; keep it
            // nil rather than storing "" in the processed-transactions set.
            let txID = (parts.count > 1 && !parts[1].isEmpty) ? parts[1] : nil
            if !grant(productID: productID, storeTransactionID: txID, recordOnFailure: false) {
                stillPending.append(entry)
            }
        }
        UserDefaults.standard.set(stillPending, forKey: Self.pendingGrantsKey)
    }

    /// Remember a paid-for grant that couldn't be applied, so the next launch
    /// can credit it.
    private func recordPendingGrant(productID: String, storeTransactionID: String?) {
        var pending = UserDefaults.standard.stringArray(forKey: Self.pendingGrantsKey) ?? []
        let entry = "\(productID)|\(storeTransactionID ?? "")"
        guard !pending.contains(entry) else { return }
        pending.append(entry)
        UserDefaults.standard.set(pending, forKey: Self.pendingGrantsKey)
    }

    func loadProducts() async {
        let fetched = await Purchases.shared.products(ProductID.allCases.map(\.rawValue))
        if fetched.isEmpty {
            lastError = "Store unavailable right now."
        } else {
            products = fetched.sorted { $0.price < $1.price }
        }
    }

    /// Active earned-XP multiplier (2 while the weekend booster runs, else 1).
    var earnMultiplier: Int {
        let until = UserDefaults.standard.double(forKey: Self.boosterKey)
        return Date().timeIntervalSince1970 < until ? 2 : 1
    }

    var boosterExpiry: Date? {
        let until = UserDefaults.standard.double(forKey: Self.boosterKey)
        return until > Date().timeIntervalSince1970 ? Date(timeIntervalSince1970: until) : nil
    }

    // MARK: - Monthly XP purchase cap

    /// Purchased XP so far this calendar month.
    var purchasedThisMonth: Int {
        let stored = UserDefaults.standard.string(forKey: Self.monthlyXPKey) ?? ""
        let parts = stored.split(separator: "|")
        guard parts.count == 2, String(parts[0]) == Self.monthToken() else { return 0 }
        return Int(parts[1]) ?? 0
    }

    /// XP still purchasable this month.
    var monthlyXPRemaining: Int { max(0, Self.monthlyXPCap - purchasedThisMonth) }

    private func recordMonthlyXP(_ amount: Int) {
        let total = purchasedThisMonth + amount
        UserDefaults.standard.set("\(Self.monthToken())|\(total)", forKey: Self.monthlyXPKey)
    }

    private static func monthToken() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: Date())
    }

    /// Generic month-scoped counter stored as "yyyy-MM|count".
    private func monthlyCount(forKey key: String) -> Int {
        let stored = UserDefaults.standard.string(forKey: key) ?? ""
        let parts = stored.split(separator: "|")
        guard parts.count == 2, String(parts[0]) == Self.monthToken() else { return 0 }
        return Int(parts[1]) ?? 0
    }

    private func bumpMonthlyCount(forKey key: String) {
        let total = monthlyCount(forKey: key) + 1
        UserDefaults.standard.set("\(Self.monthToken())|\(total)", forKey: key)
    }

    /// Streak shields bought this calendar month (cap: days in the month).
    var shieldsPurchasedThisMonth: Int { monthlyCount(forKey: Self.monthlyShieldKey) }
    /// Boosters bought this calendar month (cap: boosterMonthlyCap).
    var boostersPurchasedThisMonth: Int { monthlyCount(forKey: Self.monthlyBoosterKey) }

    /// Purchase and grant through RevenueCat. Returns true on success. XP packs
    /// are refused when they would exceed the monthly purchased-XP cap.
    @discardableResult
    func purchase(_ product: StoreProduct) async -> Bool {
        lastError = nil
        if let productID = ProductID(rawValue: product.productIdentifier), productID.xpAmount > 0,
           productID.xpAmount > monthlyXPRemaining {
            lastError = "Monthly XP purchase limit reached (\(Self.monthlyXPCap) XP). Resets next month — keep training to earn more."
            return false
        }
        if ProductID(rawValue: product.productIdentifier) == .streakFreeze,
           shieldsPurchasedThisMonth >= Self.shieldMonthlyCap {
            lastError = "Shield limit reached for this month (\(Self.shieldMonthlyCap)). Resets next month."
            return false
        }
        if ProductID(rawValue: product.productIdentifier) == .booster48h,
           boostersPurchasedThisMonth >= Self.boosterMonthlyCap {
            lastError = "Booster limit reached for this month (\(Self.boosterMonthlyCap)). Resets next month."
            return false
        }
        do {
            let result = try await Purchases.shared.purchase(product: product)
            if result.userCancelled { return false }
            let delivered = grant(productID: product.productIdentifier,
                                  storeTransactionID: result.transaction?.transactionIdentifier)
            if !delivered {
                // Charged but not creditable right now. It's saved to the
                // pending-grants list and applied on the next launch.
                lastError = "Purchase went through but couldn't be applied yet. It will be credited the next time you open the app."
            }
            return delivered
        } catch {
            lastError = "Purchase failed. You were not charged."
            return false
        }
    }

    /// Grant entitlement for a verified purchase. Idempotent per store
    /// transaction so the purchase flow and the recovery listener can never
    /// double-grant the same consumable.
    /// Returns true when the entitlement was actually delivered and recorded.
    /// Callers must not finish the StoreKit transaction on false — leaving it
    /// unfinished is what lets StoreKit re-deliver it and the player eventually
    /// receive what they paid for.
    @discardableResult
    private func grant(
        productID: String,
        storeTransactionID: String?,
        recordOnFailure: Bool = true
    ) -> Bool {
        // Check the idempotency record, but do NOT write it yet. Marking the
        // transaction processed before the grant actually landed meant that if
        // the PlayerState row wasn't there — a fresh install before onboarding
        // seeds it, or the in-memory fallback container — the guard below
        // returned, the goods were never delivered, and the recovery listener
        // skipped it forever. The player was charged and got nothing, with no
        // way to retry.
        if let txID = storeTransactionID,
           Set(UserDefaults.standard.stringArray(forKey: Self.processedKey) ?? []).contains(txID) {
            // Already delivered — safe to finish.
            return true
        }

        guard let product = ProductID(rawValue: productID) else { return false }

        guard let context,
              let player = try? context.fetch(FetchDescriptor<PlayerState>()).first else {
            // Paid for, but there is nowhere to put it yet. Remember it so a
            // later launch can credit it — nothing else will.
            if recordOnFailure {
                recordPendingGrant(productID: productID, storeTransactionID: storeTransactionID)
            }
            return false
        }

        // XP actually credited, which is not always `product.xpAmount` — an
        // over-cap streak freeze is paid out as XP instead.
        var grantedXP = product.xpAmount

        switch product {
        case .xp100, .xp300, .xp750:
            player.purchasedXP += product.xpAmount
            recordMonthlyXP(product.xpAmount)
        case .streakFreeze:
            if player.freezesRemaining >= Self.maxFreezes {
                // Already at the cap — don't silently swallow a paid shield.
                // Convert it to the equivalent XP so the purchase still lands,
                // and record it like any other purchased XP so it counts toward
                // the monthly cap and the server ledger agrees with the balance.
                player.purchasedXP += Self.freezeConsolationXP
                recordMonthlyXP(Self.freezeConsolationXP)
                grantedXP = Self.freezeConsolationXP
            } else {
                player.freezesRemaining += 1
            }
            bumpMonthlyCount(forKey: Self.monthlyShieldKey)
        case .booster48h:
            let until = max(Date().timeIntervalSince1970,
                            UserDefaults.standard.double(forKey: Self.boosterKey))
                + 48 * 3600
            UserDefaults.standard.set(until, forKey: Self.boosterKey)
            bumpMonthlyCount(forKey: Self.monthlyBoosterKey)
        }
        try? context.save()

        // Only now is the grant genuinely delivered, so only now is it safe to
        // record the transaction as processed.
        if let txID = storeTransactionID {
            var processed = Set(UserDefaults.standard.stringArray(forKey: Self.processedKey) ?? [])
            processed.insert(txID)
            UserDefaults.standard.set(Array(processed), forKey: Self.processedKey)
        }

        SyncEngine.shared.enqueuePlayerState(player)
        SyncEngine.shared.enqueueXPTransaction(
            id: UUID(), productID: productID,
            xpAmount: grantedXP, storeTransactionID: storeTransactionID
        )
        return true
    }

    /// Best-effort recovery for transactions that complete outside the purchase
    /// flow (interrupted purchases, Ask to Buy approvals). RevenueCat reports and
    /// finishes them; the idempotency guard in `grant` prevents double-grants.
    private func listenForTransactions() async {
        for await update in Transaction.updates {
            guard case .verified(let transaction) = update else { continue }
            // A failed grant is recorded to the pending list inside grant(),
            // so it is retried on the next launch. Finish either way: RevenueCat
            // owns finishing in its default mode, and leaving this unfinished
            // buys nothing.
            grant(productID: transaction.productID, storeTransactionID: String(transaction.id))
            await transaction.finish()
        }
    }
}
