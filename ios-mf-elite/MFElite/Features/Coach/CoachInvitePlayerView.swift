//
//  CoachInvitePlayerView.swift
//  MFElite
//
//  Lets a coach generate a roster invite code for a new player, optionally
//  pre-filled with a name, kit number, and position. The code is a short,
//  unambiguous 6-character string the player enters during onboarding to
//  join the roster. Fails soft when offline.
//

import SwiftUI

struct CoachInvitePlayerView: View {
    @Bindable var model: CoachViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var kit = ""
    @State private var position = ""
    @State private var isCreating = false
    @State private var generatedCode: String?
    @State private var shareText: ShareableText?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.s20) {
                    if let code = generatedCode {
                        codeCard(code)
                    } else {
                        formFields
                        PrimaryButton(label: isCreating ? "Creating…" : "Create invite code") {
                            createInvite()
                        }
                        .opacity(isCreating ? 0.6 : 1)
                        .disabled(isCreating)
                    }
                }
                .padding(DS.Spacing.s20)
            }
            .background(DS.Colors.Bg.base)
            .scrollIndicators(.hidden)
            .navigationTitle("Invite a Player")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(DS.Colors.Ink.secondary)
                }
            }
            .sheet(item: $shareText) { item in
                ShareSheet(items: [item.text])
                    .presentationDetents([.medium, .large])
            }
        }
    }

    private var formFields: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s16) {
            Text("Generate a one-time code your player enters during sign-up to join your roster. Name, kit, and position are optional — the player can fill them in themselves.")
                .style(.foot)
                .foregroundStyle(DS.Colors.Ink.tertiary)
                .fixedSize(horizontal: false, vertical: true)

            field(label: "Name (optional)", prompt: "Player name", text: $name)
            field(label: "Kit number (optional)", prompt: "e.g. 10", text: $kit)
                .keyboardType(.numberPad)
            field(label: "Position (optional)", prompt: "e.g. ST", text: $position)
        }
    }

    private func field(label: String, prompt: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s8) {
            Eyebrow(text: label)
            TextField("", text: text, prompt: Text(prompt).foregroundColor(DS.Colors.Ink.quaternary))
                .style(.body)
                .foregroundStyle(DS.Colors.Ink.primary)
                .padding(DS.Spacing.s16)
                .frame(height: 52)
                .background(DS.Colors.Bg.card)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(DS.Colors.Line.hairline, lineWidth: 1))
        }
    }

    private func codeCard(_ code: String) -> some View {
        VStack(spacing: DS.Spacing.s20) {
            VStack(spacing: DS.Spacing.s8) {
                Eyebrow(text: "Invite Code")
                Text(code)
                    .font(.system(size: 44, weight: .heavy, design: .monospaced))
                    .tracking(6)
                    .foregroundStyle(DS.Colors.Ink.primary)
                Text("Share this code with your player. They'll enter it during sign-up to join your roster.")
                    .style(.foot)
                    .foregroundStyle(DS.Colors.Ink.tertiary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(DS.Spacing.s24)
            .background(DS.Colors.Bg.card)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(DS.Colors.Line.hairline, lineWidth: 1))

            PrimaryButton(label: "Share code") {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                shareText = ShareableText(text: "Join our team on MF Elite! Use invite code \(code) when you sign up.")
            }

            Button("Done") { dismiss() }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(DS.Colors.Ink.secondary)
        }
    }

    private func createInvite() {
        guard !isCreating else { return }
        isCreating = true
        Task {
            let code = await Self.createRosterInvite(name: name, kit: kit, position: position)
            isCreating = false
            if let code {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                generatedCode = code
            } else {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }

    /// Create a pending roster invite owned by this coach and return its share
    /// code. Optional pre-fill (name / kit / position) is stamped on the invite.
    /// Fails soft, returning nil when offline or not an active coach.
    private static func createRosterInvite(name: String, kit: String, position: String) async -> String? {
        guard let coachID = SupabaseAuth.shared.userID else { return nil }
        let code = generateInviteCode()
        var row: [String: Any] = [
            "code": code,
            "coach_id": coachID,
            "status": "pending"
        ]
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !n.isEmpty { row["display_name"] = n }
        let k = kit.trimmingCharacters(in: .whitespacesAndNewlines)
        if !k.isEmpty { row["kit_number"] = k }
        let p = position.trimmingCharacters(in: .whitespacesAndNewlines)
        if !p.isEmpty { row["position"] = p }
        let ok = await SupabaseClient.shared.insert(table: "roster_invites", values: row)
        return ok ? code : nil
    }

    /// A 6-character invite code using unambiguous characters (no 0/O/1/I).
    private static func generateInviteCode() -> String {
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<6).compactMap { _ in alphabet.randomElement() })
    }
}
