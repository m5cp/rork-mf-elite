//
//  CombineTestFlowView.swift
//  MFElite
//
//  Runs a single combine test: step-by-step instructions (mirroring the mental
//  exercise step player), then a measurement screen — a stopwatch for timed
//  events or a number pad for counts. Saving APPENDS a new CombineResult and
//  shows a personal-best celebration or a quiet "previous best stands" line.
//

import SwiftUI
import SwiftData

struct CombineTestFlowView: View {
    let test: CombineTest

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var results: [CombineResult]

    @State private var stage: Stage = .steps
    @State private var stepIndex = 0
    @State private var entryText = ""
    @State private var savedValue: Double = 0
    @State private var wasPersonalBest = false

    @FocusState private var entryFocused: Bool

    private enum Stage {
        case steps
        case entry
        case result
    }

    private var isTimed: Bool { test.unit == "seconds" }

    private var priorResults: [CombineResult] {
        results.filter { $0.testID == test.id }
    }

    var body: some View {
        ZStack {
            DS.Colors.Bg.base.ignoresSafeArea()

            switch stage {
            case .steps:  stepsStage
            case .entry:  entryStage
            case .result: resultStage
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Header

    private func header(showProgress: Bool) -> some View {
        VStack(spacing: DS.Spacing.s16) {
            HStack {
                IconButton(systemName: "xmark", size: 36) { dismiss() }
                Spacer()
                Eyebrow(text: test.category)
                    .foregroundStyle(DS.Colors.Ink.tertiary)
                Spacer()
                Color.clear.frame(width: 36, height: 36)
            }

            if showProgress {
                HStack(spacing: 4) {
                    ForEach(test.instructions.indices, id: \.self) { idx in
                        Capsule()
                            .fill(idx <= stepIndex ? Color.white : DS.Colors.Line.subtle)
                            .frame(height: 4)
                            .frame(maxWidth: .infinity)
                            .animation(DS.Motion.standardSpring, value: stepIndex)
                    }
                }
            }
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s16)
    }

    // MARK: - Steps

    private var stepsStage: some View {
        VStack(spacing: 0) {
            header(showProgress: true)

            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.s12) {
                    Eyebrow(text: "Step \(stepIndex + 1) of \(test.instructions.count)")
                        .foregroundStyle(DS.Colors.Ink.quaternary)

                    Text(test.name)
                        .style(.foot)
                        .foregroundStyle(DS.Colors.Ink.tertiary)

                    Text(test.instructions[stepIndex])
                        .style(.title2)
                        .foregroundStyle(DS.Colors.Ink.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .animation(DS.Motion.standardSpring, value: stepIndex)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DS.Spacing.s20)
                .padding(.top, DS.Spacing.s32)
                .padding(.bottom, DS.Spacing.s24)
            }
            .scrollIndicators(.hidden)

            HStack(spacing: DS.Spacing.s12) {
                if stepIndex > 0 {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(DS.Motion.standardSpring) { stepIndex -= 1 }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(DS.Colors.Ink.primary)
                            .frame(width: 56, height: 56)
                            .overlay(Circle().stroke(DS.Colors.Line.subtle, lineWidth: 1))
                    }
                    .buttonStyle(PressableButtonStyle())
                }

                FloatingButton(
                    label: stepIndex < test.instructions.count - 1 ? "Next" : "Enter your score"
                ) {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    if stepIndex < test.instructions.count - 1 {
                        withAnimation(DS.Motion.standardSpring) { stepIndex += 1 }
                    } else {
                        withAnimation(DS.Motion.standardSpring) { stage = .entry }
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.bottom, DS.Spacing.s40)
        }
    }

    // MARK: - Entry

    private var entryStage: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    entryFocused = false
                    withAnimation(DS.Motion.standardSpring) { stage = .steps }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(DS.Colors.Ink.primary)
                        .frame(width: 36, height: 36)
                        .background(DS.Colors.Bg.raised)
                        .clipShape(Circle())
                }
                .buttonStyle(PressableButtonStyle())
                Spacer()
                IconButton(systemName: "xmark", size: 36) { dismiss() }
            }
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.top, DS.Spacing.s16)

            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.s8) {
                    Eyebrow(text: "Your Result")
                        .foregroundStyle(DS.Colors.Ink.quaternary)
                    Text(test.name)
                        .style(.hero)
                        .foregroundStyle(DS.Colors.Ink.primary)
                    Text(isTimed
                         ? "Time the run, then use it — or type your time."
                         : "Enter your best \(test.unit).")
                        .style(.callout)
                        .foregroundStyle(DS.Colors.Ink.tertiary)

                    if isTimed {
                        CombineStopwatch { seconds in
                            entryText = String(format: "%.2f", seconds)
                            entryFocused = false
                        }
                        .padding(.top, DS.Spacing.s24)
                    }

                    manualField
                        .padding(.top, DS.Spacing.s24)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DS.Spacing.s20)
                .padding(.top, DS.Spacing.s24)
                .padding(.bottom, DS.Spacing.s24)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)

            FloatingButton(label: "Save result") {
                save()
            }
            .disabled(parsedValue == nil)
            .opacity(parsedValue == nil ? 0.5 : 1)
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.bottom, DS.Spacing.s40)
        }
    }

    private var manualField: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s8) {
            Eyebrow(text: isTimed ? "Or type it instead" : "Tap to enter")
                .foregroundStyle(DS.Colors.Ink.quaternary)
            HStack(spacing: DS.Spacing.s12) {
                TextField(isTimed ? "9.43" : "0", text: $entryText)
                    .keyboardType(.decimalPad)
                    .focused($entryFocused)
                    .font(DS.Typography.num(size: 40))
                    .foregroundStyle(DS.Colors.Ink.primary)
                Text(test.unit)
                    .style(.title3)
                    .foregroundStyle(DS.Colors.Ink.tertiary)
            }
            .padding(DS.Spacing.s16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DS.Colors.Bg.elevated)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .stroke(entryFocused ? DS.Colors.Line.strong : DS.Colors.Line.subtle, lineWidth: 1)
            )
            .contentShape(Rectangle())
            .onTapGesture { entryFocused = true }
        }
    }

    /// The entered score parsed to a Double, accepting decimals (e.g. half-laps).
    private var parsedValue: Double? {
        let trimmed = entryText.trimmingCharacters(in: .whitespaces)
        guard let value = Double(trimmed), value > 0 else { return nil }
        return value
    }

    // MARK: - Save

    private func save() {
        guard let value = parsedValue else { return }
        entryFocused = false

        // Determine PB against existing results BEFORE inserting the new attempt.
        wasPersonalBest = CombineStats.isPersonalBest(value, test: test, priorResults: priorResults)
        savedValue = value

        modelContext.insert(CombineResult(testID: test.id, value: value))
        try? modelContext.save()

        if wasPersonalBest {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        withAnimation(DS.Motion.celebrationSpring) { stage = .result }
    }

    // MARK: - Result

    private var resultStage: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: DS.Spacing.s24) {
                    celebration
                        .padding(.horizontal, DS.Spacing.s40)
                        .padding(.top, DS.Spacing.s48)

                    CombineStandingCard(test: test, value: savedValue)
                        .padding(.horizontal, DS.Spacing.s20)
                }
                .padding(.bottom, DS.Spacing.s24)
            }
            .scrollIndicators(.hidden)

            PrimaryButton(label: "Done") { dismiss() }
                .padding(.horizontal, DS.Spacing.s20)
                .padding(.bottom, DS.Spacing.s40)
        }
    }

    private var celebration: some View {
        VStack(spacing: DS.Spacing.s24) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(wasPersonalBest ? 0.10 : 0.05))
                    .frame(width: 160, height: 160)
                    .blur(radius: 40)
                Image(systemName: wasPersonalBest ? "trophy.fill" : "checkmark")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(DS.Colors.Ink.primary)
            }

            VStack(spacing: DS.Spacing.s8) {
                Eyebrow(text: wasPersonalBest ? "New Personal Best" : "Logged")
                Text("\(CombineFormat.value(savedValue, unit: test.unit))")
                    .style(.hero)
                    .foregroundStyle(DS.Colors.Ink.primary)
                Text(test.unit)
                    .style(.title3)
                    .foregroundStyle(DS.Colors.Ink.tertiary)
                Text(wasPersonalBest
                     ? "That's your best \(test.name) yet."
                     : "Logged. Previous best stands.")
                    .style(.callout)
                    .foregroundStyle(DS.Colors.Ink.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.top, DS.Spacing.s4)
            }
        }
    }
}

// MARK: - Stopwatch

/// A simple start/stop stopwatch with big mono digits. On stop it surfaces a
/// "Use this time" button that hands the elapsed seconds back to the caller.
private struct CombineStopwatch: View {
    var onUse: (Double) -> Void

    @State private var elapsed: TimeInterval = 0
    @State private var isRunning = false
    @State private var startDate: Date?
    @State private var timer: Timer?

    var body: some View {
        VStack(spacing: DS.Spacing.s16) {
            Text(String(format: "%.2f", elapsed))
                .font(DS.Typography.num(size: 56))
                .foregroundStyle(DS.Colors.Ink.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.s20)
                .background(DS.Colors.Bg.elevated)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))

            HStack(spacing: DS.Spacing.s12) {
                SecondaryButton(label: isRunning ? "Stop" : (elapsed > 0 ? "Reset" : "Start")) {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    if isRunning {
                        stop()
                    } else if elapsed > 0 {
                        reset()
                    } else {
                        start()
                    }
                }

                if !isRunning && elapsed > 0 {
                    PrimaryButton(label: "Use this time", size: .medium) {
                        onUse(elapsed)
                    }
                }
            }
        }
        .onDisappear { timer?.invalidate(); timer = nil }
    }

    private func start() {
        startDate = Date()
        isRunning = true
        let t = Timer(timeInterval: 0.03, repeats: true) { _ in
            Task { @MainActor in
                if let startDate { elapsed = Date().timeIntervalSince(startDate) }
            }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func stop() {
        timer?.invalidate(); timer = nil
        isRunning = false
        if let startDate { elapsed = Date().timeIntervalSince(startDate) }
    }

    private func reset() {
        timer?.invalidate(); timer = nil
        isRunning = false
        elapsed = 0
        startDate = nil
    }
}

#Preview {
    CombineTestFlowView(
        test: CombineTest(
            id: "juggle", name: "Juggling Record", unit: "touches",
            lowerIsBetter: false, category: "technical",
            instructions: ["Ball starts in your hands.", "Keep it up.", "Count every touch."],
            sortIndex: 0
        )
    )
    .preferredColorScheme(.dark)
    .modelContainer(for: [CombineTest.self, CombineResult.self])
}
