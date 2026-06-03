//
//  CoachAddPlayerView.swift
//  MFElite
//
//  Coach form to add a player. Generates a one-time invite code (matching the
//  app's 6-char format) the player redeems on sign-in. All fields run through
//  the same ProfileValidation used by player onboarding.
//

import SwiftUI

struct CoachAddPlayerView: View {
    @Environment(\.dismiss) private var dismiss
    let vm: CoachRosterViewModel

    @State private var name = ""
    @State private var kit = "10"
    @State private var position = "No preference"
    @State private var generatedCode: String?
    @State private var isSaving = false

    private var canSave: Bool { ProfileValidation.isNameValid(name) && !isSaving }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.s24) {
                    if let code = generatedCode {
                        codeResult(code)
                    } else {
                        form
                    }
                }
                .padding(.horizontal, DS.Spacing.s20)
                .padding(.top, DS.Spacing.s20)
                .padding(.bottom, 120)
            }
            .background(DS.Colors.Bg.base)
            .scrollIndicators(.hidden)
            .navigationTitle(generatedCode == nil ? "Add player" : "Invite ready")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(DS.Colors.Ink.primary)
                }
            }
            .overlay(alignment: .bottom) {
                if generatedCode == nil {
                    PrimaryButton(label: isSaving ? "Generating…" : "Generate invite") { save() }
                        .opacity(canSave ? 1 : 0.4)
                        .disabled(!canSave)
                        .padding(.horizontal, DS.Spacing.s20)
                        .padding(.bottom, DS.Spacing.s24)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Form

    private var form: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s20) {
            CoachRosterFields(name: $name, kit: $kit, position: $position)
            Text("A one-time invite code is generated. The player enters it on sign-in and your details merge into their profile. Codes work for subscribed or trial players only.")
                .style(.foot)
                .foregroundStyle(DS.Colors.Ink.tertiary)
        }
    }

    // MARK: - Code result

    private func codeResult(_ code: String) -> some View {
        VStack(spacing: DS.Spacing.s16) {
            Eyebrow(text: "Share with \(ProfileValidation.normalizedName(name))")
            Text(code)
                .font(.system(size: 40, weight: .bold, design: .monospaced))
                .tracking(6)
                .foregroundStyle(DS.Colors.Ink.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.s24)
                .background(DS.Colors.Bg.elevated)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            SecondaryButton(label: "Copy code") {
                UIPasteboard.general.string = code
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
            Text("This code is one-time. The player picks their own unique username when they redeem it.")
                .style(.foot)
                .foregroundStyle(DS.Colors.Ink.tertiary)
                .multilineTextAlignment(.center)
        }
    }

    private func save() {
        guard canSave else { return }
        isSaving = true
        Task {
            let code = await vm.addPlayer(
                name: name, kit: kit, position: position
            ) ?? ProfileValidation.generateInviteCode()
            await MainActor.run {
                generatedCode = code
                isSaving = false
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
    }
}

/// Shared name / kit / position editor used by add + edit.
struct CoachRosterFields: View {
    @Binding var name: String
    @Binding var kit: String
    @Binding var position: String

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s16) {
            field(title: "Player name") {
                TextField("", text: $name,
                          prompt: Text("Full name").foregroundColor(DS.Colors.Ink.quaternary))
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .foregroundStyle(DS.Colors.Ink.primary)
                    .tint(.white)
            }

            field(title: "Kit number") {
                TextField("", text: $kit,
                          prompt: Text("1–99").foregroundColor(DS.Colors.Ink.quaternary))
                    .keyboardType(.numberPad)
                    .foregroundStyle(DS.Colors.Ink.primary)
                    .tint(.white)
                    .onChange(of: kit) { _, newValue in
                        kit = String(newValue.filter(\.isNumber).prefix(2))
                    }
            }

            VStack(alignment: .leading, spacing: DS.Spacing.s8) {
                Eyebrow(text: "Position")
                Picker("Position", selection: $position) {
                    ForEach(ProfileValidation.positions, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.menu)
                .tint(DS.Colors.Ink.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DS.Spacing.s16)
                .frame(height: 52)
                .background(DS.Colors.Bg.elevated)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
            }
        }
    }

    private func field<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s8) {
            Eyebrow(text: title)
            content()
                .frame(height: 52)
                .padding(.horizontal, DS.Spacing.s16)
                .background(DS.Colors.Bg.elevated)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
        }
    }
}

#Preview {
    CoachAddPlayerView(vm: CoachRosterViewModel())
}
