//
//  CombineTestHistoryView.swift
//  MFElite
//
//  A test's full attempt history: a line chart of every recorded result (the
//  most recent 12 shown) with the personal best marked, and a reverse-chrono
//  list of every attempt with its value and tier standing on both scales. For
//  timed events the chart's y-axis is inverted so a faster time still trends
//  UPWARD — a rising line always means improving. Nothing is ever dropped.
//

import SwiftUI
import SwiftData
import Charts

struct CombineTestHistoryView: View {
    let test: CombineTest

    @Query private var allResults: [CombineResult]
    @Environment(\.modelContext) private var modelContext
    @State private var profile = PlayerProfileStore.shared
    @State private var editingResult: CombineResult?

    /// This test's attempts, oldest → newest.
    private var history: [CombineResult] {
        allResults
            .filter { $0.testID == test.id }
            .sorted { $0.recordedAt < $1.recordedAt }
    }

    /// Newest → oldest, for the list.
    private var reverseHistory: [CombineResult] {
        history.reversed()
    }

    /// The most recent 12 attempts shown on the chart.
    private var chartHistory: [CombineResult] {
        Array(history.suffix(12))
    }

    private var best: Double? { CombineStats.personalBest(test, results: allResults) }

    private let benchmarks = CombineBenchmarks.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                chartSection
                listSection
            }
            .padding(.bottom, 120)
        }
        .background(DS.Colors.Bg.base)
        .scrollIndicators(.hidden)
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingResult) { result in
            CombineEditSheet(test: test, result: result) { newValue in
                result.value = newValue
                try? modelContext.save()
                SyncEngine.shared.enqueueCombineResult(result)
            }
        }
    }

    // MARK: - Edit / delete

    /// Permanently remove one attempt from the log and enqueue the server delete.
    private func delete(_ result: CombineResult) {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        let id = result.id
        modelContext.delete(result)
        try? modelContext.save()
        SyncEngine.shared.enqueueCombineResultDeletion(id: id)
    }

    // MARK: - Chart

    @ViewBuilder
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s12) {
            Eyebrow(text: "\(history.count) \(history.count == 1 ? "attempt" : "attempts")")
            Text(test.name)
                .style(.title1)
                .foregroundStyle(DS.Colors.Ink.primary)

            if history.isEmpty {
                Text("No attempts recorded yet.")
                    .style(.foot)
                    .foregroundStyle(DS.Colors.Ink.tertiary)
                    .padding(.top, DS.Spacing.s8)
            } else if history.count == 1 {
                Text("Test again to start charting your trend.")
                    .style(.foot)
                    .foregroundStyle(DS.Colors.Ink.tertiary)
                    .padding(.top, DS.Spacing.s8)
            } else {
                chart
                    .padding(.top, DS.Spacing.s12)
                if test.lowerIsBetter {
                    Text("Faster times sit higher — a rising line means you're improving.")
                        .style(.micro)
                        .foregroundStyle(DS.Colors.Ink.quaternary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s20)
    }

    private var chart: some View {
        Chart(chartHistory) { result in
            LineMark(
                x: .value("Date", result.recordedAt),
                y: .value(test.unit, result.value)
            )
            .foregroundStyle(Color.white)
            .interpolationMethod(.monotone)
            .lineStyle(StrokeStyle(lineWidth: 2))

            PointMark(
                x: .value("Date", result.recordedAt),
                y: .value(test.unit, result.value)
            )
            .foregroundStyle(Color.white)
            .symbolSize(36)

            if let best, result.value == best {
                PointMark(
                    x: .value("Date", result.recordedAt),
                    y: .value(test.unit, result.value)
                )
                .foregroundStyle(Color.white)
                .symbolSize(130)
                .symbol(.circle)
                .annotation(position: .top, spacing: 4) {
                    Text("PB")
                        .style(.microSm)
                        .foregroundStyle(DS.Colors.Ink.secondary)
                }
            }
        }
        // Invert the axis for timed events so a smaller (faster) value sits higher
        // and the line still climbs as the player improves.
        .chartYScale(domain: .automatic(includesZero: false, reversed: test.lowerIsBetter))
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine().foregroundStyle(DS.Colors.Line.hairline)
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    .foregroundStyle(DS.Colors.Ink.quaternary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine().foregroundStyle(DS.Colors.Line.hairline)
                AxisValueLabel().foregroundStyle(DS.Colors.Ink.quaternary)
            }
        }
        .frame(height: 200)
    }

    // MARK: - List

    @ViewBuilder
    private var listSection: some View {
        if !history.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                SectionHead(eyebrow: "Every Attempt", title: "Log")

                ForEach(Array(reverseHistory.enumerated()), id: \.element.id) { index, result in
                    attemptRow(result, isBest: best != nil && result.value == best)
                    if index != reverseHistory.count - 1 {
                        Hairline()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.top, DS.Spacing.s32 - 4)
        }
    }

    private func attemptRow(_ result: CombineResult, isBest: Bool) -> some View {
        HStack(spacing: DS.Spacing.s16) {
            VStack(alignment: .leading, spacing: DS.Spacing.s4) {
                HStack(spacing: DS.Spacing.s8) {
                    Text(result.recordedAt, format: .dateTime.month(.abbreviated).day().year())
                        .style(.foot)
                        .foregroundStyle(DS.Colors.Ink.primary)
                    if isBest {
                        Text("PB")
                            .style(.microSm)
                            .foregroundStyle(DS.Colors.Ground.primary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.white)
                            .clipShape(Capsule())
                    }
                }
                if let tiers = tierCaption(for: result.value) {
                    Text(tiers)
                        .style(.micro)
                        .foregroundStyle(DS.Colors.Ink.quaternary)
                }
            }

            Spacer(minLength: 0)

            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.s4) {
                Text(CombineFormat.value(result.value, unit: test.unit))
                    .font(DS.Typography.num(size: 20))
                    .foregroundStyle(DS.Colors.Ink.primary)
                Text(test.unit)
                    .style(.micro)
                    .foregroundStyle(DS.Colors.Ink.quaternary)
            }

            Menu {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    editingResult = result
                } label: {
                    Label("Edit Score", systemImage: "pencil")
                }
                Button(role: .destructive) {
                    delete(result)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DS.Colors.Ink.quaternary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
        }
        .padding(.vertical, DS.Spacing.s16)
    }

    /// "M: Elite · W: Pro-Level" when the player's age and a benchmark exist.
    private func tierCaption(for value: Double) -> String? {
        guard let age = profile.age,
              let male = benchmarks.standing(testID: test.id, value: value, age: age, female: false),
              let female = benchmarks.standing(testID: test.id, value: value, age: age, female: true)
        else { return nil }
        return "M: \(male.tier.label) · W: \(female.tier.label)"
    }
}

// MARK: - Edit sheet

/// A compact sheet to correct or fix a past attempt's value. Editing preserves
/// the original date; only the recorded value changes.
private struct CombineEditSheet: View {
    let test: CombineTest
    let result: CombineResult
    let onSave: (Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    @State private var didSave = false
    @FocusState private var focused: Bool

    /// What the field was seeded with. Compared as text, so re-typing the same
    /// number in a different form still counts as an edit — it saves the same
    /// value, so that is harmless.
    private let initialText: String

    init(test: CombineTest, result: CombineResult, onSave: @escaping (Double) -> Void) {
        self.test = test
        self.result = result
        self.onSave = onSave
        let seed = CombineFormat.value(result.value, unit: test.unit)
        self.initialText = seed
        _text = State(initialValue: seed)
    }

    private var parsed: Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard let value = Double(trimmed), value > 0 else { return nil }
        return value
    }

    /// A usable number that differs from the text the sheet opened with.
    /// Compared as text, so re-typing the same number in a different form
    /// still counts as an edit — it saves the same value, so that is harmless.
    private var isCorrection: Bool { parsed != nil && text != initialText }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: DS.Spacing.s16) {
                Text(result.recordedAt, format: .dateTime.month(.abbreviated).day().year())
                    .style(.foot)
                    .foregroundStyle(DS.Colors.Ink.tertiary)

                HStack(spacing: DS.Spacing.s12) {
                    HStack(spacing: DS.Spacing.s12) {
                        TextField("0", text: $text)
                            .keyboardType(.decimalPad)
                            .focused($focused)
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

                    // Replaces the "Save" bar button. The decimal pad has no
                    // return key, so the commit needs to be next to the number.
                    ConfirmButton(
                        isEnabled: isCorrection,
                        isConfirmed: didSave,
                        label: "Save corrected score"
                    ) {
                        commit()
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(DS.Spacing.s20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DS.Colors.Bg.base)
            .navigationTitle("Edit " + test.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { focused = true }
        }
        .presentationDetents([.height(260)])
        .preferredColorScheme(.dark)
    }

    /// Saves, then holds the settled checkmark long enough to be read before
    /// the sheet closes — otherwise the confirmation is never seen.
    private func commit() {
        guard let parsed else { return }
        focused = false
        didSave = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        onSave(parsed)
        Task {
            try? await Task.sleep(for: .milliseconds(420))
            dismiss()
        }
    }
}

#Preview {
    NavigationStack {
        CombineTestHistoryView(
            test: CombineTest(
                id: "juggle", name: "Juggling Record", unit: "touches",
                lowerIsBetter: false, category: "technical",
                instructions: ["Keep it up."], sortIndex: 0
            )
        )
    }
    .preferredColorScheme(.dark)
    .modelContainer(for: [CombineTest.self, CombineResult.self])
}
