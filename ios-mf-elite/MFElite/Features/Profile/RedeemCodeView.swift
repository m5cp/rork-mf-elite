//
//  RedeemCodeView.swift
//  MFElite
//
//  Optional, post-onboarding "Redeem code" screen — the standard place a player
//  can enter a coach invite code if they were given one. Redeeming merges the
//  coach's pre-filled name / kit / position into the player's existing profile
//  while keeping their own username. Entirely optional; never gates entry.
//

import SwiftUI

struct RedeemCodeView: View {
    @Environment(\.dismiss) private var dismiss

    private var profile = PlayerProfileStore.shared

    @FocusState private var focused: Bool
    @State private var code: String = ""
    @State private var shake: CGFloat = 0
    @State private var status: Status = .idle

    private let length = 6

    private enum Status: Equatable {
        case idle
        case working
        case success
        case error(String)
    }

    private var canRedeem: Bool {
        code.trimmingCharacters(in: .whitespaces).count == length && status != .working
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: DS.Spacing.s12) {
                        Eyebrow(text: "Coach invite")
                        Text("Redeem a Code")
                            .style(.hero)
                            .foregroundStyle(DS.Colors.Ink.primary)
                        Text("Got a code from your coach or academy? Enter it to link your profile and pull in your squad details. This is optional.")
                            .style(.body)
                            .foregroundStyle(DS.Colors.Ink.secondary)

                        boxes
                            .padding(.top, DS.Spacing.s32)
                            .offset(x: shake)
                            .onTapGesture { focused = true }

                        statusRow
                            .padding(.top, DS.Spacing.s12)
                    }
                    .padding(.horizontal, DS.Spacing.s20)
                    .padding(.top, DS.Spacing.s24)
                }

                PrimaryButton(label: status == .success ? "Done" : "Redeem code") {
                    if status == .success { dismiss() } else { redeem() }
                }
                .opacity(canRedeem || status == .success ? 1 : 0.4)
                .disabled(!canRedeem && status != .success)
                .padding(.horizontal, DS.Spacing.s20)
                .padding(.bottom, DS.Spacing.s24)
            }
            .background(DS.Colors.Bg.base)
            .scrollIndicators(.hidden)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(DS.Colors.Ink.secondary)
                }
            }
            .background(
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
                        if case .error = status { status = .idle }
                    }
            )
            .onAppear { focused = true }
        }
        .preferredColorScheme(.dark)
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
        let isErrored = { if case .error = status { return true } else { return false } }()
        let borderColor: Color = isErrored ? Color(hex: "#FF4D4D")
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
            .animation(.easeOut(duration: 0.15), value: isActive)
    }

    @ViewBuilder
    private var statusRow: some View {
        switch status {
        case .idle:
            Text("6 characters · letters and numbers")
                .style(.foot)
                .foregroundStyle(DS.Colors.Ink.tertiary)
        case .working:
            HStack(spacing: DS.Spacing.s8) {
                ProgressView().controlSize(.small).tint(DS.Colors.Ink.tertiary)
                Text("Linking your profile…")
                    .style(.foot)
                    .foregroundStyle(DS.Colors.Ink.tertiary)
            }
        case .success:
            label(icon: "checkmark.circle.fill", text: "Code redeemed — your squad details are linked.", color: Color(hex: "#34C759"))
        case .error(let message):
            label(icon: "exclamationmark.circle.fill", text: message, color: Color(hex: "#FF4D4D"))
        }
    }

    private func label(icon: String, text: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.s8) {
            Image(systemName: icon).foregroundStyle(color)
            Text(text).style(.foot).foregroundStyle(color)
        }
    }

    private func redeem() {
        focused = false
        status = .working
        let entered = code.trimmingCharacters(in: .whitespaces)

        Task {
            // Best-effort sign-in so the redemption attaches to the player's account.
            if !AuthService.shared.isAuthenticated {
                await AuthService.shared.signInWithApple()
            }

            do {
                let row = try await ProfileService.shared.redeemInvite(code: entered)
                profile.applyRosterMerge(
                    name: row.displayName,
                    kit: row.kitNumber,
                    position: row.position
                )
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                status = .success
            } catch {
                let message = (error as? ProfileService.ClaimError)?.errorDescription
                    ?? "That code didn't work. Check it and try again."
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                status = .error(message)
                fail()
            }
        }
    }

    private func fail() {
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
    RedeemCodeView()
        .preferredColorScheme(.dark)
}
