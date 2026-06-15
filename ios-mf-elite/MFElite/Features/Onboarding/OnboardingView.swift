//
//  OnboardingView.swift
//  MFElite
//
//  The cinematic "by invitation → admission" sequence shown to new players.
//  Coordinates the multi-step flow and writes the result to the on-device
//  profile store on completion.
//

import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var state = OnboardingState()
    @State private var isFinishing = false
    @State private var showSkipConfirm = false

    let onComplete: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Group {
                switch state.step {
                case .splash:
                    OnboardingSplashView(state: state)
                case .code:
                    OnboardingCodeView(state: state)
                case .identify:
                    OnboardingIdentifyView(state: state)
                case .position:
                    OnboardingPositionView(state: state)
                case .level:
                    OnboardingLevelView(state: state)
                case .pledge:
                    OnboardingPledgeView(state: state)
                case .account:
                    OnboardingAccountView(state: state)
                case .number:
                    OnboardingNumberView(state: state)
                case .passport:
                    OnboardingPassportView(state: state, isFinishing: isFinishing) {
                        finish()
                    }
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
            .id(state.step)

            if state.step != .splash && !isFinishing {
                skipButton
            }

            if state.canGoBack && !isFinishing {
                backButton
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showSkipConfirm) {
            SkipConfirmSheet(
                onContinue: { showSkipConfirm = false },
                onSkip: {
                    showSkipConfirm = false
                    finish(skipped: true)
                }
            )
            .preferredColorScheme(.dark)
        }
    }

    private var skipButton: some View {
        VStack {
            HStack {
                Spacer()
                Button { showSkipConfirm = true } label: {
                    Text("Skip")
                        .font(.system(size: 13, weight: .semibold))
                        .tracking(0.5)
                        .foregroundStyle(DS.Colors.Ink.quaternary)
                }
                .buttonStyle(PressableButtonStyle())
            }
            Spacer()
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s12)
    }

    private var backButton: some View {
        VStack {
            HStack {
                Button { state.goBack() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(DS.Colors.Ink.secondary)
                        .frame(width: 44, height: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel("Back")
                Spacer()
            }
            Spacer()
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s8)
    }

    private func finish(skipped: Bool = false) {
        guard !isFinishing else { return }
        isFinishing = true

        if skipped { state.applySkipDefaults() }

        // Persist locally — the on-device profile and progress are the only
        // source of truth. Players have no account.
        PlayerProfileStore.shared.complete(
            name: state.playerName.isEmpty ? "Player" : state.playerName,
            username: state.generatedUsername,
            kit: state.kitNumber,
            position: state.positionName,
            positionCode: state.positionCode,
            foot: state.foot,
            classYear: state.classYear ?? 0,
            trainingLevel: state.trainingLevel,
            skipped: skipped
        )

        // Ensure a local PlayerState exists at zero.
        ensurePlayerState()

        // If the player signed in during onboarding, push their now-complete
        // identity to the cloud profile. Fails soft.
        if SupabaseAuth.shared.isSignedIn {
            Task { await SupabaseAuth.shared.syncPlayerProfile() }
        }

        onComplete()
    }

    // MARK: - Skip confirmation

    private struct SkipConfirmSheet: View {
        let onContinue: () -> Void
        let onSkip: () -> Void

        var body: some View {
            VStack(alignment: .leading, spacing: DS.Spacing.s16) {
                Text("Skip setup?")
                    .style(.title3)
                    .foregroundStyle(DS.Colors.Ink.primary)
                    .padding(.top, DS.Spacing.s24)

                Text("You can complete your profile later in Settings.")
                    .style(.body)
                    .foregroundStyle(DS.Colors.Ink.secondary)

                PrimaryButton(label: "Continue setup", action: onContinue)
                    .padding(.top, DS.Spacing.s8)

                GhostButton(label: "Skip for now", action: onSkip)
                    .frame(maxWidth: .infinity)

                Spacer()
            }
            .padding(.horizontal, DS.Spacing.s20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DS.Colors.Bg.base)
            .presentationDetents([.height(280)])
        }
    }

    private func ensurePlayerState() {
        let existing = try? modelContext.fetch(FetchDescriptor<PlayerState>()).first
        if existing == nil {
            modelContext.insert(PlayerState(playerID: UUID().uuidString, xp: 0, streak: 0, freezesRemaining: 0))
            try? modelContext.save()
        }
    }
}
