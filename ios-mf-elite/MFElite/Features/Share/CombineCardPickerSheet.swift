//
//  CombineCardPickerSheet.swift
//  MFElite
//
//  Pre-editor picker for the two combine share cards. Combine Result: choose
//  exactly one test you've completed to feature. Combine Scorecard: choose any
//  subset of your completed tests (default: all). Players with no combine data
//  can still open a sample preview.
//

import SwiftUI
import SwiftData

struct CombineCardPickerSheet: View {
    let kind: ShareMomentKind
    let onBuilt: (ShareMoment) -> Void

    @Environment(\.dismiss) private var dismiss
    @Query private var tests: [CombineTest]
    @Query private var results: [CombineResult]
    @State private var selected: Set<String> = []

    /// Tests that have at least one recorded attempt, in seed order.
    private var completedTests: [CombineTest] {
        tests
            .filter { test in results.contains { $0.testID == test.id } }
            .sorted { $0.sortIndex < $1.sortIndex }
    }

    private var isScorecard: Bool { kind == .combineScorecard }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s16) {
            Capsule()
                .fill(DS.Colors.Line.subtle)
                .frame(width: 36, height: 4)
                .frame(maxWidth: .infinity)

            Eyebrow(text: isScorecard ? "Combine Scorecard" : "Combine Result")
            Text(isScorecard ? "Choose the tests to show" : "Choose one test to feature")
                .style(.title3)
                .foregroundStyle(DS.Colors.Ink.primary)

            if completedTests.isEmpty {
                Text("You haven't recorded a combine test yet. You can still preview the card — run a test on the Progress tab to fill it with your real scores.")
                    .style(.foot)
                    .foregroundStyle(DS.Colors.Ink.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
                PrimaryButton(label: "Preview sample card") {
                    onBuilt(.sample(kind, playerLine: ShareMomentBuilder.playerLine))
                    dismiss()
                }
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(completedTests, id: \.id) { test in
                            testRow(test)
                            Hairline()
                        }
                    }
                }
                .frame(maxHeight: 300)

                PrimaryButton(label: "Create card") { build() }
                    .disabled(selected.isEmpty)
            }
        }
        .padding(DS.Spacing.s20)
        .background(DS.Colors.Bg.base)
        .onAppear {
            if isScorecard {
                selected = Set(completedTests.map(\.id)) // default: all completed
            } else if let first = completedTests.first {
                selected = [first.id] // default: first completed
            }
        }
    }

    private func testRow(_ test: CombineTest) -> some View {
        let isOn = selected.contains(test.id)
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            if isScorecard {
                if isOn { selected.remove(test.id) } else { selected.insert(test.id) }
            } else {
                selected = [test.id]
            }
        } label: {
            HStack(spacing: DS.Spacing.s12) {
                Image(systemName: isScorecard
                    ? (isOn ? "checkmark.square.fill" : "square")
                    : (isOn ? "largecircle.fill.circle" : "circle"))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isOn ? DS.Colors.Gold.base : DS.Colors.Ink.quaternary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(test.name)
                        .style(.body)
                        .foregroundStyle(DS.Colors.Ink.primary)
                    if let best = CombineStats.personalBest(test, results: results) {
                        Text("Best: \(CombineFormat.value(best, unit: test.unit))")
                            .style(.micro)
                            .foregroundStyle(DS.Colors.Ink.tertiary)
                    }
                }
                Spacer()
            }
            .padding(.vertical, DS.Spacing.s12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
    }

    private func build() {
        let moment: ShareMoment
        if isScorecard {
            moment = ShareMomentBuilder.combineScorecard(tests: tests, results: results, including: selected)
        } else {
            guard let testID = selected.first,
                  let test = tests.first(where: { $0.id == testID }),
                  let best = CombineStats.personalBest(test, results: results) else { return }
            moment = ShareMomentBuilder.combineResult(test: test, value: best, results: results)
        }
        onBuilt(moment)
        dismiss()
    }
}
