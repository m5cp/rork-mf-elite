//
//  AnnouncementComposerView.swift
//  MFElite
//
//  Coach composer for a team announcement: a short title and a longer body
//  (location, time, details). On send it hands the values back so the caller
//  can publish them and share the same text to a team chat.
//

import SwiftUI

struct AnnouncementComposerView: View {
    let onSend: (String, String, BroadcastAudience) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var message = ""
    @State private var audience = BroadcastAudience()

    private var canSend: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && audience.isValid
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.s20) {
                    field(
                        label: "Title",
                        prompt: "Practice moved",
                        text: $title,
                        axis: .horizontal
                    )

                    VStack(alignment: .leading, spacing: DS.Spacing.s8) {
                        Eyebrow(text: "Message")
                        TextField(
                            "",
                            text: $message,
                            prompt: Text("Location, time, details…")
                                .foregroundColor(DS.Colors.Ink.quaternary),
                            axis: .vertical
                        )
                        .lineLimit(4...10)
                        .style(.body)
                        .foregroundStyle(DS.Colors.Ink.primary)
                        .padding(DS.Spacing.s16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(DS.Colors.Bg.card)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                        .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(DS.Colors.Line.hairline, lineWidth: 1))
                    }

                    AudiencePickerSection(audience: $audience)

                    Text("The athletes you send this to see it on their Today screen, and you can post the same text to your team chat in one tap.")
                        .style(.foot)
                        .foregroundStyle(DS.Colors.Ink.quaternary)

                    PrimaryButton(label: "Send & share") {
                        guard canSend else { return }
                        onSend(title, message, audience)
                        dismiss()
                    }
                    .opacity(canSend ? 1 : 0.5)
                    .disabled(!canSend)
                }
                .padding(DS.Spacing.s20)
            }
            .background(DS.Colors.Bg.base)
            .scrollIndicators(.hidden)
            .navigationTitle("New Announcement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(DS.Colors.Ink.secondary)
                }
            }
        }
    }

    private func field(label: String, prompt: String, text: Binding<String>, axis: Axis) -> some View {
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
}

/// One announcement row in the coach's manage list with an active toggle.
struct CoachAnnouncementRow: View {
    let announcement: TeamAnnouncement
    let onToggleActive: (Bool) -> Void

    var body: some View {
        HStack(spacing: DS.Spacing.s12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(announcement.title)
                    .style(.title3)
                    .foregroundStyle(DS.Colors.Ink.primary)
                    .lineLimit(1)
                Text(subtitle)
                    .style(.micro)
                    .foregroundStyle(DS.Colors.Ink.tertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: DS.Spacing.s8)
            Toggle("", isOn: Binding(
                get: { announcement.active },
                set: { newValue in
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onToggleActive(newValue)
                }
            ))
            .labelsHidden()
            .tint(DS.Colors.Ink.primary)
        }
        .padding(DS.Spacing.s12)
        .background(DS.Colors.Bg.card)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(DS.Colors.Line.hairline, lineWidth: 1))
        .opacity(announcement.active ? 1 : 0.6)
    }

    private var subtitle: String {
        let status = announcement.active ? "Active" : "Inactive"
        return "\(status) · \(CoachFormat.shortDate(announcement.createdAt))"
    }
}
