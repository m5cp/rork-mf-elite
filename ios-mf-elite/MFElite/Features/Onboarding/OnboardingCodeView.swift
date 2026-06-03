//
//  OnboardingCodeView.swift
//  MFElite
//

import SwiftUI

struct OnboardingCodeView: View {
    let state: OnboardingState

    @FocusState private var focused: Bool
    @State private var code: String = ""
    @State private var shake: CGFloat = 0
    @State private var errored = false
    @State private var showNoCodeAlert = false

    private let length = 6
    private let validCodes: Set<String> = ["MFELITE", "INVITE", "ACADEMY"]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.s12) {
                    Eyebrow(text: "Step 1 of 6")
                    Text("The Code")
                        .style(.hero)
                        .foregroundStyle(DS.Colors.Ink.primary)
                    Text("Enter the invite code from your coach to begin your academy journey.")
                        .style(.body)
                        .foregroundStyle(DS.Colors.Ink.secondary)

                    boxes
                        .padding(.top, DS.Spacing.s32)
                        .offset(x: shake)
                        .onTapGesture { focused = true }
                }
                .padding(.horizontal, DS.Spacing.s20)
                .padding(.top, DS.Spacing.s48)
            }

            VStack(spacing: DS.Spacing.s8) {
                PrimaryButton(label: "Verify code") { verify() }
                GhostButton(label: "I don't have a code") { showNoCodeAlert = true }
            }
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.bottom, DS.Spacing.s24)
        }
        .background(
            // Hidden field driving the boxes.
            TextField("", text: $code)
                .focused($focused)
                .keyboardType(.asciiCapable)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .opacity(0)
                .frame(width: 0, height: 0)
                .onChange(of: code) { _, newValue in
                    let filtered = String(newValue.uppercased().prefix(length))
                        .filter { $0.isLetter || $0.isNumber }
                    if filtered != newValue { code = filtered }
                    if errored { errored = false }
                }
        )
        .onAppear { focused = true }
        .alert("Need an invite?", isPresented: $showNoCodeAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Contact your coach or academy for an invite code.")
        }
    }

    private var boxes: some View {
        HStack(spacing: DS.Spacing.s8) {
            ForEach(0..<length, id: \.self) { index in
                charBox(at: index)
            }
        }
    }

    private func charBox(at index: Int) -> some View {
        let chars = Array(code)
        let isActive = index == chars.count && focused
        let char = index < chars.count ? String(chars[index]) : ""
        let borderColor: Color = errored ? Color(hex: "#FF4D4D")
            : isActive ? DS.Colors.Line.strong
            : DS.Colors.Line.hairline

        return Text(char)
            .style(.title1)
            .foregroundStyle(DS.Colors.Ink.primary)
            .frame(width: 44, height: 52)
            .background(DS.Colors.Bg.card)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.sm)
                    .stroke(borderColor, lineWidth: isActive ? 1.5 : 1)
            )
            .animation(DS.Motion.fastDuration == 0 ? nil : .easeOut(duration: 0.15), value: isActive)
    }

    private func verify() {
        let entered = code.trimmingCharacters(in: .whitespaces)
        // MVP: accept any 6-character code (or known invite words).
        if entered.count == length || validCodes.contains(entered) {
            state.inviteCode = entered
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            state.advance()
        } else {
            fail()
        }
    }

    private func fail() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        errored = true
        withAnimation(.default) {}
        let baseAnimation = Animation.linear(duration: 0.07)
        withAnimation(baseAnimation) { shake = -10 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.07) {
            withAnimation(baseAnimation) { shake = 10 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.07) {
                withAnimation(baseAnimation) { shake = -6 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.07) {
                    withAnimation(baseAnimation) { shake = 0 }
                }
            }
        }
    }
}

#Preview {
    OnboardingCodeView(state: OnboardingState())
        .background(DS.Colors.Bg.base)
}
