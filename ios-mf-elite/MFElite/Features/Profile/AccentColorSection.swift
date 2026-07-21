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
        }
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
                    .font(.system(size: 8.5, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(isSelected ? DS.Colors.Ink.primary : DS.Colors.Ink.quaternary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(PressableButtonStyle())
    }
}
