//
//  SettingsView.swift
//  MFElite
//
//  Minimal settings screen — currently the gateway to the coach workspace.
//

import SwiftUI
import SwiftData

struct SettingsRoute: Hashable {}

struct SettingsView: View {
    @State private var showCoachLogin = false
    @State private var showRedeemCode = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: DS.Spacing.s8) {
                    Eyebrow(text: "Settings")
                    Text("Settings")
                        .style(.hero)
                        .foregroundStyle(DS.Colors.Ink.primary)
                }
                .padding(.horizontal, DS.Spacing.s20)
                .padding(.top, DS.Spacing.s24)

                VStack(spacing: 0) {
                    Button {
                        showRedeemCode = true
                    } label: {
                        settingsRow(icon: "ticket", label: "Redeem a code")
                    }
                    .buttonStyle(PressableButtonStyle())

                    Hairline()

                    Button {
                        showCoachLogin = true
                    } label: {
                        settingsRow(icon: "lock.shield", label: "Coach workspace")
                    }
                    .buttonStyle(PressableButtonStyle())
                }
                .padding(.horizontal, DS.Spacing.s20)
                .padding(.top, DS.Spacing.s32)
            }
            .padding(.bottom, 120)
        }
        .background(DS.Colors.Bg.base)
        .scrollIndicators(.hidden)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showCoachLogin) {
            CoachLoginView()
        }
        .sheet(isPresented: $showRedeemCode) {
            RedeemCodeView()
        }
    }

    private func settingsRow(icon: String, label: String) -> some View {
        HStack(spacing: DS.Spacing.s16) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(DS.Colors.Ink.primary)
                .frame(width: 36, height: 36)
                .background(DS.Colors.Bg.raised)
                .clipShape(Circle())
            Text(label)
                .style(.title3)
                .foregroundStyle(DS.Colors.Ink.primary)
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DS.Colors.Ink.quaternary)
        }
        .padding(.vertical, DS.Spacing.s16)
        .contentShape(Rectangle())
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .preferredColorScheme(.dark)
    .modelContainer(for: [
        Discipline.self, Category.self, MasteryLevel.self,
        Drill.self, DrillProgress.self, PlayerState.self
    ])
}
