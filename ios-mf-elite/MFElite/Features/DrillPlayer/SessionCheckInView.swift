//
//  SessionCheckInView.swift
//  MFElite
//
//  A short, friendly post-session check-in: a 1–5 "how did that feel?" rating
//  and an optional one-line reflection. Captured once per completed session and
//  saved onto the session's log entries so effort builds a personal history and
//  can quietly inform the adaptive daily plan.
//

import SwiftUI
import SwiftData

/// How a finished session felt, captured as a 1 (brutal) – 5 (easy) rating.
enum SessionFeel: Int, CaseIterable, Identifiable {
    case brutal = 1
    case tough = 2
    case solid = 3
    case smooth = 4
    case easy = 5

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .brutal: return "Brutal"
        case .tough:  return "Tough"
        case .solid:  return "Solid"
        case .smooth: return "Smooth"
        case .easy:   return "Easy"
        }
    }

    var symbol: String {
        switch self {
        case .brutal: return "flame.fill"
        case .tough:  return "bolt.fill"
        case .solid:  return "checkmark"
        case .smooth: return "hand.thumbsup.fill"
        case .easy:   return "sparkles"
        }
    }
}

struct SessionCheckInView: View {
    /// Submitted with the chosen rating (1–5) and a trimmed reflection (nil if empty).
    var onSubmit: (Int, String?) -> Void
    var onSkip: () -> Void

    @State private var selected: SessionFeel?
    @State private var note: String = ""
    @FocusState private var noteFocused: Bool

    private var trimmedNote: String? {
        let t = note.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.s24) {
                VStack(alignment: .leading, spacing: DS.Spacing.s8) {
                    Eyebrow(text: "Quick check-in")
                    Text("How did that feel?")
                        .style(.title1)
                        .foregroundStyle(DS.Colors.Ink.primary)
                    Text("Your honest read keeps tomorrow's plan dialed in.")
                        .style(.body)
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                feelPicker

                VStack(alignment: .leading, spacing: DS.Spacing.s8) {
                    Eyebrow(text: "Reflection — optional")
                    TextField(
                        "",
                        text: $note,
                        prompt: Text("What clicked, or what to work on next…")
                            .foregroundColor(DS.Colors.Ink.disabled),
                        axis: .vertical
                    )
                    .lineLimit(2...4)
                    .style(.body)
                    .foregroundStyle(DS.Colors.Ink.primary)
                    .focused($noteFocused)
                    .padding(DS.Spacing.s16)
                    .background(DS.Colors.Bg.elevated)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.md)
                            .stroke(noteFocused ? DS.Colors.Line.strong : DS.Colors.Line.hairline, lineWidth: 1)
                    )
                }

                VStack(spacing: DS.Spacing.s12) {
                    PrimaryButton(label: "Save reflection") {
                        guard let selected else { return }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onSubmit(selected.rawValue, trimmedNote)
                    }
                    .opacity(selected == nil ? 0.45 : 1)
                    .disabled(selected == nil)

                    GhostButton(label: "Skip") { onSkip() }
                }
            }
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.top, DS.Spacing.s24)
            .padding(.bottom, DS.Spacing.s32)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .background(DS.Colors.Bg.base)
    }

    private var feelPicker: some View {
        HStack(spacing: DS.Spacing.s8) {
            ForEach(SessionFeel.allCases) { feel in
                let isOn = selected == feel
                Button {
                    UISelectionFeedbackGenerator().selectionChanged()
                    withAnimation(DS.Motion.standardSpring) { selected = feel }
                } label: {
                    VStack(spacing: DS.Spacing.s8) {
                        Image(systemName: feel.symbol)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(isOn ? DS.Colors.Ground.primary : DS.Colors.Ink.secondary)
                            .frame(width: 44, height: 44)
                            .background(isOn ? Color.white : DS.Colors.Bg.elevated)
                            .clipShape(Circle())
                            .overlay(
                                Circle().stroke(
                                    isOn ? Color.clear : DS.Colors.Line.hairline,
                                    lineWidth: 1
                                )
                            )
                        Text(feel.label)
                            .style(.microSm)
                            .foregroundStyle(isOn ? DS.Colors.Ink.primary : DS.Colors.Ink.quaternary)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel("\(feel.label) — \(feel.rawValue) of 5")
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
    }
}

// MARK: - Reusable sheet modifier

private struct SessionCheckInModifier: ViewModifier {
    @Binding var isPresented: Bool
    let drillCount: Int
    @Environment(\.modelContext) private var modelContext

    func body(content: Content) -> some View {
        content.sheet(isPresented: $isPresented) {
            SessionCheckInView(
                onSubmit: { rating, note in
                    QuickLog.attachReflection(
                        rating: rating,
                        note: note,
                        toMostRecent: drillCount,
                        context: modelContext
                    )
                    isPresented = false
                },
                onSkip: { isPresented = false }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }
}

extension View {
    /// Presents the post-session check-in sheet, persisting the rating/reflection
    /// onto the `drillCount` most recently logged drills when submitted.
    func sessionCheckIn(isPresented: Binding<Bool>, drillCount: Int) -> some View {
        modifier(SessionCheckInModifier(isPresented: isPresented, drillCount: drillCount))
    }
}

#Preview {
    SessionCheckInView(onSubmit: { _, _ in }, onSkip: {})
        .preferredColorScheme(.dark)
}
