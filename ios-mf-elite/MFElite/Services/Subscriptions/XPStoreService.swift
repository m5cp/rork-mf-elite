//
//  XPStoreService.swift
//  MFElite
//
//  StoreKit 2 consumables: XP packs (dual-ledger — purchased XP counts toward
//  rank only), streak freezes (capped at 3), and the 2x weekend booster
//  (multiplies EARNED XP for 48h — it rewards more training, never replaces it).
//

import Foundation
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
    /// Hard ceiling on purchased XP per calendar month (economy guardrail).
    static let monthlyXPCap = 2000
    private static let boosterKey = "MF_BOOSTER_UNTIL"
    private static let monthlyXPKey = "MF_PURCHASED_XP_MONTH" // "yyyy-MM|total"

    private(set) var products: [Product] = []
    private(set) var lastError: String?
    private var context: ModelContext?

    func configure(context: ModelContext) {
        self.context = context
        Task { await loadProducts() }
        Task { await listenForTransactions() }
    }

    func loadProducts() async {
        do {
            products = try await Product.products(for: ProductID.allCases.map(\.rawValue))
                .sorted { $0.price < $1.price }
        } catch {
            lastError = "Store unavailable right now."
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

    /// Purchase and grant. Returns true on success. XP packs are refused when
    /// they would exceed the monthly purchased-XP cap.
    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        lastError = nil
        if let productID = ProductID(rawValue: product.id), productID.xpAmount > 0,
           productID.xpAmount > monthlyXPRemaining {
            lastError = "Monthly XP purchase limit reached (\(Self.monthlyXPCap) XP). Resets next month — keep training to earn more."
            return false
        }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    lastError = "Purchase could not be verified."
                    return false
                }
                grant(productID: transaction.productID, storeTransactionID: String(transaction.id))
                await transaction.finish()
                return true
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            lastError = "Purchase failed. You were not charged."
            return false
        }
    }

    /// Grant entitlement for a verified transaction.
    private func grant(productID: String, storeTransactionID: String?) {
        guard let context,
              let player = try? context.fetch(FetchDescriptor<PlayerState>()).first,
              let product = ProductID(rawValue: productID) else { return }

        switch product {
        case .xp100, .xp300, .xp750:
            player.purchasedXP += product.xpAmount
            recordMonthlyXP(product.xpAmount)
        case .streakFreeze:
            player.freezesRemaining = min(Self.maxFreezes, player.freezesRemaining + 1)
        case .booster48h:
            let until = max(Date().timeIntervalSince1970,
                            UserDefaults.standard.double(forKey: Self.boosterKey))
                + 48 * 3600
            UserDefaults.standard.set(until, forKey: Self.boosterKey)
        }
        try? context.save()
        SyncEngine.shared.enqueuePlayerState(player)
        SyncEngine.shared.enqueueXPTransaction(
            id: UUID(), productID: productID,
            xpAmount: product.xpAmount, storeTransactionID: storeTransactionID
        )
    }

    /// Handle transactions that complete outside the purchase flow
    /// (interrupted purchases, Ask to Buy approvals).
    private func listenForTransactions() async {
        for await update in Transaction.updates {
            guard case .verified(let transaction) = update else { continue }
            grant(productID: transaction.productID, storeTransactionID: String(transaction.id))
            await transaction.finish()
        }
    }
}
