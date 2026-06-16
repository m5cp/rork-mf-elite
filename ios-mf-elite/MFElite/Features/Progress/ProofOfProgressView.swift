//
//  ProofOfProgressView.swift
//  MFElite
//
//  "Proof of Progress" — gathers every MF Combine test's personal best and shows
//  it climbing over time: a running-best sparkline per test, the improvement vs
//  the very first attempt, and how many skill tiers the player has climbed. Tops
//  it off with a branded, shareable summary card a player or parent can save.
//  Reads the append-only CombineResult log; never mutates stored data.
//

import SwiftUI
import SwiftData

/// Navigation route to the Proof of Progress dashboard.
struct ProofOfProgressRoute: Hashable {}

// MARK: - View model (pure)

/// Per-test proof of how a player's combine score has moved over time.
struct TestProof: Identifiable {
    let test: CombineTest
    let best: Double
    let first: Double
    let attempts: Int
    /// Direction-aware: did the personal best beat the first attempt?
    let improved: Bool
    /// e.g. "1.20s faster" or "+15 touches"; nil when no improvement yet.
    let improvementText: String?
    /// Running best-so-far after each attempt (always trends toward better).
    let bestsOverTime: [Double]
    /// Skill tiers climbed first→best for sex-neutral technical tests; nil otherwise.
    let tierGain: Int?
    /// The player's current tier for sex-neutral technical tests; nil otherwise.
    let currentTier: CombineTier?

    var id: String { test.id }
}

/// Computes the dashboard's proof data from the combine tests + results.
struct ProgressProof {
    let perTest: [TestProof]

    /// Total personal bests recorded (a test with any result has at least one PB).
    var testsWithData: Int { perTest.count }
    /// Tests whose best beats their first attempt.
    var testsImproved: Int { perTest.filter { $0.improved }.count }
    /// Total skill tiers climbed across sex-neutral technical tests.
    var tiersClimbed: Int { perTest.compactMap(\.tierGain).reduce(0, +) }

    init(tests: [CombineTest], results: [CombineResult], age: Int?) {
        let benchmarks = CombineBenchmarks.shared
        perTest = tests
            .sorted { $0.sortIndex < $1.sortIndex }
            .compactMap { test in
                let sorted = results
                    .filter { $0.testID == test.id }
                    .sorted { $0.recordedAt < $1.recordedAt }
                guard let firstResult = sorted.first,
                      let best = CombineStats.personalBest(test, results: sorted) else { return nil }

                let firstValue = firstResult.value

                // Running best after each attempt (monotonic toward "better").
                var runningBest: [Double] = []
                var current = firstValue
                for r in sorted {
                    current = test.lowerIsBetter ? min(current, r.value) : max(current, r.value)
                    runningBest.append(current)
                }

                let improved = test.lowerIsBetter ? best < firstValue : best > firstValue
                var improvementText: String?
                if improved {
                    let magnitude = abs(best - firstValue)
                    let formatted = CombineFormat.value(magnitude, unit: test.unit)
                    improvementText = test.unit == "seconds"
                        ? "\(formatted)s faster"
                        : "+\(formatted) \(test.unit)"
                }

                // Sex-neutral tier resolution: only the technical (skill) scales are
                // identical for everyone, so tier gains are claimed only there.
                var tierGain: Int?
                var currentTier: CombineTier?
                if test.category == "technical", let age,
                   let firstStanding = benchmarks.standing(testID: test.id, value: firstValue, age: age, female: false),
                   let bestStanding = benchmarks.standing(testID: test.id, value: best, age: age, female: false) {
                    tierGain = max(0, bestStanding.tier.rawValue - firstStanding.tier.rawValue)
                    currentTier = bestStanding.tier
                }

                return TestProof(
                    test: test, best: best, first: firstValue, attempts: sorted.count,
                    improved: improved, improvementText: improvementText,
                    bestsOverTime: runningBest, tierGain: tierGain, currentTier: currentTier
                )
            }
    }
}

// MARK: - View

struct ProofOfProgressView: View {
    @Query(sort: \CombineTest.sortIndex) private var tests: [CombineTest]
    @Query private var results: [CombineResult]

    @State private var profile = PlayerProfileStore.shared
    @State private var shareImage: ShareableImage?
    @State private var isExporting = false

    private var proof: ProgressProof {
        ProgressProof(tests: tests, results: results, age: profile.age)
    }

    var body: some View {
        let proof = self.proof
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                if proof.testsWithData == 0 {
                    emptyState
                } else {
                    summaryCard(proof)
                    shareButton
                    personalBests(proof)
                    retestFooter
                }
            }
            .padding(.bottom, 120)
        }
        .background(DS.Colors.Bg.base)
        .scrollIndicators(.hidden)
        .navigationTitle("Proof of Progress")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: CombineRoute.self) { _ in CombineView() }
        .sheet(item: $shareImage) { item in
            ShareSheet(items: [item.image])
                .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s8) {
            Eyebrow(text: "MF Combine")
            Text("Proof of\nProgress")
                .style(.hero)
                .foregroundStyle(DS.Colors.Ink.primary)
                .lineSpacing(-8)
            Text("The receipts. Every personal best, every tier you've climbed, all in one place.")
                .style(.callout)
                .foregroundStyle(DS.Colors.Ink.tertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, DS.Spacing.s4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s20)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s16) {
            Card {
                VStack(alignment: .leading, spacing: DS.Spacing.s8) {
                    Eyebrow(text: "Nothing to prove yet")
                    Text("Run your first MF Combine to set a baseline. Re-test over the weeks and this page fills with proof of how far you've come.")
                        .style(.callout)
                        .foregroundStyle(DS.Colors.Ink.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            NavigationLink(value: CombineRoute()) {
                Text("Start the combine")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(DS.Colors.Ground.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.pill))
                    .pillLightElevation()
            }
            .buttonStyle(PressableButtonStyle())
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s24)
    }

    // MARK: - Summary

    private func summaryCard(_ proof: ProgressProof) -> some View {
        Card(raised: true) {
            VStack(alignment: .leading, spacing: DS.Spacing.s16) {
                Eyebrow(text: "Since You Started")
                HStack(spacing: 0) {
                    summaryStat("\(proof.testsImproved)", "Tests Improved")
                    summaryDivider
                    summaryStat("\(proof.tiersClimbed)", "Tiers Climbed")
                    summaryDivider
                    summaryStat("\(proof.testsWithData)", "PBs Set")
                }
            }
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s24)
    }

    private func summaryStat(_ value: String, _ label: String) -> some View {
        VStack(spacing: DS.Spacing.s4) {
            Text(value)
                .font(DS.Typography.num(size: 32))
                .tracking(-1)
                .foregroundStyle(DS.Colors.Ink.primary)
            Eyebrow(text: label)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var summaryDivider: some View {
        Rectangle()
            .fill(DS.Colors.Line.hairline)
            .frame(width: 1, height: 44)
    }

    private var shareButton: some View {
        Button {
            exportAndShare()
        } label: {
            Label(isExporting ? "Preparing…" : "Share progress card", systemImage: "square.and.arrow.up")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DS.Colors.Ink.tertiary)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
        }
        .buttonStyle(PressableButtonStyle())
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s8)
    }

    // MARK: - Personal bests

    private func personalBests(_ proof: ProgressProof) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: "Personal Bests")
                .padding(.bottom, DS.Spacing.s4)

            ForEach(Array(proof.perTest.enumerated()), id: \.element.id) { index, item in
                proofRow(item)
                if index != proof.perTest.count - 1 { Hairline() }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s32 - 4)
    }

    private func proofRow(_ item: TestProof) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s12) {
            HStack(alignment: .top, spacing: DS.Spacing.s16) {
                VStack(alignment: .leading, spacing: DS.Spacing.s4) {
                    Text(item.test.name)
                        .style(.title3)
                        .foregroundStyle(DS.Colors.Ink.primary)
                    if let improvementText = item.improvementText {
                        HStack(spacing: DS.Spacing.s4) {
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color(hex: "#3DD68C"))
                            Text("\(improvementText) since your first")
                                .style(.foot)
                                .foregroundStyle(DS.Colors.Ink.tertiary)
                        }
                    } else {
                        Text(item.attempts < 2 ? "Set your baseline — re-test to track gains" : "Best holds. Keep chasing it.")
                            .style(.foot)
                            .foregroundStyle(DS.Colors.Ink.quaternary)
                    }
                    if let tier = item.currentTier {
                        Text("\(tier.label)\(item.tierGain.map { $0 > 0 ? " · +\($0) tier\($0 == 1 ? "" : "s")" : "" } ?? "")")
                            .style(.micro)
                            .foregroundStyle(DS.Colors.Ink.quaternary)
                            .padding(.top, 1)
                    }
                }

                Spacer(minLength: DS.Spacing.s8)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(CombineFormat.value(item.best, unit: item.test.unit))
                        .font(DS.Typography.num(size: 22))
                        .foregroundStyle(DS.Colors.Ink.primary)
                    Eyebrow(text: "Best")
                        .foregroundStyle(DS.Colors.Ink.quaternary)
                }
            }

            if item.bestsOverTime.count >= 2 {
                ProgressSparkline(
                    goodness: Self.goodness(item.bestsOverTime, lowerIsBetter: item.test.lowerIsBetter)
                )
                .frame(height: 32)
            }
        }
        .padding(.vertical, DS.Spacing.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Map raw best-over-time values to a 0...1 "goodness" curve that always
    /// climbs as the player improves (inverting for timed events).
    static func goodness(_ values: [Double], lowerIsBetter: Bool) -> [CGFloat] {
        guard let minV = values.min(), let maxV = values.max(), maxV != minV else {
            return values.map { _ in 0.5 }
        }
        return values.map { v in
            let t = (v - minV) / (maxV - minV)
            return lowerIsBetter ? CGFloat(1 - t) : CGFloat(t)
        }
    }

    // MARK: - Retest footer

    private var retestFooter: some View {
        NavigationLink(value: CombineRoute()) {
            Card {
                HStack(spacing: DS.Spacing.s16) {
                    Image(systemName: "stopwatch")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(DS.Colors.Ink.primary)
                        .frame(width: 44, height: 44)
                        .background(DS.Colors.Bg.raised)
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: DS.Spacing.s4) {
                        Text("Re-test the combine")
                            .style(.title3)
                            .foregroundStyle(DS.Colors.Ink.primary)
                        Text("New numbers are the only way to prove new progress.")
                            .style(.foot)
                            .foregroundStyle(DS.Colors.Ink.quaternary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DS.Colors.Ink.quaternary)
                }
            }
        }
        .buttonStyle(PressableButtonStyle())
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s32 - 4)
    }

    // MARK: - Shareable card

    private var shareCard: some View {
        let proof = self.proof
        return MFShareCard(eyebrow: "Proof of Progress") {
            VStack(spacing: DS.Spacing.s16) {
                Text(ShareText.firstName(profile.displayName))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))

                HStack(spacing: 0) {
                    shareStat("\(proof.testsImproved)", "Improved")
                    shareStat("\(proof.tiersClimbed)", "Tiers Up")
                    shareStat("\(proof.testsWithData)", "PBs")
                }

                Text("Tracked on the MF Combine.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.vertical, DS.Spacing.s8)
        }
    }

    private func shareStat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 40, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(.white)
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }

    private func exportAndShare() {
        guard !isExporting else { return }
        isExporting = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let image = ShareCardRenderer.render(shareCard)
        isExporting = false
        if let image { shareImage = ShareableImage(image: image) }
    }
}

// MARK: - Sparkline

/// A minimal monotonic line chart drawn from pre-normalized 0...1 goodness values.
/// Always climbs left→right as the player improves, matching the proof narrative.
private struct ProgressSparkline: View {
    let goodness: [CGFloat]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let count = max(1, goodness.count - 1)

            ZStack(alignment: .bottomLeading) {
                // Baseline track.
                Rectangle()
                    .fill(DS.Colors.Line.hairline)
                    .frame(height: 1)

                linePath(w: w, h: h, count: count)
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                // End-point marker.
                if let last = goodness.last {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 6, height: 6)
                        .position(x: w, y: h - last * h)
                }
            }
        }
    }

    private func linePath(w: CGFloat, h: CGFloat, count: Int) -> Path {
        Path { path in
            for (index, value) in goodness.enumerated() {
                let x = w * CGFloat(index) / CGFloat(count)
                let y = h - value * h
                if index == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ProofOfProgressView()
    }
    .preferredColorScheme(.dark)
    .modelContainer(for: [CombineTest.self, CombineResult.self])
}
