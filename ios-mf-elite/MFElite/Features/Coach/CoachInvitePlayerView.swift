//
//  CoachInvitePlayerView.swift
//  MFElite
//
//  Coach-side sheet that generates a join code adding a player to this coach's
//  roster (via the `roster_invites` table). Optional pre-fill (name / kit /
//  position) is stamped onto the invite so the player lands with their details.
//

import SwiftUI

struct CoachInvitePlayerView: View {
    let model: CoachViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var kit = ""
    @State private var position = ""
    @State private var code: String?
    @State private var isWorking = false
    @State private var failed = false
    @State private var shareText: ShareableText?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.s20) {
                    if let code {
                        generated(code)
                    } else {
                        form
                    }
                }
                .padding(DS.Spacing.s20)
            }
            .background(DS.Colors.Bg.base)
            .scrollIndicators(.hidden)
            .navigationTitle("Invite a Player")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .sheet(item: $shareText) { item in
                ShareSheet(items: [item.text])
                    .presentationDetents([.medium, .large])
            }
        }
        .preferredColorScheme(.dark)
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s16) {
            Text("Generate a code and share it with a player. When they enter it under \u{201C}Join a coach\u{2019}s team,\u{201D} they\u{2019}re added to your roster. Pre-fill is optional.")
                .style(.foot)
                .foregroundStyle(DS.Colors.Ink.secondary)
                .fixedSize(horizontal: false, vertical: true)

            field("Player name (optional)") {
                TextField("e.g. Leo", text: $name)
                    .textInputAutocapitalization(.words)
            }
            field("Kit number (optional)") {
                TextField("e.g. 10", text: $kit)
                    .keyboardType(.numberPad)
                    .onChange(of: kit) { _, v in kit = String(v.filter(\.isNumber).prefix(2)) }
            }
            field("Position (optional)") {
                TextField("e.g. ST", text: $position)
                    .textInputAutocapitalization(.characters)
                    .onChange(of: position) { _, v in position = String(v.prefix(4)) }
            }

            PrimaryButton(label: isWorking ? "Generating\u{2026}" : "Generate invite code") {
                generate()
            }
            .disabled(isWorking)

            if failed {
                Text("Couldn\u{2019}t create the code. Check your connection and try again.")
                    .style(.foot)
                    .foregroundStyle(Color(hex: "#FF5A5F"))
            }
        }
    }

    private func generated(_ value: String) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s16) {
            Eyebrow(text: "Share this code")

            Text(value)
                .font(.system(size: 44, weight: .heavy, design: .monospaced))
                .tracking(6)
                .foregroundStyle(DS.Colors.Ink.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.s20)
                .background(DS.Colors.Bg.card)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.md)
                        .stroke(DS.Colors.Line.hairline, lineWidth: 1)
                )

            HStack(spacing: DS.Spacing.s12) {
                Button {
                    UIPasteboard.general.string = value
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                } label: {
                    Text("Copy")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(DS.Colors.Ink.secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(DS.Colors.Bg.raised)
                        .clipShape(Capsule())
                }
                .buttonStyle(PressableButtonStyle())

                PrimaryButton(label: "Share", size: .medium) {
                    shareText = ShareableText(text: "Join my team on MF Elite. Open the app \u{2192} Profile \u{2192} Join a coach\u{2019}s team, and enter code \(value).")
                }
            }

            Button("Create another code") {
                code = nil; name = ""; kit = ""; position = ""; failed = false
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(DS.Colors.Ink.secondary)
            .padding(.top, DS.Spacing.s4)
        }
    }

    private func field<C: View>(_ label: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s8) {
            Eyebrow(text: label)
            content()
                .font(DS.Typography.body)
                .foregroundStyle(DS.Colors.Ink.primary)
                .tint(.white)
                .padding(DS.Spacing.s16)
                .background(DS.Colors.Bg.raised)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func generate() {
        isWorking = true
        failed = false
        Task {
            let result = await model.createRosterInvite(name: name, kit: kit, position: position)
            isWorking = false
            if let result {
                code = result
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } else {
                failed = true
            }
        }
    }
}
