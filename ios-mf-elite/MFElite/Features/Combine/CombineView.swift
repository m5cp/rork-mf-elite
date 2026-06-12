//
//  CombineView.swift
//  MFElite
//
//  The MF Combine hub: a baseline skills test split into TECHNICAL and PHYSICAL
//  events. Each row shows the player's personal best and latest attempt; tapping
//  starts that test's flow. When all 8 tests are recorded on the same day a
//  "Combine complete" scorecard is offered.
//

import SwiftUI
import SwiftData

/// Navigation route into the MF Combine hub.
struct CombineRoute: Hashable {}

struct CombineView: View {
    @Query(sort: \CombineTest.sortIndex) private var tests: [CombineTest]
    @Query private var results: [CombineResult]

    @State private var activeTest: CombineTest?
    @State private var showScorecard = false

    private var technical: [CombineTest] { tests.filter { $0.category == "technical" } }
    private var physical: [CombineTest] { tests.filter { $0.category == "physical" } }

    private var isComplete: Bool {
        CombineStats.combineComplete(tests: tests, results: results)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header

                if isComplete {
                    completeBanner
                }

                section(title: "Technical", eyebrow: "5 Tests", tests: technical)
                section(title: "Physical", eyebrow: "3 Tests", tests: physical)
            }
            .padding(.bottom, 120)
        }
        .background(DS.Colors.Bg.base)
        .scrollIndicators(.hidden)
        .navigationTitle("MF Combine")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $activeTest) { test in
            CombineTestFlowView(test: test)
        }
        .sheet(isPresented: $showScorecard) {
            CombineScorecardView(tests: tests, results: results)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s8) {
            Eyebrow(text: "MF Combine")
            Text("Baseline test")
                .style(.title1)
                .foregroundStyle(DS.Colors.Ink.primary)
            Text("Measure where you stand today. Re-test anytime — every attempt is kept so you can watch the numbers move.")
                .style(.callout)
                .foregroundStyle(DS.Colors.Ink.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s20)
    }

    // MARK: - Complete banner

    private var completeBanner: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            showScorecard = true
        } label: {
            Card(raised: true) {
                HStack(spacing: DS.Spacing.s16) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(DS.Colors.Ink.primary)
                    VStack(alignment: .leading, spacing: DS.Spacing.s4) {
                        Eyebrow(text: "Combine Complete")
                        Text("See today's scorecard")
                            .style(.title3)
                            .foregroundStyle(DS.Colors.Ink.primary)
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
        .padding(.top, DS.Spacing.s20)
    }

    // MARK: - Section

    private func section(title: String, eyebrow: String, tests sectionTests: [CombineTest]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHead(eyebrow: eyebrow, title: title)
                .padding(.bottom, DS.Spacing.s4)

            ForEach(Array(sectionTests.enumerated()), id: \.element.id) { index, test in
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    activeTest = test
                } label: {
                    row(for: test)
                }
                .buttonStyle(PressableButtonStyle())

                if index != sectionTests.count - 1 {
                    Hairline()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s32 - 4)
    }

    private func row(for test: CombineTest) -> some View {
        let best = CombineStats.personalBest(test, results: results)
        let latest = CombineStats.latest(test.id, results: results)
        return HStack(spacing: DS.Spacing.s16) {
            VStack(alignment: .leading, spacing: DS.Spacing.s4) {
                Text(test.name)
                    .style(.title3)
                    .foregroundStyle(DS.Colors.Ink.primary)
                if let latest {
                    Text("Last \(CombineFormat.value(latest.value, unit: test.unit)) \(test.unit) · \(CombineFormat.relative(latest.recordedAt))")
                        .style(.foot)
                        .foregroundStyle(DS.Colors.Ink.quaternary)
                } else {
                    Text("Not tested yet · \(test.unit)")
                        .style(.foot)
                        .foregroundStyle(DS.Colors.Ink.quaternary)
                }
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 2) {
                if let best {
                    Text(CombineFormat.value(best, unit: test.unit))
                        .font(DS.Typography.num(size: 22))
                        .foregroundStyle(DS.Colors.Ink.primary)
                    Eyebrow(text: "Best")
                        .foregroundStyle(DS.Colors.Ink.quaternary)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DS.Colors.Ink.quaternary)
                }
            }
        }
        .padding(.vertical, DS.Spacing.s16)
        .contentShape(Rectangle())
    }
}

#Preview {
    NavigationStack {
        CombineView()
    }
    .preferredColorScheme(.dark)
    .modelContainer(for: [CombineTest.self, CombineResult.self])
}
