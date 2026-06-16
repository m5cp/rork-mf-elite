//
//  MotionEffects.swift
//  MFElite
//
//  Reusable arrival-motion building blocks: a staggered entrance modifier and an
//  animated count-up number. Both respect the system Reduce Motion setting.
//

import SwiftUI

// MARK: - Staggered entrance

/// Rises and fades a section in once, offset by its position so a column of
/// sections cascades from top to bottom. Plays only when `appeared` flips true,
/// so it never replays while scrolling.
struct EntranceModifier: ViewModifier {
    let index: Int
    let appeared: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Delay grows with position but is capped so the last sections don't lag.
    private var delay: Double {
        min(Double(index) * 0.05, 0.6)
    }

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 18)
                .animation(
                    .spring(response: 0.5, dampingFraction: 0.85).delay(delay),
                    value: appeared
                )
        }
    }
}

extension View {
    /// Cascading entrance for a section at `index`, driven by the parent's
    /// `appeared` flag (set once in `.onAppear`).
    func entrance(_ index: Int, appeared: Bool) -> some View {
        modifier(EntranceModifier(index: index, appeared: appeared))
    }
}

// MARK: - Count-up number

/// Drives interpolated number text via `animatableData` so the value animates
/// frame-by-frame rather than snapping.
private struct CountUpModifier: AnimatableModifier {
    var number: Double
    let format: (Double) -> String

    var animatableData: Double {
        get { number }
        set { number = newValue }
    }

    func body(content: Content) -> some View {
        Text(format(number))
    }
}

/// An integer that counts up from zero to `value` on appear with a smooth easing
/// settle. Apply `.font` / `.foregroundStyle` from the call site as usual.
struct CountUp: View {
    let value: Int
    var format: (Int) -> String = { $0.formatted() }
    var duration: Double = 0.9

    @State private var current: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        EmptyView()
            .modifier(CountUpModifier(number: current) { format(Int($0.rounded())) })
            .onAppear {
                guard !reduceMotion else { current = Double(value); return }
                current = 0
                withAnimation(.easeOut(duration: duration)) { current = Double(value) }
            }
            .onChange(of: value) { _, newValue in
                withAnimation(reduceMotion ? nil : DS.Motion.standardSpring) {
                    current = Double(newValue)
                }
            }
            .accessibilityLabel(format(value))
    }
}
