//
//  JoinTeamView.swift
//  MFElite
//
//  Player-side sheet to join a coach's roster by entering an invite code. Calls
//  the `redeem_roster_invite` RPC, which links the player to the coach and makes
//  sure their player_profiles row exists. The player's own training is untouched.
//

import SwiftUI

struct JoinTeamView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var code = ""
    @State private var isWorking = false
    @State private var message: String?
    @State private var joined = false

    /// Shortest code the coach admin ever hands out.
    private var isCodeComplete: Bool {
        code.trimmingCharacters(in: .whitespaces).count >= 4
    }

    private var canJoin: Bool {
        isCodeComplete && !isWorking && !joined
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.s20) {
                    Text("Enter the code your coach gave you to join their team. Your training stays yours \u{2014} this just links you to their roster.")
                        .style(.foot)
                        .foregroundStyle(DS.Colors.Ink.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    TextField("CODE", text: $code)
                        .font(.system(size: 28, weight: .heavy, design: .monospaced))
                        .tracking(6)
                        .multilineTextAlignment(.center)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .foregroundStyle(DS.Colors.Ink.primary)
                        .onChange(of: code) { _, v in
                            code = String(v.uppercased().filter { $0.isLetter || $0.isNumber }.prefix(8))
                        }
                        .padding(DS.Spacing.s16)
                        .frame(maxWidth: .infinity)
                        .background(DS.Colors.Bg.card)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.md)
                                .stroke(DS.Colors.Line.hairline, lineWidth: 1)
                        )
                        // A code read off a coach's whiteboard is typed blind in
                        // all-caps; the only feedback used to be the Join button
                        // silently un-greying at the bottom of the sheet. The mark
                        // sits where the eyes already are.
                        .overlay(alignment: .trailing) {
                            ConfirmBadge(
                                isConfirmed: isCodeComplete,
                                label: joined ? "Joined" : "Ready",
                                unconfirmedLabel: "Code incomplete"
                            )
                            .padding(.trailing, DS.Spacing.s12)
                        }

                    if let message {
                        Text(message)
                            .style(.foot)
                            .foregroundStyle(joined ? Color(hex: "#3DD68C") : Color(hex: "#FF5A5F"))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    PrimaryButton(label: isWorking ? "Joining\u{2026}" : (joined ? "Joined \u{2713}" : "Join team")) {
                        join()
                    }
                    .disabled(!canJoin)
                }
                .padding(DS.Spacing.s20)
            }
            .background(DS.Colors.Bg.base)
            .scrollIndicators(.hidden)
            .navigationTitle("Join a Team")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func join() {
        guard SupabaseAuth.shared.isSignedIn else {
            message = "Sign in first (Profile \u{2192} Sign in) so we can add you to the roster."
            return
        }
        isWorking = true
        message = nil
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            let ok = await SupabaseClient.shared.rpc("redeem_roster_invite", params: ["invite_code": trimmed])
            isWorking = false
            if ok {
                joined = true
                message = "You\u{2019}re on the team! Your coach can now see your progress."
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                await SupabaseAuth.shared.syncPlayerProfile()
            } else {
                message = "That code isn\u{2019}t valid or has already been used. Double-check with your coach."
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }
}
