import SwiftUI
import SwiftData

/// The "Generate a Session" sheet: time + focus + level, with a preview, a
/// Regenerate reroll, and a one-tap "Surprise me".
struct GenerateSessionSheet: View {
    /// Called with the chosen drills when the player taps Start.
    let onStart: ([DrillContext]) -> Void

    @Query(sort: \Discipline.sortIndex) private var disciplines: [Discipline]

    @State private var minutes: Int = 10
    @State private var focus: TrainingFocus = .balanced
    @State private var level: TrainingLevelBand = .auto
    @State private var preview: [DrillContext] = []

    private let minuteOptions = [5, 10, 20]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.s20) {
                VStack(alignment: .leading, spacing: DS.Spacing.s8) {
                    Eyebrow(text: "Generate a Session")
                    Text("Build your session")
                        .style(.title1)
                        .foregroundStyle(DS.Colors.Ink.primary)
                }
                .padding(.top, DS.Spacing.s24)

                surpriseButton

                pickerBlock(title: "Time") {
                    chips(minuteOptions.map { ("\($0) MIN", $0 == minutes) }) { idx in
                        minutes = minuteOptions[idx]; regenerate()
                    }
                }

                pickerBlock(title: "Focus") {
                    chips(TrainingFocus.allCases.filter { $0 != .surprise }
                        .map { ($0.label.uppercased(), $0 == focus) }) { idx in
                        focus = TrainingFocus.allCases.filter { $0 != .surprise }[idx]; regenerate()
                    }
                }

                pickerBlock(title: "Level") {
                    chips(TrainingLevelBand.allCases.map { ($0.label.uppercased(), $0 == level) }) { idx in
                        level = TrainingLevelBand.allCases[idx]; regenerate()
                    }
                }

                if !preview.isEmpty {
                    VStack(alignment: .leading, spacing: DS.Spacing.s8) {
                        HStack {
                            Eyebrow(text: "\(preview.count) drills · \(estMinutes) min")
                            Spacer()
                            Button { regenerate() } label: {
                                Label("Regenerate", systemImage: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(DS.Colors.Ink.tertiary)
                            }
                        }
                        ForEach(preview) { ctx in
                            HStack(spacing: DS.Spacing.s12) {
                                DisciplineMark(kind: ctx.discipline.mark, size: 14)
                                Text(ctx.drill.title)
                                    .style(.callout)
                                    .foregroundStyle(DS.Colors.Ink.secondary)
                                Spacer(minLength: 0)
                            }
                            .padding(.vertical, DS.Spacing.s4)
                        }
                    }
                    .padding(DS.Spacing.s16)
                    .background(DS.Colors.Bg.elevated)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                }

                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onStart(preview)
                } label: {
                    Text("Start session")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(DS.Colors.Ground.primary)
                        .frame(maxWidth: .infinity).frame(height: 50)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.pill))
                }
                .buttonStyle(PressableButtonStyle())
                .disabled(preview.isEmpty)
            }
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.bottom, DS.Spacing.s32)
        }
        .scrollIndicators(.hidden)
        .onAppear { if preview.isEmpty { regenerate() } }
    }

    private var estMinutes: Int {
        let s = preview.reduce(0) { $0 + $1.drill.durationSec + max(0, $1.drill.sets - 1) * 15 }
        return max(1, Int((Double(s) / 60).rounded()))
    }

    private func regenerate() {
        preview = SessionGenerator.generate(
            disciplines: disciplines, focus: focus, level: level, budgetSeconds: minutes * 60
        )
    }

    private var surpriseButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            let items = SessionGenerator.generate(
                disciplines: disciplines, focus: .surprise, level: .auto, budgetSeconds: minutes * 60
            )
            onStart(items)
        } label: {
            HStack(spacing: DS.Spacing.s12) {
                Image(systemName: "dice.fill").font(.system(size: 18, weight: .bold))
                Text("Surprise me").font(.system(size: 15, weight: .bold))
                Spacer()
                Image(systemName: "arrow.right").font(.system(size: 14, weight: .bold))
            }
            .foregroundStyle(DS.Colors.Ink.primary)
            .padding(DS.Spacing.s16)
            .frame(maxWidth: .infinity)
            .background(DS.Colors.Bg.raised)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(DS.Colors.Line.hairline, lineWidth: 1))
        }
        .buttonStyle(PressableButtonStyle())
    }

    @ViewBuilder
    private func pickerBlock<Content: View>(title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s8) {
            Eyebrow(text: title)
            content()
        }
    }

    private func chips(_ items: [(String, Bool)], onTap: @escaping (Int) -> Void) -> some View {
        let cols = [GridItem(.adaptive(minimum: 96), spacing: DS.Spacing.s8)]
        return LazyVGrid(columns: cols, alignment: .leading, spacing: DS.Spacing.s8) {
            ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                Button { onTap(idx) } label: {
                    Text(item.0)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(item.1 ? DS.Colors.Ground.primary : DS.Colors.Ink.secondary)
                        .padding(.vertical, DS.Spacing.s8).padding(.horizontal, DS.Spacing.s12)
                        .frame(maxWidth: .infinity)
                        .background(item.1 ? Color.white : DS.Colors.Bg.raised)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                        .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm).stroke(DS.Colors.Line.hairline, lineWidth: 1))
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
    }
}
