//
//  OnboardingView.swift
//  MFElite
//
//  The cinematic "by invitation → admission" sequence shown to new players.
//  Coordinates the multi-step flow and writes the result to the profile store,
//  Supabase, and (best-effort) Sign in with Apple on completion.
//

import SwiftUI
import SwiftData
import Supabase

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
                case .signIn:
                    OnboardingSignInView(
                        state: state,
                        onContinueAsPlayer: { state.advance() },
                        onAuthenticated: { handleAuthenticated() }
                    )
                case .identify:
                    OnboardingIdentifyView(state: state)
                case .position:
                    OnboardingPositionView(state: state)
                case .pledge:
                    OnboardingPledgeView(state: state)
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

            if state.step != .splash && state.step != .signIn && !isFinishing {
                skipButton
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

    /// After a coach sign-in: recognized coaches skip the player setup entirely
    /// and go straight to the academy. Anyone not on the coaches list simply
    /// continues as a regular player.
    private func handleAuthenticated() {
        if AuthService.shared.isCoach {
            finishAsCoach()
        } else {
            state.advance()
        }
    }

    /// Minimal coach completion: store a lightweight profile (no kit/position/
    /// pledge needed) and enter the academy with full access.
    private func finishAsCoach() {
        guard !isFinishing else { return }
        isFinishing = true

        let coachName = AuthService.shared.coachDisplayName
            ?? AuthService.shared.user?.name
            ?? "Coach"
        PlayerProfileStore.shared.complete(
            name: coachName,
            username: AuthService.shared.user?.id ?? "coach",
            kit: "",
            position: "Coach",
            skipped: true
        )
        ensurePlayerState()

        Task {
            await CurriculumSyncService.shared.syncCurriculum(context: modelContext, force: true)
            await MainActor.run { onComplete() }
        }
    }

    private func finish(skipped: Bool = false) {
        guard !isFinishing else { return }
        isFinishing = true

        if skipped { state.applySkipDefaults() }

        // 1. Persist locally — instant, offline-first source of truth. Players
        //    have no account; their profile and progress live on the device.
        PlayerProfileStore.shared.complete(
            name: state.playerName.isEmpty ? "Player" : state.playerName,
            username: state.generatedUsername,
            kit: state.kitNumber,
            position: state.positionName,
            skipped: skipped
        )

        // 2. Ensure a local PlayerState exists at zero.
        ensurePlayerState()

        // 3. Remote mirror only if a coach happened to sign in but continued as
        //    a player. Regular players never create a remote account.
        Task {
            if AuthService.shared.isAuthenticated {
                await createRemoteProfile()
                await CurriculumSyncService.shared.syncCurriculum(context: modelContext)
            }
            await MainActor.run { onComplete() }
        }
    }

    private func createRemoteProfile() async {
        guard SupabaseService.shared.isConfigured,
              let userID = AuthService.shared.user?.id else { return }
        do {
            try await ProfileService.shared.upsertOwnProfile(
                userID: userID,
                username: state.generatedUsername,
                name: state.playerName,
                kit: state.kitNumber,
                position: state.positionName,
                pledgeTier: state.pledgeTier.rawValue,
                foot: state.foot,
                memberNumber: state.memberNumber,
                classYear: state.classYear
            )
            try await SupabaseService.shared.client
                .from("player_state")
                .upsert(PlayerStateUpsert(
                    playerId: userID,
                    xp: 0,
                    streak: 0,
                    freezesRemaining: 0,
                    lastTrainedDate: nil,
                    streakPb: 0
                ), onConflict: "player_id")
                .execute()
        } catch {
            print("[Onboarding] remote profile creation failed: \(error)")
        }
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
            let playerID = AuthService.shared.user?.id ?? UUID().uuidString
            modelContext.insert(PlayerState(playerID: playerID, xp: 0, streak: 0, freezesRemaining: 0))
            try? modelContext.save()
        }
    }
}
