//
//  CombineView.swift
//  MFElite
//
//  The MF Combine hub: a baseline skills test split into TECHNICAL and PHYSICAL
//  events. Each row shows the player's personal best and latest attempt; tapping
//  starts that test's flow. When every test in the head coach's baseline is
//  recorded on the same day a "Combine complete" scorecard is offered.
//
//  The head coach chooses which tests form that baseline. Tests he leaves out
//  are still listed and still runnable — they just don't gate completion — so
//  narrowing the baseline never takes a test away from a player.
//

import SwiftUI
import SwiftData

/// True only for the head coach — the baseline editor entry is gated on this,
/// the same way every Control Center surface is.
private var isHeadCoach: Bool {
    SubscriptionService.shared.coachRole == "head_coach"
}

/// Navigation route into the MF Combine hub.
struct CombineRoute: Hashable {}

/// Navigation route to a single test's full attempt history.
struct CombineHistoryRoute: Hashable {
    let test: CombineTest
}

struct CombineView: View {
    @Query(sort: \CombineTest.sortIndex) private var tests: [CombineTest]
    @Query private var results: [CombineResult]

    @State private var showScorecard = false
    @State private var standards = CoachStandardsStore.shared

    private var technical: [CombineTest] { tests.filter { $0.category == "technical" } }
    private var physical: [CombineTest] { tests.filter { $0.category == "physical" } }

    /// The tests the head coach counts as the baseline. With nothing configured
    /// this is every test, which is exactly how the combine behaved before.
    private var baselineTests: [CombineTest] { standards.baseline(from: tests) }

    private var isComplete: Bool {
        CombineStats.combineComplete(tests: baselineTests, results: results)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header

                if isHeadCoach {
                    editorLink
                }

                if isComplete {
                    completeBanner
                }

                section(title: "Technical", eyebrow: testCount(technical), tests: technical)
                section(title: "Physical", eyebrow: testCount(physical), tests: physical)
            }
            .padding(.bottom, 120)
        }
        .background(DS.Colors.Bg.base)
        .scrollIndicators(.hidden)
        .navigationTitle("MF Combine")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: CombineTest.self) { test in
            CombineTestDetailView(test: test)
        }
        .navigationDestination(for: CombineHistoryRoute.self) { route in
            CombineTestHistoryView(test: route.test)
        }
        .navigationDestination(for: CoachStandardsRoute.self) { _ in
            CoachStandardsEditorView()
        }
        .sheet(isPresented: $showScorecard) {
            // The scorecard grades the baseline, not every test on the list.
            CombineScorecardView(tests: baselineTests, results: results)
        }
        .task { await standards.refreshIfStale() }
    }

    /// "5 Tests", or "3 of 5 Tests" once the coach has taken some out.
    private func testCount(_ sectionTests: [CombineTest]) -> String {
        let included = sectionTests.filter { standards.isInBaseline($0.id) }.count
        if included == sectionTests.count {
            return "\(sectionTests.count) Tests"
        }
        return "\(included) of \(sectionTests.count) Tests"
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s8) {
            ArtworkBanner(name: MFArtwork.combine)
                .padding(.bottom, DS.Spacing.s12)

            Eyebrow(text: "MF Combine")
            Text("Baseline test")
                .style(.title1)
                .foregroundStyle(DS.Colors.Ink.primary)
            Text("Measure where you stand today. Re-test anytime — every attempt is kept so you can watch the numbers move.")
                .style(.callout)
                .foregroundStyle(DS.Colors.Ink.tertiary)
                .fixedSize(horizontal: false, vertical: true)

            if baselineTests.count < tests.count {
                Text("Your coach's baseline is \(baselineTests.count) of these \(tests.count) tests. The rest are still yours to run anytime.")
                    .style(.foot)
                    .foregroundStyle(DS.Colors.Ink.quaternary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s20)
    }

    // MARK: - Head coach entry

    private var editorLink: some View {
        NavigationLink(value: CoachStandardsRoute()) {
            Card {
                HStack(spacing: DS.Spacing.s16) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(DS.Colors.Ink.primary)
                    VStack(alignment: .leading, spacing: DS.Spacing.s4) {
                        Eyebrow(text: "Head Coach")
                        Text("Baseline & targets")
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
        .simultaneousGesture(TapGesture().onEnded {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        })
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
                NavigationLink(value: test) {
                    row(for: test)
                }
                .buttonStyle(PressableButtonStyle())
                .simultaneousGesture(TapGesture().onEnded {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                })

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
                HStack(spacing: DS.Spacing.s8) {
                    Text(test.name)
                        .style(.title3)
                        .foregroundStyle(DS.Colors.Ink.primary)
                    // Only ever shown once the coach has narrowed the baseline,
                    // so the default list is untouched.
                    if !standards.isInBaseline(test.id) {
                        Text("Optional")
                            .style(.microSm)
                            .foregroundStyle(DS.Colors.Ink.quaternary)
                    }
                }
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
