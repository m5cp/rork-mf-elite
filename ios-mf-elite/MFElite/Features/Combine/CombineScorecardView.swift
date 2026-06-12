//
//  CombineScorecardView.swift
//  MFElite
//
//  Shown once every combine test has a result recorded on the same day. Lists
//  each test with today's value and the delta versus the player's previous
//  attempt (green improved / neutral same / red declined — remembering a smaller
//  number is an improvement for timed events). Exports as a shareable image.
//

import SwiftUI

struct CombineScorecardView: View {
    let tests: [CombineTest]
    let results: [CombineResult]

    @Environment(\.dismiss) private var dismiss
    @State private var shareImage: ShareableImage?
    @State private var isExporting = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.s24) {
                    scorecard
                        .raisedElevation()
                        .padding(.top, DS.Spacing.s8)

                    PrimaryButton(label: isExporting ? "Preparing…" : "Share scorecard") {
                        exportAndShare()
                    }
                    .padding(.horizontal, DS.Spacing.s8)
                }
                .padding(.horizontal, DS.Spacing.s20)
                .padding(.bottom, DS.Spacing.s32)
            }
            .background(DS.Colors.Bg.base)
            .scrollIndicators(.hidden)
            .navigationTitle("Combine Scorecard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(DS.Colors.Ink.primary)
                }
            }
            .sheet(item: $shareImage) { item in
                ShareSheet(items: [item.image])
                    .presentationDetents([.medium, .large])
            }
        }
    }

    // MARK: - Rows

    /// One row per test: today's value and a delta vs the previous attempt.
    private struct ScoreRow: Identifiable {
        let id: String
        let name: String
        let unit: String
        let todayText: String
        let deltaText: String?
        let delta: CombineDelta?
    }

    private var rows: [ScoreRow] {
        let calendar = Calendar.current
        return tests.sorted { $0.sortIndex < $1.sortIndex }.compactMap { test in
            let testResults = results
                .filter { $0.testID == test.id }
                .sorted { $0.recordedAt < $1.recordedAt }

            guard let today = testResults.last(where: { calendar.isDateInToday($0.recordedAt) }) else {
                return nil
            }

            // The most recent attempt strictly before today's recorded value.
            let previous = testResults.last(where: { $0.recordedAt < today.recordedAt })

            var deltaText: String?
            var delta: CombineDelta?
            if let previous {
                delta = CombineStats.delta(today.value, previous: previous.value, test: test)
                let diff = abs(today.value - previous.value)
                if diff > 0 {
                    deltaText = CombineFormat.value(diff, unit: test.unit)
                }
            }

            return ScoreRow(
                id: test.id,
                name: test.name,
                unit: test.unit,
                todayText: CombineFormat.value(today.value, unit: test.unit),
                deltaText: deltaText,
                delta: delta
            )
        }
    }

    // MARK: - Scorecard (renderable, light theme)

    private var scorecard: some View {
        VStack(spacing: DS.Spacing.s20) {
            Image("mf-logo-black")
                .resizable()
                .scaledToFit()
                .frame(height: 26)

            VStack(spacing: DS.Spacing.s4) {
                Text("MF Combine")
                    .font(.system(size: 13, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(.black.opacity(0.45))
                Text("Combine Complete")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.black)
                Text(Date(), format: .dateTime.month(.wide).day().year())
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.5))
            }

            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    scoreRowView(row)
                    if index != rows.count - 1 {
                        Rectangle()
                            .fill(.black.opacity(0.08))
                            .frame(height: 1)
                    }
                }
            }

            Text("Scan your progress in MF Elite.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.black.opacity(0.45))
        }
        .padding(DS.Spacing.s24)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 28))
    }

    private func scoreRowView(_ row: ScoreRow) -> some View {
        HStack(spacing: DS.Spacing.s12) {
            VStack(alignment: .leading, spacing: 1) {
                Text(row.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.black)
                Text(row.unit)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.black.opacity(0.4))
            }

            Spacer(minLength: 0)

            Text(row.todayText)
                .font(.system(size: 20, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(.black)

            deltaBadge(row)
                .frame(width: 64, alignment: .trailing)
        }
        .padding(.vertical, DS.Spacing.s12)
    }

    @ViewBuilder
    private func deltaBadge(_ row: ScoreRow) -> some View {
        if let delta = row.delta {
            HStack(spacing: 2) {
                Image(systemName: deltaSymbol(delta))
                    .font(.system(size: 10, weight: .bold))
                if let deltaText = row.deltaText {
                    Text(deltaText)
                        .font(.system(size: 13, weight: .bold))
                        .monospacedDigit()
                }
            }
            .foregroundStyle(deltaColor(delta))
        } else {
            Text("NEW")
                .font(.system(size: 11, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(.black.opacity(0.4))
        }
    }

    private func deltaSymbol(_ delta: CombineDelta) -> String {
        switch delta {
        case .improved: return "arrow.up.right"
        case .same:     return "minus"
        case .declined: return "arrow.down.right"
        }
    }

    /// Solid, print-safe colors for the light scorecard.
    private func deltaColor(_ delta: CombineDelta) -> Color {
        switch delta {
        case .improved: return Color(hex: "#15A05A")
        case .same:     return .black.opacity(0.4)
        case .declined: return Color(hex: "#D23B3B")
        }
    }

    // MARK: - Share

    private func exportAndShare() {
        guard !isExporting else { return }
        isExporting = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let renderer = ImageRenderer(content: scorecard.frame(width: 360))
        renderer.scale = 3
        renderer.isOpaque = true
        isExporting = false
        if let image = renderer.uiImage {
            shareImage = ShareableImage(image: image)
        }
    }
}
