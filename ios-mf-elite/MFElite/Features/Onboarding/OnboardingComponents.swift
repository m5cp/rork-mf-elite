//
//  OnboardingComponents.swift
//  MFElite
//
//  Shared building blocks for the cinematic onboarding flow: chapter eyebrows,
//  the 6-segment step bar, the arrow CTA pill, the diagonal MF stripe texture,
//  the interactive pitch diagram, and the numeric keypad.
//

import SwiftUI

// MARK: - Diagonal stripe texture

/// The faint 115° MF slash motif used as a full-screen background texture.
struct DiagonalStripes: View {
    var opacity: Double = 0.4
    var spacing: CGFloat = 26

    var body: some View {
        Canvas { context, size in
            let angle = Angle(degrees: 115).radians
            let slope = cos(angle) / sin(angle)
            let diagonal = size.width + size.height
            var offset: CGFloat = -size.height * abs(slope)
            while offset < diagonal {
                var path = Path()
                path.move(to: CGPoint(x: offset, y: 0))
                path.addLine(to: CGPoint(x: offset - size.height * slope, y: size.height))
                context.stroke(path, with: .color(.white.opacity(0.05)), lineWidth: 1)
                offset += spacing
            }
        }
        .opacity(opacity)
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}

// MARK: - ChapterEyebrow

/// Two-digit chapter number + dash rule + label, e.g. "00 — THE CODE".
struct ChapterEyebrow: View {
    let number: Int
    let label: String

    var body: some View {
        HStack(spacing: DS.Spacing.s8) {
            Text(String(format: "%02d", number))
                .style(.micro)
                .foregroundStyle(DS.Colors.Ink.primary)
            Rectangle()
                .fill(DS.Colors.Line.subtle)
                .frame(width: 22, height: 1)
            Text(label.uppercased())
                .style(.micro)
                .foregroundStyle(DS.Colors.Ink.tertiary)
        }
    }
}

// MARK: - StepBar

/// Six segments; the first `filled` are white, the rest dim.
struct StepBar: View {
    let filled: Int
    var total: Int = 6

    var body: some View {
        HStack(spacing: DS.Spacing.s8) {
            ForEach(0..<total, id: \.self) { index in
                Capsule()
                    .fill(index < filled ? Color.white : Color.white.opacity(0.14))
                    .frame(height: 3)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Step \(filled) of \(total)")
    }
}

// MARK: - ArrowCTA

/// Secondary-style pill with a trailing arrow, used on the creed slate.
struct ArrowCTA: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.s8) {
                Text(label.uppercased())
                    .font(.system(size: 13, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(DS.Colors.Ink.primary)
                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(DS.Colors.Ink.primary)
            }
            .padding(.vertical, DS.Spacing.s12)
            .padding(.horizontal, DS.Spacing.s20)
            .overlay(
                Capsule().stroke(DS.Colors.Line.subtle, lineWidth: 1)
            )
        }
        .buttonStyle(PressableButtonStyle())
    }
}

// MARK: - Underline input

/// Editorial underline text field used on the Identify step.
struct UnderlineField: View {
    let placeholder: String
    @Binding var text: String
    var fontSize: CGFloat = 32
    var keyboard: UIKeyboardType = .default
    var maxLength: Int? = nil

    var body: some View {
        VStack(spacing: DS.Spacing.s8) {
            TextField("", text: $text, prompt: Text(placeholder).foregroundColor(DS.Colors.Ink.disabled))
                .font(.system(size: fontSize, weight: .bold))
                .foregroundStyle(DS.Colors.Ink.primary)
                .tint(.white)
                .keyboardType(keyboard)
                .onChange(of: text) { _, newValue in
                    if let maxLength, newValue.count > maxLength {
                        text = String(newValue.prefix(maxLength))
                    }
                }
            Rectangle()
                .fill(Color.white)
                .frame(height: 1.5)
        }
    }
}

// MARK: - Pitch diagram

/// A top-down pitch with tappable position dots.
struct PitchDiagram: View {
    let positions: [PitchPosition]
    @Binding var selected: PitchPosition?

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                pitchLines(width: w, height: h)
                ForEach(positions) { position in
                    dot(for: position, width: w, height: h)
                }
            }
        }
    }

    private func dot(for position: PitchPosition, width: CGFloat, height: CGFloat) -> some View {
        let isSelected = selected?.id == position.id
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(DS.Motion.standardSpring) { selected = position }
        } label: {
            ZStack {
                if isSelected {
                    Circle()
                        .fill(Color.white.opacity(0.45))
                        .frame(width: 56, height: 56)
                        .blur(radius: 14)
                }
                Circle()
                    .fill(isSelected ? Color.white : Color.white.opacity(0.12))
                    .frame(width: isSelected ? 32 : 20, height: isSelected ? 32 : 20)
                    .overlay(
                        Circle().stroke(
                            isSelected ? Color.white.opacity(0.10) : Color.white.opacity(0.55),
                            lineWidth: isSelected ? 6 : 1.5
                        )
                    )
                Text(position.code.replacingOccurrences(of: "2", with: ""))
                    .font(.system(size: 12, weight: .bold))
                    .tracking(1.6)
                    .foregroundStyle(isSelected ? DS.Colors.Ground.primary : DS.Colors.Ink.secondary)
                    .offset(y: isSelected ? 0 : 22)
            }
        }
        .buttonStyle(PressableButtonStyle())
        .position(x: position.x * width, y: position.y * height)
        .accessibilityLabel(position.name)
    }

    private func pitchLines(width w: CGFloat, height h: CGFloat) -> some View {
        let line = Color.white.opacity(0.28)
        return ZStack {
            Rectangle().stroke(line, lineWidth: 1.5)
            // Halfway line
            Path { p in
                p.move(to: CGPoint(x: 0, y: h / 2))
                p.addLine(to: CGPoint(x: w, y: h / 2))
            }.stroke(line, lineWidth: 1.5)
            // Centre circle
            Circle()
                .stroke(line, lineWidth: 1.5)
                .frame(width: w * 0.28, height: w * 0.28)
            // Top penalty box
            Rectangle()
                .stroke(line, lineWidth: 1.5)
                .frame(width: w * 0.5, height: h * 0.16)
                .position(x: w / 2, y: h * 0.08)
            // Bottom penalty box
            Rectangle()
                .stroke(line, lineWidth: 1.5)
                .frame(width: w * 0.5, height: h * 0.16)
                .position(x: w / 2, y: h * 0.92)
            // Top goal box
            Rectangle()
                .stroke(line, lineWidth: 1.5)
                .frame(width: w * 0.26, height: h * 0.07)
                .position(x: w / 2, y: h * 0.035)
            // Bottom goal box
            Rectangle()
                .stroke(line, lineWidth: 1.5)
                .frame(width: w * 0.26, height: h * 0.07)
                .position(x: w / 2, y: h * 0.965)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Numeric keypad

/// A 3×4 numeric keypad (1–9, blank, 0, backspace) used to pick the kit number.
struct NumberKeypad: View {
    @Binding var value: String
    var maxDigits: Int = 2

    private let keys: [String] = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "", "0", "⌫"]

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DS.Spacing.s12), count: 3), spacing: DS.Spacing.s12) {
            ForEach(keys, id: \.self) { key in
                keyButton(key)
            }
        }
    }

    @ViewBuilder
    private func keyButton(_ key: String) -> some View {
        if key.isEmpty {
            Color.clear.frame(height: 50)
        } else {
            Button {
                tap(key)
            } label: {
                Text(key)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(DS.Colors.Ink.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color(hex: "#0D0D0D"))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(DS.Colors.Line.subtle, lineWidth: 1)
                    )
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel(key == "⌫" ? "Delete" : key)
        }
    }

    private func tap(_ key: String) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if key == "⌫" {
            if !value.isEmpty { value.removeLast() }
        } else if value.count < maxDigits {
            // Block a leading zero so kit numbers read naturally.
            if value.isEmpty && key == "0" { return }
            value.append(key)
        }
    }
}
