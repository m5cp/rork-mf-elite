//
//  CoachAIBriefingView.swift
//  MFElite
//
//  Coach-only, on-device AI briefings: a weekly team briefing, a per-rostered-
//  player summary, and a plain-language app-activity overview. Runs locally via
//  Apple Intelligence; on unsupported devices a clean data-built summary shows.
//

import SwiftUI
import SwiftData

struct CoachAIBriefingRoute: Hashable {}

struct CoachAIBriefingView: View {
    @Bindable var model: CoachViewModel
    @Environment(\.modelContext) private var modelContext

    @State private var kind: CoachBriefingKind = .team
    @State private var selectedPlayer: RosterPlayer?
    @State private var output = ""
    @State private var isGenerating = false
    @State private var copied = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.s20) {
                intro
                Picker("Briefing", selection: $kind) {
                    ForEach(CoachBriefingKind.allCases) { k in
                        Text(k.title).tag(k)
                    }
                }
                .pickerStyle(.segmented)

                if kind == .player { playerPicker }

                if let reason = CoachAIBriefing.unavailableReason {
                    noticeBanner(reason)
                }

                generateButton
                if !output.isEmpty { outputCard }
            }
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.top, DS.Spacing.s16)
            .padding(.bottom, 120)
        }
        .background(DS.Colors.Bg.base)
        .scrollIndicators(.hidden)
        .navigationTitle("AI Briefing")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: kind) { _, _ in output = "" }
        .onChange(of: selectedPlayer) { _, _ in output = "" }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s4) {
            Text("Private, on-device insights")
                .style(.title2)
                .foregroundStyle(DS.Colors.Ink.primary)
            Text("Generated on your iPhone using Apple Intelligence — nothing about a player ever leaves your device.")
                .style(.foot)
                .foregroundStyle(DS.Colors.Ink.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var playerPicker: some View {
        Menu {
            ForEach(model.roster) { player in
                Button(player.displayName) { selectedPlayer = player }
            }
        } label: {
            HStack(spacing: DS.Spacing.s12) {
                SectionIcon(systemName: "person.crop.circle", size: 36)
                Text(selectedPlayer?.displayName ?? "Choose a player")
                    .style(.title3)
                    .foregroundStyle(selectedPlayer == nil ? DS.Colors.Ink.tertiary : DS.Colors.Ink.primary)
                Spacer(minLength: 0)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DS.Colors.Ink.quaternary)
            }
            .padding(DS.Spacing.s16)
            .frame(maxWidth: .infinity)
            .background(DS.Colors.Bg.card)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(DS.Colors.Line.hairline, lineWidth: 1))
        }
    }

    private func noticeBanner(_ text: String) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.s8) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DS.Colors.Ink.tertiary)
            Text(text)
                .style(.micro)
                .foregroundStyle(DS.Colors.Ink.tertiary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(DS.Spacing.s12)
        .background(DS.Colors.Bg.card)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(DS.Colors.Line.hairline, lineWidth: 1))
    }

    private var generateButton: some View {
        Button {
            Task { await generate() }
        } label: {
            HStack(spacing: DS.Spacing.s8) {
                if isGenerating {
                    ProgressView().controlSize(.small).tint(DS.Colors.Ground.primary)
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: 15, weight: .bold))
                }
                Text(isGenerating ? "Thinking…" : (output.isEmpty ? "Generate briefing" : "Regenerate"))
                    .font(.system(size: 15, weight: .bold))
            }
            .foregroundStyle(DS.Colors.Ground.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color.white)
            .clipShape(Capsule())
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(isGenerating || (kind == .player && selectedPlayer == nil))
        .opacity((kind == .player && selectedPlayer == nil) ? 0.5 : 1)
    }

    private var outputCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s12) {
            Card(padding: DS.Spacing.s16) {
                Text(output)
                    .style(.body)
                    .foregroundStyle(DS.Colors.Ink.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Button {
                UIPasteboard.general.string = output
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                copied = true
                Task { try? await Task.sleep(for: .seconds(2)); copied = false }
            } label: {
                HStack(spacing: DS.Spacing.s8) {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 14, weight: .semibold))
                    Text(copied ? "Copied" : "Copy")
                        .style(.foot)
                        .fontWeight(.semibold)
                    Spacer(minLength: 0)
                }
                .foregroundStyle(DS.Colors.Ink.primary)
                .padding(DS.Spacing.s12)
                .frame(maxWidth: .infinity)
                .background(DS.Colors.Bg.card)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(DS.Colors.Line.hairline, lineWidth: 1))
            }
            .buttonStyle(PressableButtonStyle())
        }
    }

    private func generate() async {
        isGenerating = true
        output = ""
        switch kind {
        case .team:
            output = await CoachAIBriefing.teamBriefing(model: model)
        case .app:
            output = await CoachAIBriefing.appOverview(model: model)
        case .player:
            if let player = selectedPlayer {
                await model.loadDetail(for: player, context: modelContext)
                if let detail = model.detailCache[player.id] {
                    output = await CoachAIBriefing.playerSummary(name: player.displayName, detail: detail)
                } else {
                    output = "Couldn't load \(ShareText.firstName(player.displayName))'s data. Pull to refresh their profile and try again."
                }
            }
        }
        isGenerating = false
    }
}
