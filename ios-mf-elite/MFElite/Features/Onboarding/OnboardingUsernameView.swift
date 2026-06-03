//
//  OnboardingUsernameView.swift
//  MFElite
//
//  Step 3 — claim a unique username. Validates format locally and checks
//  remote availability live, blocking advance until the handle is free.
//

import SwiftUI

struct OnboardingUsernameView: View {
    let state: OnboardingState

    @FocusState private var focused: Bool
    @State private var username: String = ""
    @State private var status: Status = .idle
    @State private var checkTask: Task<Void, Never>?

    private enum Status: Equatable {
        case idle
        case checking
        case available
        case error(String)
    }

    private var trimmed: String { ProfileValidation.normalizedUsername(username) }
    private var canContinue: Bool { status == .available }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.s12) {
                    Eyebrow(text: "Step 2 of 6")
                    Text("Your Handle")
                        .style(.hero)
                        .foregroundStyle(DS.Colors.Ink.primary)
                    Text("Pick a unique username. This is how the academy and your coach identify you.")
                        .style(.body)
                        .foregroundStyle(DS.Colors.Ink.secondary)

                    field
                        .padding(.top, DS.Spacing.s32)

                    statusRow
                        .padding(.top, DS.Spacing.s8)
                }
                .padding(.horizontal, DS.Spacing.s20)
                .padding(.top, DS.Spacing.s48)
            }

            PrimaryButton(label: "Claim handle") {
                state.username = trimmed
                state.advance()
            }
            .opacity(canContinue ? 1 : 0.4)
            .disabled(!canContinue)
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.bottom, DS.Spacing.s24)
        }
        .onAppear {
            username = state.username
            focused = true
            if !username.isEmpty { scheduleCheck() }
        }
        .onDisappear { checkTask?.cancel() }
    }

    private var field: some View {
        HStack(spacing: DS.Spacing.s8) {
            Text("@")
                .font(DS.Typography.title2)
                .foregroundStyle(DS.Colors.Ink.tertiary)
            TextField("", text: $username,
                      prompt: Text("username").foregroundColor(DS.Colors.Ink.quaternary))
                .focused($focused)
                .font(DS.Typography.title2)
                .foregroundStyle(DS.Colors.Ink.primary)
                .tint(.white)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onChange(of: username) { _, newValue in
                    let filtered = String(newValue.filter {
                        $0.isLetter || $0.isNumber || $0 == "_" || $0 == "."
                    }.prefix(ProfileValidation.usernameMaxLength))
                    if filtered != newValue { username = filtered }
                    scheduleCheck()
                }
        }
        .frame(height: 56)
        .padding(.horizontal, DS.Spacing.s20)
        .background(DS.Colors.Bg.elevated)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .stroke(borderColor, lineWidth: 1)
        )
    }

    private var borderColor: Color {
        switch status {
        case .available: return DS.Colors.Line.strong
        case .error: return Color(hex: "#FF4D4D")
        default: return DS.Colors.Line.hairline
        }
    }

    @ViewBuilder
    private var statusRow: some View {
        switch status {
        case .idle:
            Text("3–20 characters · letters, numbers, _ or .")
                .style(.foot)
                .foregroundStyle(DS.Colors.Ink.tertiary)
        case .checking:
            HStack(spacing: DS.Spacing.s8) {
                ProgressView().controlSize(.small).tint(DS.Colors.Ink.tertiary)
                Text("Checking availability…")
                    .style(.foot)
                    .foregroundStyle(DS.Colors.Ink.tertiary)
            }
        case .available:
            label(icon: "checkmark.circle.fill", text: "@\(trimmed) is available", color: Color(hex: "#34C759"))
        case .error(let message):
            label(icon: "exclamationmark.circle.fill", text: message, color: Color(hex: "#FF4D4D"))
        }
    }

    private func label(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: DS.Spacing.s8) {
            Image(systemName: icon).foregroundStyle(color)
            Text(text).style(.foot).foregroundStyle(color)
        }
    }

    /// Debounced format + remote availability check.
    private func scheduleCheck() {
        checkTask?.cancel()
        let candidate = trimmed
        if let formatError = ProfileValidation.validateUsernameFormat(candidate) {
            status = candidate.isEmpty ? .idle : .error(formatError.localizedDescription ?? "Invalid username")
            return
        }
        status = .checking
        checkTask = Task {
            try? await Task.sleep(for: .milliseconds(450))
            if Task.isCancelled { return }
            let available = await ProfileService.shared.isUsernameAvailable(candidate)
            if Task.isCancelled || candidate != trimmed { return }
            status = available
                ? .available
                : .error(ProfileValidation.UsernameError.taken.localizedDescription ?? "Taken")
        }
    }
}

#Preview {
    OnboardingUsernameView(state: OnboardingState())
        .background(DS.Colors.Bg.base)
}
