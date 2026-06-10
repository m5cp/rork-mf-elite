//
//  OnboardingIdentifyView.swift
//  MFElite
//
//  Step 2 — Identify: photo header, editorial underline name input, and the
//  graduation class year.
//

import SwiftUI

struct OnboardingIdentifyView: View {
    let state: OnboardingState

    @State private var name: String = ""
    @State private var classYear: Int? = nil
    @State private var birthYear: Int? = nil
    @FocusState private var nameFocused: Bool

    /// Sensible birth-year window for youth athletes through adults.
    private var birthYearRange: ClosedRange<Int> {
        let currentYear = Calendar.current.component(.year, from: Date())
        return (currentYear - 99)...(currentYear - 4)
    }

    private var canContinue: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && classYear != nil && birthYear != nil
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                photoHeader

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Enter your name.")
                            .font(.system(size: 44, weight: .heavy))
                            .tracking(-1.6)
                            .foregroundStyle(DS.Colors.Ink.primary)
                            .padding(.top, DS.Spacing.s16)

                        UnderlineField(placeholder: "Your name", text: $name, fontSize: 32, maxLength: 28)
                            .focused($nameFocused)
                            .submitLabel(.done)
                            .padding(.top, DS.Spacing.s20)

                        HStack {
                            Spacer()
                            Text("\(name.count)/28")
                                .style(.microSm)
                                .foregroundStyle(DS.Colors.Ink.quaternary)
                        }
                        .padding(.top, DS.Spacing.s8)

                        Text("This name appears on your player card and in your reports.")
                            .style(.foot)
                            .foregroundStyle(DS.Colors.Ink.tertiary)
                            .padding(.top, DS.Spacing.s8)

                        Eyebrow(text: "Class Year")
                            .padding(.top, DS.Spacing.s24)

                        YearPickerField(year: $classYear)
                            .padding(.top, DS.Spacing.s8)

                        Text("The year you graduate (or graduated) high school.")
                            .style(.foot)
                            .foregroundStyle(DS.Colors.Ink.tertiary)
                            .padding(.top, DS.Spacing.s8)

                        Eyebrow(text: "Birth Year")
                            .padding(.top, DS.Spacing.s24)

                        YearPickerField(year: $birthYear, range: birthYearRange, defaultYear: OnboardingState.defaultBirthYear)
                            .padding(.top, DS.Spacing.s8)

                        Text("Used to tailor age-appropriate guidance and to set up family safety controls.")
                            .style(.foot)
                            .foregroundStyle(DS.Colors.Ink.tertiary)
                            .padding(.top, DS.Spacing.s8)
                    }
                    .padding(.horizontal, DS.Spacing.s20)
                    .padding(.bottom, DS.Spacing.s24)
                }
                .scrollIndicators(.hidden)
                .keyboardDoneButton { nameFocused = false }

                footer
            }
        }
        .onAppear {
            name = state.playerName
            classYear = state.classYear
            birthYear = state.birthYear
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { nameFocused = true }
        }
    }

    private var photoHeader: some View {
        PhotoPlaceholder(height: 188, label: "ATHLETE · ROOM TONE")
            .clipShape(Rectangle())
            .overlay(
                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.5), location: 0),
                        .init(color: .clear, location: 0.28),
                        .init(color: .clear, location: 0.6),
                        .init(color: .black, location: 1)
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: DS.Spacing.s12) {
                    Image("mf-logo-white")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 20)
                        .accessibilityLabel("MF Elite")
                    ChapterEyebrow(number: 1, label: "Identify")
                }
                .padding(.horizontal, DS.Spacing.s20)
                .padding(.top, 56)
            }
            .ignoresSafeArea(edges: .top)
    }

    private var footer: some View {
        VStack(spacing: DS.Spacing.s16) {
            PrimaryButton(label: "Continue") {
                state.playerName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                state.classYear = classYear
                state.birthYear = birthYear
                state.advance()
            }
            .opacity(canContinue ? 1 : 0.4)
            .disabled(!canContinue)
            StepBar(filled: 2, total: OnboardingStep.stepTotal)
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.bottom, DS.Spacing.s24)
    }
}

#Preview {
    OnboardingIdentifyView(state: OnboardingState())
}
