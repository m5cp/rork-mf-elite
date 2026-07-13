//
//  CustomTabBar.swift
//  MFElite
//
//  A floating glass-style pill tab bar with custom-drawn icons.
//

import SwiftUI

struct CustomTabBar: View {
    @Binding var selectedTab: AppTab
    var tabs: [AppTab] = AppTab.allCases

    private let barHeight: CGFloat = 68
    private let cornerRadius: CGFloat = 34

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs) { tab in
                tabSlot(for: tab)
            }
        }
        .frame(height: barHeight)
        .background(glassSurface)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(innerEdges)
        .shadow(color: .black.opacity(0.55), radius: 56, y: 24)
        .shadow(color: .black.opacity(0.32), radius: 18, y: 6)
        .padding(.horizontal, 14)
        .padding(.bottom, 26)
    }

    // MARK: - Tab Slot

    private func tabSlot(for tab: AppTab) -> some View {
        let isActive = tab == selectedTab

        return Button {
            guard tab != selectedTab else { return }
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            withAnimation(DS.Motion.standardSpring) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: DS.Spacing.s4) {
                TabBarIcon(
                    tab: tab,
                    color: isActive ? DS.Colors.Gold.base : Color.white.opacity(0.62)
                )
                Text(tab.label)
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(isActive ? DS.Colors.Gold.textLight : Color.white.opacity(0.62))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .overlay(alignment: .top) {
                if isActive {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(DS.Colors.Gold.base)
                        .frame(width: 22, height: 2)
                        .padding(.top, 4)
                        .shadow(color: DS.Colors.Gold.base.opacity(0.70), radius: 6)
                }
            }
            .background(alignment: .center) {
                if isActive {
                    RadialGradient(
                        colors: [DS.Colors.Gold.base.opacity(0.20), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 46
                    )
                    .allowsHitTesting(false)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Glass Surface

    private var glassSurface: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
            LinearGradient(
                colors: [
                    Color(.sRGB, red: 46/255, green: 46/255, blue: 48/255, opacity: 0.42),
                    Color(.sRGB, red: 22/255, green: 22/255, blue: 24/255, opacity: 0.55)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    /// Inner specular shine + depth + side edges.
    private var innerEdges: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .stroke(Color.white.opacity(0.06), lineWidth: 1)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.white.opacity(0.22))
                    .frame(height: 1.5)
                    .blur(radius: 0.5)
                    .padding(.horizontal, cornerRadius * 0.5)
            }
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.black.opacity(0.34))
                    .frame(height: 1)
                    .padding(.horizontal, cornerRadius * 0.5)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .allowsHitTesting(false)
    }
}

#Preview {
    ZStack(alignment: .bottom) {
        DS.Colors.Bg.base.ignoresSafeArea()
        CustomTabBar(selectedTab: .constant(.today))
    }
}
