//
//  CoachQuotesView.swift
//  MFElite
//
//  Manage the daily motivation quotes shown on the player Today screen.
//

import SwiftUI

struct CoachQuotesView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var quotes: [SupabaseQuote] = []
    @State private var draft = ""
    @State private var isLoading = true
    @State private var errorMessage: String?
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                composer
                quoteList
            }
            .background(DS.Colors.Bg.base)
            .navigationTitle("Daily Quotes")
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
            HStack {
                Eyebrow(text: "Add quote")
                Spacer()
                Eyebrow(text: "\(quotes.count) In Queue", color: DS.Colors.Ink.quaternary)
            }
            HStack(spacing: DS.Spacing.s8) {
                TextField("New motivation quote", text: $draft, axis: .vertical)
                    .lineLimit(1...3)
                    .style(.callout)
                    .foregroundStyle(DS.Colors.Ink.primary)
                    .focused($isFocused)
                    .padding(.vertical, DS.Spacing.s12)
                    .padding(.horizontal, DS.Spacing.s16)
                    .background(DS.Colors.Bg.elevated)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))

                Button {
                    Task { await addQuote() }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(DS.Colors.Ground.primary)
                        .frame(width: 44, height: 44)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                }
                .buttonStyle(PressableButtonStyle())
                .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(draft.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
                .accessibilityLabel("Add quote")
            }
            if let errorMessage {
                Text(errorMessage).style(.foot).foregroundStyle(DS.Colors.Ink.secondary)
            }
        }
        .padding(DS.Spacing.s20)
    }

    @ViewBuilder
    private var quoteList: some View {
        if isLoading {
            Spacer()
            ProgressView().tint(DS.Colors.Ink.primary)
            Spacer()
        } else if quotes.isEmpty {
            Spacer()
            Text("No quotes yet. Add one above.")
                .style(.foot)
                .foregroundStyle(DS.Colors.Ink.tertiary)
            Spacer()
        } else {
            List {
                ForEach(quotes) { quote in
                    Text(quote.quote)
                        .style(.callout)
                        .foregroundStyle(DS.Colors.Ink.primary)
                        .listRowBackground(DS.Colors.Bg.elevated)
                }
                .onDelete { offsets in
                    Task { await delete(at: offsets) }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(DS.Colors.Bg.base)
        }
    }

    // MARK: - Data

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            quotes = try await CoachContentService.shared.fetchQuotes()
        } catch {
            errorMessage = "Couldn't load quotes."
        }
    }

    private func addQuote() async {
        let text = draft.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        isFocused = false
        do {
            try await CoachContentService.shared.addQuote(text, sortIndex: quotes.count)
            draft = ""
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            await load()
        } catch {
            errorMessage = "Couldn't add quote."
        }
    }

    private func delete(at offsets: IndexSet) async {
        let targets = offsets.map { quotes[$0] }
        for quote in targets {
            try? await CoachContentService.shared.deleteQuote(id: quote.id)
        }
        await load()
    }
}
