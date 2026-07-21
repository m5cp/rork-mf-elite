//
//  CombineTestDetailView.swift
//  MFElite
//
//  A single combine test's home: personal best, a trend chart of every recorded
//  attempt over time (append-only history), the "where you stand" benchmark
//  card, and a button to run the test again. Opened from the MF Combine list.
//

import SwiftUI
import SwiftData
import Charts

struct CombineTestDetailView: View {
    let test: CombineTest

    @Query private var allResults: [CombineResult]
    @State private var runningTest: CombineTest?

    /// This test's attempts, oldest → newest.
    private var history: [CombineResult] {
        allResults
            .filter { $0.testID == test.id }
            .sorted { $0.recordedAt < $1.recordedAt }
    }

    private var best: Double? { CombineStats.personalBest(test, results: allResults) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                statStrip
                trendSection
                CombineStandingCard(test: test, value: best)
                    .padding(.horizontal, DS.Spacing.s20)
                    .padding(.top, DS.Spacing.s24)
            }
            .padding(.bottom, 140)
        }
        .background(DS.Colors.Bg.base)
        .scrollIndicators(.hidden)
        .navigationTitle(test.name)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(label: history.isEmpty ? "Start test" : "Test again") {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                runningTest = test
            }
            .padding(.horizontal, DS.Spacing.s20)
            // Clear the floating tab bar so the button is fully visible and tappable.
            .padding(.bottom, DS.tabBarClearance + DS.Spacing.s12)
            .background(
                LinearGradient(
                    colors: [DS.Colors.Bg.base.opacity(0), DS.Colors.Bg.base],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()
            )
        }
        .fullScreenCover(item: $runningTest) { test in
            CombineTestFlowView(test: test)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s8) {
            Eyebrow(text: test.category)
            Text(test.name)
                .style(.title1)
                .foregroundStyle(DS.Colors.Ink.primary)
            Text(test.instructions.first ?? "")
                .style(.callout)
                .foregroundStyle(DS.Colors.Ink.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s20)
    }

    // MARK: - Stat strip

    private var statStrip: some View {
        Card {
            HStack(spacing: 0) {
                stat(
                    label: "Best",
                    value: best.map { CombineFormat.value($0, unit: test.unit) } ?? "—"
                )
                divider
                stat(
                    label: "Latest",
                    value: history.last.map { CombineFormat.value($0.value, unit: test.unit) } ?? "—"
                )
                divider
                stat(label: "Attempts", value: "\(history.count)")
            }
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s20)
    }

    private func stat(label: String, value: String) -> some View {
        VStack(spacing: DS.Spacing.s4) {
            Text(value)
                .font(DS.Typography.num(size: 24))
                .tracking(-1)
                .foregroundStyle(DS.Colors.Ink.primary)
            Eyebrow(text: label)
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle()
            .fill(DS.Colors.Line.hairline)
            .frame(width: 1, height: 36)
    }

    // MARK: - Trend

    @ViewBuilder
    private var trendSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s12) {
            HStack {
                Eyebrow(text: "Progress")
                Spacer()
                if !history.isEmpty {
                    NavigationLink(value: CombineHistoryRoute(test: test)) {
                        HStack(spacing: 3) {
                            Text("History")
                                .style(.micro)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }

            if history.count < 2 {
                Text(history.isEmpty
                     ? "Run the test to start tracking your trend."
                     : "Test again to see your trend take shape.")
                    .style(.foot)
                    .foregroundStyle(DS.Colors.Ink.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                trendChart
                Text(trendCaption)
                    .style(.micro)
                    .foregroundStyle(DS.Colors.Ink.quaternary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s32 - 4)
    }

    private var trendChart: some View {
        Chart(history) { result in
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
                .symbolSize(120)
                .symbol(.circle)
                .annotation(position: .top, spacing: 4) {
                    Text("PB")
                        .style(.microSm)
                        .foregroundStyle(DS.Colors.Ink.secondary)
                }
            }
        }
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
        .frame(height: 180)
    }

    /// A plain-language read on direction from first to latest attempt, honoring
    /// lowerIsBetter (a faster time is an improvement).
    private var trendCaption: String {
        guard let first = history.first, let last = history.last, first.id != last.id else {
            return ""
        }
        let delta = CombineStats.delta(last.value, previous: first.value, test: test)
        switch delta {
        case .improved: return "Trending up since your first attempt."
        case .same:     return "Holding steady since your first attempt."
        case .declined: return "Down from your first attempt — time to test again."
        }
    }
}
