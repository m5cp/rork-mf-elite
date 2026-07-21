//
//  DrillScoreSection.swift
//  MFElite
//
//  Combine-style score tracking embedded in the drill detail page: log a
//  numeric score for this drill, see best / latest / attempts, and a trend
//  chart over time. Append-only history, synced like combine results.
//

import SwiftUI
import SwiftData
import Charts

struct DrillScoreSection: View {
    let drillID: String
    let drillTitle: String

    @Environment(\.modelContext) private var modelContext
    @Query private var allResults: [DrillResult]
    @State private var showEntry = false

    private var history: [DrillResult] {
        allResults
            .filter { $0.drillID == drillID }
            .sorted { $0.recordedAt < $1.recordedAt }
    }

    /// Higher is treated as better for drill scores (reps, goals, touches).
    private var best: Double? { history.map(\.value).max() }
    private var latest: DrillResult? { history.last }
    private var unit: String { latest?.unit ?? "" }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s16) {
            HStack {
                SectionHead(title: "Score tracker")
                Spacer()
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showEntry = true
                } label: {
                    Label("Log score", systemImage: "plus.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DS.Colors.Gold.base)
                }
                .buttonStyle(PressableButtonStyle())
            }

            if history.isEmpty {
                Text("Log a score after a set — juggles, reps, cone time — and track your progress here over time.")
                    .style(.foot)
                    .foregroundStyle(DS.Colors.Ink.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                HStack(spacing: 0) {
                    scoreStat(label: "BEST", value: format(best))
                    Divider().frame(height: 32).overlay(DS.Colors.Line.subtle)
                    scoreStat(label: "LATEST", value: format(latest?.value))
                    Divider().frame(height: 32).overlay(DS.Colors.Line.subtle)
                    scoreStat(label: "ATTEMPTS", value: "\(history.count)")
                }
                .padding(.vertical, DS.Spacing.s12)
                .background(DS.Colors.Bg.raised, in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))

                if history.count >= 2 {
                    Chart(history, id: \.id) { result in
                        LineMark(
                            x: .value("Date", result.recordedAt),
                            y: .value("Score", result.value)
                        )
                        .foregroundStyle(DS.Colors.Gold.base)
                        .interpolationMethod(.monotone)
                        PointMark(
                            x: .value("Date", result.recordedAt),
                            y: .value("Score", result.value)
                        )
                        .foregroundStyle(result.value == best ? DS.Colors.Gold.textLight : DS.Colors.Gold.base)
                    }
                    .chartYAxis { AxisMarks(position: .trailing) }
                    .frame(height: 140)
                }
            }
        }
        .sheet(isPresented: $showEntry) {
            DrillScoreEntrySheet(drillID: drillID, drillTitle: drillTitle, lastUnit: unit)
                .presentationDetents([.height(340)])
        }
    }

    private func scoreStat(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(DS.Typography.num(size: 22))
                .foregroundStyle(DS.Colors.Ink.primary)
            Text(label)
                .style(.micro)
                .foregroundStyle(DS.Colors.Ink.quaternary)
        }
        .frame(maxWidth: .infinity)
    }

    private func format(_ value: Double?) -> String {
        guard let value else { return "—" }
        let text = value.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(value))
            : String(format: "%.1f", value)
        return unit.isEmpty ? text : "\(text) \(unit)"
    }
}

// MARK: - Entry sheet

struct DrillScoreEntrySheet: View {
    let drillID: String
    let drillTitle: String
    var lastUnit: String = ""

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var valueText = ""
    @State private var unit = ""
    @FocusState private var valueFocused: Bool

    private static let unitOptions = ["reps", "seconds", "goals", "touches", "meters"]

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s16) {
            Eyebrow(text: "Log score")
            Text(drillTitle)
                .style(.title3)
                .foregroundStyle(DS.Colors.Ink.primary)
                .lineLimit(2)

            TextField("Score", text: $valueText)
                .keyboardType(.decimalPad)
                .focused($valueFocused)
                .font(DS.Typography.num(size: 34))
                .foregroundStyle(DS.Colors.Ink.primary)
                .padding(DS.Spacing.s16)
                .background(DS.Colors.Bg.raised, in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.s8) {
                    ForEach(Self.unitOptions, id: \.self) { option in
                        Button {
                            unit = (unit == option) ? "" : option
                        } label: {
                            Text(option.uppercased())
                                .style(.micro)
                                .foregroundStyle(unit == option ? DS.Colors.Gold.inkOnGold : DS.Colors.Ink.secondary)
                                .padding(.horizontal, 12).padding(.vertical, 7)
                                .background(
                                    unit == option ? AnyShapeStyle(DS.Colors.Gold.base) : AnyShapeStyle(DS.Colors.Bg.raised),
                                    in: Capsule()
                                )
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                }
            }

            PrimaryButton(label: "Save score") { save() }
                .disabled(Double(valueText) == nil)
        }
        .padding(DS.Spacing.s20)
        .background(DS.Colors.Bg.base)
        .onAppear {
            unit = lastUnit
            valueFocused = true
        }
    }

    private func save() {
        guard let value = Double(valueText) else { return }
        let result = DrillResult(drillID: drillID, value: value, unit: unit)
        modelContext.insert(result)
        try? modelContext.save()
        SyncEngine.shared.enqueueDrillResult(result)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}
