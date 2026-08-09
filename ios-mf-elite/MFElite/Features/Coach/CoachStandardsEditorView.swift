//
//  CoachStandardsEditorView.swift
//  MFElite
//
//  Head-coach editor for the MF Combine baseline: which tests make up the
//  academy's baseline test, and the target number expected at each age group.
//  The published male/female scales stay on screen next to every field so the
//  coach can always see the standard he is choosing to deviate from.
//
//  Writes go straight to Supabase through `CoachStandardsStore` and are
//  audit-logged. RLS refuses a non-head-coach write, so the gate below is about
//  not offering a screen where every save would come back "not allowed".
//

import SwiftUI
import SwiftData

/// True only for the head coach — the whole editor is gated on this, the same
/// way every Control Center surface is.
private var isHeadCoach: Bool {
    SubscriptionService.shared.coachRole == "head_coach"
}

/// Navigation route into the baseline standards editor.
struct CoachStandardsRoute: Hashable {}

struct CoachStandardsEditorView: View {
    @Query(sort: \CombineTest.sortIndex) private var tests: [CombineTest]

    @State private var store = CoachStandardsStore.shared
    /// The age group being edited. Seeded to U12 and corrected on appear if the
    /// bundled benchmark file ever ships a different set of bands.
    @State private var bandID: String = "U12"
    /// In-progress text per test for the selected age group, so a half-typed
    /// number is never written and switching age groups reloads cleanly.
    @State private var drafts: [String: String] = [:]
    @State private var savingTestID: String?

    @FocusState private var focusedTestID: String?

    private var bands: [CombineBenchmarks.AgeBand] { CombineBenchmarks.shared.ageBands }

    private var selectedBand: CombineBenchmarks.AgeBand? {
        bands.first(where: { $0.id == bandID })
    }

    private var baselineTests: [CombineTest] { store.baseline(from: tests) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.s32) {
                header

                if isHeadCoach {
                    baselineSection
                    targetsSection
                } else {
                    lockedCard
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.top, DS.Spacing.s24)
            .padding(.bottom, DS.tabBarClearance + DS.Spacing.s32)
        }
        .background(DS.Colors.Bg.base)
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Baseline Standards")
        .navigationBarTitleDisplayMode(.inline)
        .keyboardDoneButton { focusedTestID = nil }
        .task {
            await store.refreshIfStale()
            // Drafts are also loaded in onAppear so cached values paint
            // instantly — but on a device with no cache that runs BEFORE the
            // store resolves, leaving the coach's existing targets looking
            // unset next to a row that says "Your target".
            loadDrafts()
        }
        .onAppear {
            if !bands.contains(where: { $0.id == bandID }) {
                bandID = bands.first?.id ?? ""
            }
            loadDrafts()
        }
        .onChange(of: bandID) { _, _ in loadDrafts() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s8) {
            Eyebrow(text: "Head Coach")
            Text("Baseline Standards")
                .style(.title1)
                .foregroundStyle(DS.Colors.Ink.primary)
            Text("Choose the tests that make up your baseline, then set the number you expect at each age group. Anything you leave unset keeps the published standard.")
                .style(.callout)
                .foregroundStyle(DS.Colors.Ink.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var lockedCard: some View {
        Card {
            VStack(alignment: .leading, spacing: DS.Spacing.s8) {
                Eyebrow(text: "Head Coach Only")
                Text("Only a head coach can change the baseline every player is measured against.")
                    .style(.foot)
                    .foregroundStyle(DS.Colors.Ink.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Baseline selection

    private var baselineSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s12) {
            SectionHead(
                eyebrow: "\(baselineTests.count) of \(tests.count) selected",
                title: "The Baseline"
            )

            Text("A test you switch off stays available for players to run on its own — it just stops counting toward a completed combine.")
                .style(.foot)
                .foregroundStyle(DS.Colors.Ink.tertiary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: DS.Spacing.s8) {
                ForEach(tests, id: \.id) { test in
                    baselineRow(test)
                }
            }
        }
    }

    private func baselineRow(_ test: CombineTest) -> some View {
        let included = store.isInBaseline(test.id)
        return HStack(spacing: DS.Spacing.s12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(test.name)
                    .style(.title3)
                    .foregroundStyle(DS.Colors.Ink.primary)
                    .lineLimit(1)
                Text("\(test.category) · \(test.unit)")
                    .style(.micro)
                    .foregroundStyle(DS.Colors.Ink.tertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: DS.Spacing.s8)

            Toggle("", isOn: Binding(
                get: { store.isInBaseline(test.id) },
                set: { newValue in
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    Task { await store.setIncluded(testID: test.id, included: newValue) }
                }
            ))
            .labelsHidden()
            .tint(DS.Colors.Ink.primary)
        }
        .padding(DS.Spacing.s12)
        .background(DS.Colors.Bg.card)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .stroke(DS.Colors.Line.hairline, lineWidth: 1)
        )
        .opacity(included ? 1 : 0.6)
    }

    // MARK: - Targets by age group

    private var targetsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s12) {
            SectionHead(eyebrow: "By Age Group", title: "Your Targets")

            bandPicker

            if let selectedBand {
                Text(selectedBand.label)
                    .style(.foot)
                    .foregroundStyle(DS.Colors.Ink.secondary)
            }

            if baselineTests.isEmpty {
                Text("Switch a test back on above to set a target for it.")
                    .style(.foot)
                    .foregroundStyle(DS.Colors.Ink.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: DS.Spacing.s12) {
                    ForEach(baselineTests, id: \.id) { test in
                        targetRow(test)
                    }
                }
            }

            Text("A player is measured against your number for their age group. Where you haven't set one, the published boys/girls standard for that age group is used instead — both stay visible on the player's card.")
                .style(.micro)
                .foregroundStyle(DS.Colors.Ink.quaternary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, DS.Spacing.s4)
        }
    }

    private var bandPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.s8) {
                ForEach(bands, id: \.id) { band in
                    Chip(label: band.id, active: band.id == bandID) {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        bandID = band.id
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func targetRow(_ test: CombineTest) -> some View {
        let coach = store.coachTarget(testID: test.id, bandID: bandID)
        let maleDefault = store.defaultTarget(testID: test.id, bandID: bandID, female: false)
        let femaleDefault = store.defaultTarget(testID: test.id, bandID: bandID, female: true)

        return VStack(alignment: .leading, spacing: DS.Spacing.s8) {
            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.s8) {
                Text(test.name)
                    .style(.title3)
                    .foregroundStyle(DS.Colors.Ink.primary)
                    .lineLimit(1)
                Spacer(minLength: DS.Spacing.s8)
                Text(coach == nil ? "Standard" : "Your target")
                    .style(.microSm)
                    .foregroundStyle(coach == nil ? DS.Colors.Ink.quaternary : DS.Colors.Ink.primary)
            }

            Text(standardCaption(male: maleDefault, female: femaleDefault, unit: test.unit))
                .style(.micro)
                .foregroundStyle(DS.Colors.Ink.quaternary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: DS.Spacing.s12) {
                TextField("—", text: draftBinding(test))
                    .keyboardType(.decimalPad)
                    .focused($focusedTestID, equals: test.id)
                    .font(DS.Typography.num(size: 20))
                    .foregroundStyle(DS.Colors.Ink.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, DS.Spacing.s12)
                    .padding(.vertical, DS.Spacing.s8)
                    .background(DS.Colors.Bg.elevated)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.sm)
                            .stroke(focusedTestID == test.id ? DS.Colors.Line.strong : DS.Colors.Line.subtle,
                                    lineWidth: 1)
                    )

                Text(test.unit)
                    .style(.foot)
                    .foregroundStyle(DS.Colors.Ink.tertiary)
                    .lineLimit(1)
            }

            HStack(spacing: DS.Spacing.s16) {
                if isDirty(test) {
                    Button("Save") { save(test) }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(DS.Colors.Ink.primary)
                        .disabled(savingTestID == test.id)
                        .opacity(savingTestID == test.id ? 0.5 : 1)
                }
                if coach != nil {
                    Button("Use standard") { clear(test) }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                }
                Spacer(minLength: 0)
            }
            .frame(height: 22)
        }
        .padding(DS.Spacing.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.Colors.Bg.card)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .stroke(DS.Colors.Line.hairline, lineWidth: 1)
        )
    }

    /// The published numbers for this test and age group, shown so the coach can
    /// see what he is deviating from before he types over it.
    private func standardCaption(male: Double?, female: Double?, unit: String) -> String {
        guard let male, let female else {
            return "No published standard for this test — set your own."
        }
        return "Standard · Boys \(CombineFormat.value(male, unit: unit)) · Girls \(CombineFormat.value(female, unit: unit)) \(unit)"
    }

    // MARK: - Draft editing

    private func draftBinding(_ test: CombineTest) -> Binding<String> {
        Binding(
            get: { drafts[test.id] ?? "" },
            set: { drafts[test.id] = $0 }
        )
    }

    private func loadDrafts() {
        var fresh: [String: String] = [:]
        for test in tests {
            if let value = store.coachTarget(testID: test.id, bandID: bandID) {
                fresh[test.id] = CombineFormat.value(value, unit: test.unit)
            } else {
                fresh[test.id] = ""
            }
        }
        drafts = fresh
    }

    /// Whether the field holds a usable number that differs from what is saved.
    /// An empty field is not dirty — clearing a target is "Use standard", not a
    /// blank save, so a coach can't wipe a number by tapping into the field.
    private func isDirty(_ test: CombineTest) -> Bool {
        let text = (drafts[test.id] ?? "").trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, let value = parsed(text) else { return false }
        guard let current = store.coachTarget(testID: test.id, bandID: bandID) else { return true }
        return abs(value - current) > 0.0001
    }

    /// Same bounds the player-facing score entry uses, so a mistyped target can
    /// never be stored as a number no athlete could ever reach.
    private func parsed(_ text: String) -> Double? {
        guard let value = Double(text.trimmingCharacters(in: .whitespaces)),
              value > 0, value.isFinite, value < 1_000_000 else { return nil }
        return value
    }

    private func save(_ test: CombineTest) {
        guard let typed = parsed(drafts[test.id] ?? "") else { return }
        focusedTestID = nil
        savingTestID = test.id
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let testID = test.id
        // Store the number at the precision the app displays it. Saving 3.605 on
        // a timed event and rendering it back as "3.60" would leave the field
        // permanently one edit away from what's saved, so Save would never go
        // away.
        let display = CombineFormat.value(typed, unit: test.unit)
        let value = Double(display) ?? typed
        let band = bandID
        Task {
            let ok = await store.setTarget(testID: testID, bandID: band, value: value)
            savingTestID = nil
            if ok, band == bandID {
                drafts[testID] = display
            }
        }
    }

    private func clear(_ test: CombineTest) {
        focusedTestID = nil
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let testID = test.id
        let band = bandID
        Task {
            let ok = await store.clearTarget(testID: testID, bandID: band)
            if ok, band == bandID {
                drafts[testID] = ""
            }
        }
    }
}
