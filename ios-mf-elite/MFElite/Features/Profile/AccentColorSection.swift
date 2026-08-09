//
// AccentColorSection.swift
// MFElite
//
// Settings row group: pick the app accent color. Swatches update the whole
// app live (the root re-renders on PlayerProfileStore.accentID).
//

import SwiftUI

struct AccentColorSection: View {
    @State private var profile = PlayerProfileStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s12) {
            SectionHead(title: "Accent color")

            HStack(spacing: DS.Spacing.s16) {
                ForEach(AppAccent.allCases) { accent in
                    swatch(accent)
                }
                Spacer(minLength: 0)
            }

            Text("Icons, rings, and highlights across the app use your accent. Share cards keep their own theme picker.")
                .style(.micro)
                .foregroundStyle(DS.Colors.Ink.quaternary)
                .fixedSize(horizontal: false, vertical: true)

            Hairline()
                .padding(.vertical, DS.Spacing.s8)

            symbolStylePicker

            Hairline()
                .padding(.vertical, DS.Spacing.s8)

            ringStylePicker
        }
    }

    /// Third axis: the daily rings. Separate from icons because the rings are
    /// the one place three values have to stay distinguishable at a glance,
    /// so "gold icons, neutral rings" is a reasonable thing to want.
    private var ringStylePicker: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s8) {
            SectionHead(title: "Training rings")

            HStack(spacing: DS.Spacing.s8) {
                ForEach(RingStyle.allCases) { style in
                    ringOption(style)
                }
            }

            Text(currentRingStyle.detail)
                .style(.micro)
                .foregroundStyle(DS.Colors.Ink.quaternary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var currentRingStyle: RingStyle {
        RingStyle(rawValue: profile.ringStyleID) ?? .accent
    }

    private func ringOption(_ style: RingStyle) -> some View {
        let isSelected = currentRingStyle == style
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            profile.ringStyleID = style.rawValue
        } label: {
            HStack(spacing: DS.Spacing.s8) {
                Image(systemName: style == .accent ? "circle.circle.fill" : "circle.circle")
                    .font(.system(size: 13, weight: .bold))
                Text(style.displayName)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(isSelected ? DS.Colors.Ground.primary : DS.Colors.Ink.secondary)
            .padding(.vertical, DS.Spacing.s8 + 2)
            .padding(.horizontal, DS.Spacing.s16)
            .frame(maxWidth: .infinity)
            .background(isSelected ? Color.white : DS.Colors.Bg.raised)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(DS.Colors.Line.hairline, lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel("\(style.displayName) rings")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    /// Second axis: whether symbols and avatars pick the accent up at all.
    /// Some players want a gold app; some want black-and-white with the accent
    /// reserved for progress and selection.
    private var symbolStylePicker: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s8) {
            SectionHead(title: "Icons & avatars")

            HStack(spacing: DS.Spacing.s8) {
                ForEach(SymbolStyle.allCases) { style in
                    styleOption(style)
                }
            }

            Text(currentSymbolStyle.detail)
                .style(.micro)
                .foregroundStyle(DS.Colors.Ink.quaternary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var currentSymbolStyle: SymbolStyle {
        SymbolStyle(rawValue: profile.symbolStyleID) ?? .accent
    }

    private func styleOption(_ style: SymbolStyle) -> some View {
        let isSelected = currentSymbolStyle == style
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            profile.symbolStyleID = style.rawValue
        } label: {
            HStack(spacing: DS.Spacing.s8) {
                Image(systemName: style == .accent ? "seal.fill" : "circle.righthalf.filled")
                    .font(.system(size: 13, weight: .bold))
                Text(style.displayName)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(isSelected ? DS.Colors.Ground.primary : DS.Colors.Ink.secondary)
            .padding(.vertical, DS.Spacing.s8 + 2)
            .padding(.horizontal, DS.Spacing.s16)
            .frame(maxWidth: .infinity)
            .background(isSelected ? Color.white : DS.Colors.Bg.raised)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(DS.Colors.Line.hairline, lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel("\(style.displayName) icons")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func swatch(_ accent: AppAccent) -> some View {
        let isSelected = profile.accentID == accent.rawValue
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            profile.accentID = accent.rawValue
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(accent.base)
                        .frame(width: 34, height: 34)
                    if isSelected {
                        Circle()
                            .stroke(accent.textLight, lineWidth: 2)
                            .frame(width: 44, height: 44)
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(accent.inkOnAccent)
                    }
                }
                .frame(width: 46, height: 46)
                Text(accent.displayName.uppercased())
                    .font(.system(size: 10.5, weight: .semibold))
                    .tracking(0.4)
                    .foregroundStyle(isSelected ? DS.Colors.Ink.primary : DS.Colors.Ink.quaternary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel("\(accent.displayName) accent color")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
