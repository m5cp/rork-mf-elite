//
//  CoachAnnouncementsView.swift
//  MFElite
//
//  Create and manage announcements shown on the player Today screen.
//

import SwiftUI

struct CoachAnnouncementsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var announcements: [SupabaseAnnouncement] = []
    @State private var title = ""
    @State private var messageBody = ""
    @State private var isLoading = true
    @State private var errorMessage: String?
    @FocusState private var isFocused: Bool

    private var activeCount: Int { announcements.filter(\.active).count }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.s24) {
                    composer
                    list
                }
                .padding(DS.Spacing.s20)
            }
            .background(DS.Colors.Bg.base)
            .scrollIndicators(.hidden)
            .navigationTitle("Announcements")
            .navigationBarTitleDisplayMode(.inline)
            .keyboardDoneButton { isFocused = false }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .tint(DS.Colors.Ink.primary)
                }
            }
            .task { await load() }
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s8) {
            Eyebrow(text: "Create announcement")
            TextField("Title", text: $title)
                .style(.callout)
                .foregroundStyle(DS.Colors.Ink.primary)
                .focused($isFocused)
                .submitLabel(.done)
                .padding(.vertical, DS.Spacing.s12)
                .padding(.horizontal, DS.Spacing.s16)
                .background(DS.Colors.Bg.elevated)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))

            TextField("Body", text: $messageBody, axis: .vertical)
                .lineLimit(2...5)
                .style(.callout)
                .foregroundStyle(DS.Colors.Ink.primary)
                .focused($isFocused)
                .padding(.vertical, DS.Spacing.s12)
                .padding(.horizontal, DS.Spacing.s16)
                .background(DS.Colors.Bg.elevated)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))

            PrimaryButton(label: "Post", size: .medium) { Task { await post() } }
                .opacity(title.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)

            if let errorMessage {
                Text(errorMessage).style(.foot).foregroundStyle(DS.Colors.Ink.secondary)
            }
        }
    }

    @ViewBuilder
    private var list: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s12) {
            HStack {
                Eyebrow(text: "Posted")
                Spacer()
                Eyebrow(text: "\(activeCount) Active", color: DS.Colors.Ink.quaternary)
            }

            if isLoading {
                ProgressView().tint(DS.Colors.Ink.primary).frame(maxWidth: .infinity)
            } else if announcements.isEmpty {
                Text("No announcements yet.")
                    .style(.foot)
                    .foregroundStyle(DS.Colors.Ink.tertiary)
            } else {
                ForEach(announcements) { item in
                    row(item)
                }
            }
        }
    }

    private func row(_ item: SupabaseAnnouncement) -> some View {
        Card {
            VStack(alignment: .leading, spacing: DS.Spacing.s8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: DS.Spacing.s4) {
                        Text(item.title)
                            .style(.title3)
                            .foregroundStyle(DS.Colors.Ink.primary)
                        if let body = item.body, !body.isEmpty {
                            Text(body)
                                .style(.foot)
                                .foregroundStyle(DS.Colors.Ink.tertiary)
                        }
                    }
                    Spacer(minLength: DS.Spacing.s8)
                    Toggle("", isOn: Binding(
                        get: { item.active },
                        set: { newValue in Task { await setActive(item, active: newValue) } }
                    ))
                    .labelsHidden()
                    .tint(.white)
                }

                Button(role: .destructive) {
                    Task { await delete(item) }
                } label: {
                    Text("Delete")
                        .style(.foot)
                        .foregroundStyle(DS.Colors.Ink.secondary)
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
    }

    // MARK: - Data

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            announcements = try await CoachContentService.shared.fetchAnnouncements()
        } catch {
            errorMessage = "Couldn't load announcements."
        }
    }

    private func post() async {
        let cleanTitle = title.trimmingCharacters(in: .whitespaces)
        guard !cleanTitle.isEmpty else { return }
        isFocused = false
        do {
            try await CoachContentService.shared.addAnnouncement(title: cleanTitle, body: messageBody.trimmingCharacters(in: .whitespaces))
            title = ""
            messageBody = ""
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            await load()
        } catch {
            errorMessage = "Couldn't post announcement."
        }
    }

    private func setActive(_ item: SupabaseAnnouncement, active: Bool) async {
        do {
            try await CoachContentService.shared.setAnnouncementActive(id: item.id, active: active)
            await load()
        } catch {
            errorMessage = "Couldn't update announcement."
        }
    }

    private func delete(_ item: SupabaseAnnouncement) async {
        do {
            try await CoachContentService.shared.deleteAnnouncement(id: item.id)
            await load()
        } catch {
            errorMessage = "Couldn't delete announcement."
        }
    }
}
