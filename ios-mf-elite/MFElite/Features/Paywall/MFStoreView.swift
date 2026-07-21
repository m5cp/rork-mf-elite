//
//  MFStoreView.swift
//  MFElite
//
//  The MF Store — StoreKit consumables in the app's dark style. XP packs speed
//  up academy rank (dual-ledger: purchased XP never reaches leaderboards),
//  streak protection, and the 48-hour 2x earned-XP booster. Purchases for
//  under-13 profiles are gated behind the parental passcode.
//

import SwiftUI
import SwiftData
import RevenueCat

/// Navigation route to the MF Store.
struct MFStoreRoute: Hashable {}

struct MFStoreView: View {
    @Query private var players: [PlayerState]
    @State private var store = XPStoreService.shared
    @State private var profile = PlayerProfileStore.shared
    @State private var gate = ParentGate.shared

    @State private var gateMode: ParentGateMode?
    @State private var pendingPurchase: StoreProduct?
    @State private var confirmation: String?
    @State private var isPurchasing = false

    private var freezes: Int { players.first?.freezesRemaining ?? 0 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                if let error = store.lastError {
                    errorBanner(error)
                }
                xpPacksSection
                streakSection
                boosterSection
                footer
            }
            .padding(.bottom, 120)
        }
        .background(DS.Colors.Bg.base)
        .scrollIndicators(.hidden)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .bottom) { confirmationToast }
        .sheet(item: $gateMode) { mode in
            ParentGateView(mode: mode)
                .presentationDetents([.large])
                .preferredColorScheme(.dark)
        }
        .onChange(of: gate.hasPIN) { _, hasPIN in
            guard hasPIN, let product = pendingPurchase else { return }
            pendingPurchase = nil
            Task { await runPurchase(product) }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s8) {
            Eyebrow(text: "MF Store")
            Text("Boost your grind")
                .style(.hero)
                .foregroundStyle(DS.Colors.Ink.primary)
            Text("XP packs speed up your academy rank. Leaderboards always show earned XP only.")
                .style(.foot)
                .foregroundStyle(DS.Colors.Ink.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s16)
    }

    // MARK: - XP packs

    private var xpPacksSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: "XP Packs")
                .padding(.bottom, DS.Spacing.s12)

            VStack(spacing: DS.Spacing.s12) {
                xpPackRow(.xp100, subtitle: "\u{2248} 1 day of training")
                xpPackRow(.xp300, subtitle: "\u{2248} 3 days")
                xpPackRow(.xp750, subtitle: "\u{2248} 1 week")
            }

            Text("Monthly limit: \(store.monthlyXPRemaining.formatted()) of 2,000 XP remaining")
                .style(.micro)
                .foregroundStyle(DS.Colors.Ink.quaternary)
                .padding(.top, DS.Spacing.s12)
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s32)
    }

    private func xpPackRow(_ id: XPStoreService.ProductID, subtitle: String) -> some View {
        Card {
            HStack(spacing: DS.Spacing.s12) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .metallicSymbol(.gold)
                    .frame(width: 40, height: 40)
                    .background(DS.Colors.Bg.raised)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(id.xpAmount.formatted()) XP")
                        .style(.title3)
                        .foregroundStyle(DS.Colors.Ink.primary)
                    Text(subtitle)
                        .style(.micro)
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                }

                Spacer(minLength: DS.Spacing.s8)

                buyButton(for: id)
            }
        }
    }

    // MARK: - Streak protection

    private var streakSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: "Streak Protection")
                .padding(.bottom, DS.Spacing.s12)

            Card {
                HStack(spacing: DS.Spacing.s12) {
                    Image(systemName: "snowflake")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color(hex: "#6FB7FF"))
                        .frame(width: 40, height: 40)
                        .background(DS.Colors.Bg.raised)
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Streak Freeze")
                            .style(.title3)
                            .foregroundStyle(DS.Colors.Ink.primary)
                        Text("If you miss a day, a freeze is used automatically and your streak survives. \(freezes) of \(XPStoreService.maxFreezes) held.")
                            .style(.micro)
                            .foregroundStyle(DS.Colors.Ink.tertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: DS.Spacing.s8)

                    if freezes >= XPStoreService.maxFreezes {
                        Text("Max")
                            .style(.foot)
                            .foregroundStyle(DS.Colors.Ink.quaternary)
                            .padding(.vertical, DS.Spacing.s12)
                            .padding(.horizontal, DS.Spacing.s16)
                            .overlay(Capsule().stroke(DS.Colors.Line.subtle, lineWidth: 1))
                    } else {
                        buyButton(for: .streakFreeze)
                    }
                }
            }
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s32)
    }

    // MARK: - Booster

    private var boosterSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: "48-Hour 2x Booster")
                .padding(.bottom, DS.Spacing.s12)

            Card {
                VStack(alignment: .leading, spacing: DS.Spacing.s12) {
                    HStack(spacing: DS.Spacing.s12) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color(hex: "#FF8A3D"))
                            .frame(width: 40, height: 40)
                            .background(DS.Colors.Bg.raised)
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text("2x XP Booster")
                                .style(.title3)
                                .foregroundStyle(DS.Colors.Ink.primary)
                            Text("Everything you EARN by training counts double for 48 hours.")
                                .style(.micro)
                                .foregroundStyle(DS.Colors.Ink.tertiary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: DS.Spacing.s8)

                        if store.boosterExpiry == nil {
                            buyButton(for: .booster48h)
                        }
                    }

                    if let expiry = store.boosterExpiry {
                        HStack(spacing: DS.Spacing.s8) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color(hex: "#FF8A3D"))
                            (Text("Active — ends ") + Text(expiry, style: .relative))
                                .style(.foot)
                                .foregroundStyle(DS.Colors.Ink.secondary)
                        }
                        .padding(.top, DS.Spacing.s4)
                    }
                }
            }
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s32)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s8) {
            Text("Purchases never affect leaderboards, drill mastery, or certifications.")
                .style(.micro)
                .foregroundStyle(DS.Colors.Ink.tertiary)
            Text("XP packs, freezes and boosters are one-time items, so there's nothing to restore — if a purchase is interrupted, it's granted automatically the next time you open the app.")
                .style(.micro)
                .foregroundStyle(DS.Colors.Ink.quaternary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s32)
    }

    // MARK: - Buy button

    @ViewBuilder
    private func buyButton(for id: XPStoreService.ProductID) -> some View {
        if let product = store.products.first(where: { $0.productIdentifier == id.rawValue }) {
            Button {
                attemptPurchase(product)
            } label: {
                Text(product.localizedPriceString)
                    .style(.foot)
                    .foregroundStyle(DS.Colors.Ground.primary)
                    .padding(.vertical, DS.Spacing.s12)
                    .padding(.horizontal, DS.Spacing.s20)
                    .background(Color.white)
                    .clipShape(Capsule())
                    .opacity(isPurchasing ? 0.5 : 1)
            }
            .buttonStyle(PressableButtonStyle())
            .disabled(isPurchasing)
        } else {
            ProgressView()
                .tint(DS.Colors.Ink.tertiary)
                .frame(width: 44, height: 44)
        }
    }

    private func errorBanner(_ message: String) -> some View {
        Text(message)
            .style(.foot)
            .foregroundStyle(Color(hex: "#FF5A5A"))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DS.Spacing.s12)
            .background(Color(hex: "#FF5A5A").opacity(0.1), in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.top, DS.Spacing.s16)
    }

    @ViewBuilder
    private var confirmationToast: some View {
        if let confirmation {
            Text(confirmation)
                .style(.foot)
                .foregroundStyle(DS.Colors.Ground.primary)
                .padding(.vertical, DS.Spacing.s12)
                .padding(.horizontal, DS.Spacing.s20)
                .background(Color.white, in: Capsule())
                .padding(.bottom, DS.Spacing.s32)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: - Purchase flow

    private func attemptPurchase(_ product: StoreProduct) {
        guard profile.isLikelyUnder13 else {
            Task { await runPurchase(product) }
            return
        }
        // Under-13 profiles require the parental gate first.
        pendingPurchase = product
        if gate.hasPIN {
            gateMode = .verify(title: "Parent approval") {
                if let pending = pendingPurchase {
                    pendingPurchase = nil
                    Task { await runPurchase(pending) }
                }
            }
        } else {
            // No passcode yet — a parent sets one, then the purchase continues.
            gateMode = .set
        }
    }

    private func runPurchase(_ product: StoreProduct) async {
        isPurchasing = true
        let success = await store.purchase(product)
        isPurchasing = false
        if success {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                confirmation = "Purchase complete!"
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation { confirmation = nil }
            }
        }
    }
}

#Preview {
    NavigationStack {
        MFStoreView()
            .preferredColorScheme(.dark)
            .modelContainer(for: [PlayerState.self])
    }
}
