//
//  JoinTeamView.swift
//  MFElite
//
//  Lets a signed-in player redeem a coach's roster invite code, merging the
//  coach's pre-filled name/kit/position into their existing profile. Entirely
//  optional — the app works fully without ever joining a team. Requires
//  sign-in since redemption runs against the player's Supabase account.
//

import SwiftUI

struct JoinTeamView: View {
    @Environment(\.dismiss) private var dismiss

    private var profile = PlayerProfileStore.shared
    private var auth = SupabaseAuth.shared

    @FocusState private var focused: Bool
    @State private var code: String = ""
    @State private var isRedeeming = false
    @State private var status: Status = .idle

    private let length = ProfileValidation.inviteCodeLength

    private enum Status: Equatable {
        case idle
        case success
        case error(String)
    }

    private var canRedeem: Bool {
        ProfileValidation.isInviteCodeValid(code) && !isRedeeming
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.s24) {
                    VStack(alignment: .leading, spacing: DS.Spacing.s8) {
                        Eyebrow(text: "Coach Invite")
                        Text("Join a Team")
                            .style(.title1)
                            .foregroundStyle(DS.Colors.Ink.primary)
                        Text("Got a code from your coach or academy? Enter it below to link your profile and pull in your squad details.")
                            .style(.callout)
                            .foregroundStyle(DS.Colors.Ink.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if auth.isSignedIn {
                        codeField
                        if case let .error(message) = status {
                            Text(message)
                                .style(.foot)
                                .foregroundStyle(Color(hex: "#FF5A5A"))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if status == .success {
                            HStack(spacing: DS.Spacing.s8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(DS.Colors.Ink.primary)
                                Text("Joined! Your squad details are linked.")
                                    .style(.callout)
                                    .foregroundStyle(DS.Colors.Ink.secondary)
                            }
                        }
                        PrimaryButton(label: isRedeeming ? "Joining…" : "Join team") {
                            redeem()
                        }
                        .opacity(canRedeem ? 1 : 0.5)
                        .disabled(!canRedeem)
                    } else {
                        Text("Sign in with Apple first (from Settings → Sync) to join a coach's team.")
                            .style(.callout)
                            .foregroundStyle(DS.Colors.Ink.tertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(DS.Spacing.s20)
            }
            .background(DS.Colors.Bg.base)
            .scrollIndicators(.hidden)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(DS.Colors.Ink.secondary)
                }
            }
        }
    }

    private var codeField: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s8) {
            Eyebrow(text: "Invite code")
            TextField("", text: $code, prompt: Text("e.g. 4X9K2M").foregroundColor(DS.Colors.Ink.quaternary))
                .font(.system(size: 28, weight: .heavy, design: .monospaced))
                .tracking(4)
                .foregroundStyle(DS.Colors.Ink.primary)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .focused($focused)
                .onChange(of: code) { _, newValue in
                    code = ProfileValidation.normalizedInviteCode(newValue)
                }
                .padding(DS.Spacing.s16)
                .frame(height: 64)
                .background(DS.Colors.Bg.card)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(DS.Colors.Line.hairline, lineWidth: 1))
        }
        .onAppear { focused = true }
    }

    private func redeem() {
        guard canRedeem else { return }
        isRedeeming = true
        status = .idle
        Task {
            let merged = await Self.redeemInvite(code: code)
            isRedeeming = false
            switch merged {
            case .success:
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                status = .success
                try? await Task.sleep(for: .seconds(1))
                dismiss()
            case .failure(let message):
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                status = .error(message)
            }
        }
    }

    private enum RedeemOutcome {
        case success
        case failure(String)
    }

    /// Call the `redeem_roster_invite` RPC and merge any returned fields into
    /// the local profile. Fails soft with a friendly message.
    private static func redeemInvite(code: String) async -> RedeemOutcome {
        let normalized = ProfileValidation.normalizedInviteCode(code)
        guard let data = await SupabaseClient.shared.rpcData(
            "redeem_roster_invite",
            params: ["invite_code": normalized]
        ) else {
            return .failure("That code didn't work. Check it and try again.")
        }
        guard let row = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return .failure("That code didn't work. Check it and try again.")
        }
        let profile = PlayerProfileStore.shared
        if let name = row["display_name"] as? String, !name.isEmpty {
            profile.displayName = name
        }
        if let kit = row["kit_number"] as? String, !kit.isEmpty {
            profile.kitNumber = kit
        }
        if let position = row["position"] as? String, !position.isEmpty {
            profile.position = position
        }
        return .success
    }
}

#Preview {
    JoinTeamView()
        .preferredColorScheme(.dark)
}
