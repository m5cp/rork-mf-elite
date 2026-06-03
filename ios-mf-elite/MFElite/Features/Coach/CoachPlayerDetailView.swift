//
//  CoachPlayerDetailView.swift
//  MFElite
//
//  Coach view of a single player: shareable roster fields (editable) plus a
//  reset action. Shows NO private data — no email, sign-in identity, or billing.
//

import SwiftUI

struct CoachPlayerDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let vm: CoachRosterViewModel
    let player: PlayerProfileRow

    @State private var name: String
    @State private var kit: String
    @State private var position: String
    @State private var isSaving = false
    @State private var showResetConfirm = false

    init(vm: CoachRosterViewModel, player: PlayerProfileRow) {
        self.vm = vm
        self.player = player
        _name = State(initialValue: player.displayName ?? "")
        _kit = State(initialValue: player.kitNumber ?? "10")
        _position = State(initialValue: player.position ?? "No preference")
    }

    private var canSave: Bool { ProfileValidation.isNameValid(name) && !isSaving }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.s24) {
                    identityCard
                    CoachRosterFields(name: $name, kit: $kit, position: $position)
                    privacyNote
                    resetButton
                }
                .padding(.horizontal, DS.Spacing.s20)
                .padding(.top, DS.Spacing.s20)
                .padding(.bottom, 120)
            }
            .background(DS.Colors.Bg.base)
            .scrollIndicators(.hidden)
            .navigationTitle("Player")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(DS.Colors.Ink.primary)
                }
            }
            .overlay(alignment: .bottom) {
                PrimaryButton(label: isSaving ? "Saving…" : "Save changes") { save() }
                    .opacity(canSave ? 1 : 0.4)
                    .disabled(!canSave)
                    .padding(.horizontal, DS.Spacing.s20)
                    .padding(.bottom, DS.Spacing.s24)
            }
            .confirmationDialog("Reset this player's info?",
                                isPresented: $showResetConfirm, titleVisibility: .visible) {
                Button("Reset info", role: .destructive) { reset() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Their name, kit, and position are cleared. Progress and certifications are kept. They'll re-enter details on next launch.")
            }
        }
        .preferredColorScheme(.dark)
    }

    private var identityCard: some View {
        HStack(spacing: DS.Spacing.s16) {
            Avatar(size: 56, initials: player.initials ?? "?")
            VStack(alignment: .leading, spacing: DS.Spacing.s4) {
                Text(player.displayName?.isEmpty == false ? (player.displayName ?? "") : "Unclaimed")
                    .style(.title2)
                    .foregroundStyle(DS.Colors.Ink.primary)
                if let username = player.username, !username.isEmpty {
                    Eyebrow(text: "@\(username) · username locked")
                }
            }
            Spacer(minLength: 0)
        }
    }

    private var privacyNote: some View {
        HStack(spacing: DS.Spacing.s8) {
            Image(systemName: "lock.fill")
                .font(.system(size: 12))
                .foregroundStyle(DS.Colors.Ink.tertiary)
            Text("Email, sign-in identity, and billing are private and never shown here.")
                .style(.microSm)
                .foregroundStyle(DS.Colors.Ink.tertiary)
        }
    }

    private var resetButton: some View {
        Button(role: .destructive) {
            showResetConfirm = true
        } label: {
            Text("Reset player info")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color(hex: "#FF4D4D"))
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.pill)
                        .stroke(Color(hex: "#FF4D4D").opacity(0.4), lineWidth: 1)
                )
        }
        .buttonStyle(PressableButtonStyle())
    }

    private func save() {
        guard canSave else { return }
        isSaving = true
        Task {
            await vm.updatePlayer(player, name: name, kit: kit, position: position)
            await MainActor.run {
                isSaving = false
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                dismiss()
            }
        }
    }

    private func reset() {
        Task {
            await vm.resetPlayer(player)
            await MainActor.run {
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                dismiss()
            }
        }
    }
}

#Preview {
    CoachPlayerDetailView(
        vm: CoachRosterViewModel(),
        player: PlayerProfileRow(
            id: "1", accountId: "1", username: "marcus.b", displayName: "Marcus Bell",
            initials: "MB", kitNumber: "09", position: "Forward", managed: false, isExample: false
        )
    )
}
