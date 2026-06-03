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

    let onComplete: () -> Void

    var body: some View {
        ZStack {
            DS.Colors.Bg.base.ignoresSafeArea()

            Group {
                switch state.step {
                case .splash:
                    OnboardingSplashView(state: state)
                case .identify:
                    OnboardingIdentifyView(state: state)
                case .username:
                    OnboardingUsernameView(state: state)
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
        }
        .preferredColorScheme(.dark)
    }

    private func finish() {
        guard !isFinishing else { return }
        isFinishing = true

        // 1. Persist locally — instant, offline-first source of truth.
        PlayerProfileStore.shared.complete(
            name: state.playerName.isEmpty ? "Player One" : state.playerName,
            username: state.username,
            kit: state.kitNumber,
            position: state.position
        )

        // 2. Ensure a local PlayerState exists at zero.
        ensurePlayerState()

        // 3. Best-effort remote: Sign in with Apple + profile creation. Falls
        //    back to anonymous local-only mode if auth isn't ready / declined.
        Task {
            await AuthService.shared.signInWithApple()
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
                username: state.username,
                name: state.playerName,
                kit: state.kitNumber,
                position: state.position
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

    private func ensurePlayerState() {
        let existing = try? modelContext.fetch(FetchDescriptor<PlayerState>()).first
        if existing == nil {
            let playerID = AuthService.shared.user?.id ?? UUID().uuidString
            modelContext.insert(PlayerState(playerID: playerID, xp: 0, streak: 0, freezesRemaining: 0))
            try? modelContext.save()
        }
    }

}
