//
//  Buttons.swift
//  MFElite
//
//  All button variants: Primary, Floating, Secondary, Ghost, Icon.
//

import SwiftUI

enum ButtonSize {
    case large
    case medium
}

/// White pill CTA on dark background. Full width.
struct PrimaryButton: View {
    let label: String
    var hint: String? = nil
    var size: ButtonSize = .large
    let action: () -> Void

    private var height: CGFloat { size == .large ? 56 : 48 }

    var body: some View {
        Button(action: action) {
            ZStack {
                Text(label)
                    .font(.system(size: 17, weight: .bold))
                    .tracking(0.1)
                    .foregroundStyle(DS.Colors.Ground.primary)

                if let hint {
                    HStack {
                        Spacer()
                        Text(hint)
                            .style(.micro)
                            .foregroundStyle(Color.black.opacity(0.55))
                    }
                    .padding(.trailing, DS.Spacing.s20)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.pill))
            .pillLightElevation()
        }
        .buttonStyle(PressableButtonStyle())
    }
}

/// Identical to PrimaryButton but with heavier floating shadow. For sticky bottom CTAs.
struct FloatingButton: View {
    let label: String
    var hint: String? = nil
    var size: ButtonSize = .large
    let action: () -> Void

    private var height: CGFloat { size == .large ? 56 : 48 }

    var body: some View {
        Button(action: action) {
            ZStack {
                Text(label)
                    .font(.system(size: 17, weight: .bold))
                    .tracking(0.1)
                    .foregroundStyle(DS.Colors.Ground.primary)

                if let hint {
                    HStack {
                        Spacer()
                        Text(hint)
                            .style(.micro)
                            .foregroundStyle(Color.black.opacity(0.55))
                    }
                    .padding(.trailing, DS.Spacing.s20)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.pill))
            .floatingElevation()
        }
        .buttonStyle(PressableButtonStyle())
    }
}

/// Transparent background, white text, subtle border.
struct SecondaryButton: View {
    let label: String
    var size: ButtonSize = .large
    let action: () -> Void

    private var height: CGFloat { size == .large ? 50 : 44 }

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 15, weight: .semibold))
                .tracking(0.1)
                .foregroundStyle(DS.Colors.Ink.primary)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.pill)
                        .stroke(DS.Colors.Line.subtle, lineWidth: 1)
                )
        }
        .buttonStyle(PressableButtonStyle())
    }
}

/// No background, no border. Tertiary ink color.
struct GhostButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 15, weight: .semibold))
                .tracking(0.1)
                .foregroundStyle(DS.Colors.Ink.tertiary)
                .frame(height: 44)
        }
        .buttonStyle(PressableButtonStyle())
    }
}

/// Circular icon button.
struct IconButton: View {
    let systemName: String
    var size: CGFloat = 40
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(DS.Colors.Ink.primary)
                .frame(width: size, height: size)
                .background(DS.Colors.Bg.raised)
                .clipShape(Circle())
                .overlay(
                    Circle().stroke(DS.Colors.Line.hairline, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.30), radius: 2, y: 1)
                // Keep a ≥44pt tappable area even when the visible circle is smaller.
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
    }
}

/// Shared press feedback for all buttons.
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(DS.Motion.standardSpring, value: configuration.isPressed)
    }
}

#Preview {
    ZStack {
        DS.Colors.Bg.base.ignoresSafeArea()
        VStack(spacing: DS.Spacing.s16) {
            PrimaryButton(label: "Begin Session", hint: "12 MIN") {}
            FloatingButton(label: "Continue") {}
            SecondaryButton(label: "Skip For Now") {}
            GhostButton(label: "Not Now") {}
            IconButton(systemName: "bell") {}
        }
        .padding(.horizontal, DS.Spacing.s20)
    }
}
