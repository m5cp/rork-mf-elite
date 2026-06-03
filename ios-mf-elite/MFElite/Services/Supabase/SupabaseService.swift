//
//  SupabaseService.swift
//  MFElite
//
//  Wraps the Supabase client. Auth tokens come from Rork Auth (see AuthService),
//  so RLS `user_id()` resolves to the signed-in Rork user.
//

import Foundation
import Supabase

/// Single source of truth for the Supabase client.
final class SupabaseService {
    static let shared = SupabaseService()

    let client: SupabaseClient

    /// Whether real Supabase credentials are present. When false, remote sync is
    /// skipped and the app runs fully on local SwiftData seed data.
    let isConfigured: Bool

    /// Read via `Config.allValues` (a dictionary lookup) rather than a direct
    /// `Config.EXPO_PUBLIC_*` member so this compiles even before the backend is
    /// provisioned. Once provisioning registers the keys, `Config` regenerates
    /// and these resolve to the real values automatically.
    /// Prefer the user-owned Supabase project (`EXPO_PUBLIC_MY_SUPABASE_*`).
    /// Falls back to the Rork-provisioned project only if the user keys are absent.
    private static var supabaseURLString: String {
        let mine = Config.allValues["EXPO_PUBLIC_MY_SUPABASE_URL"] ?? ""
        return mine.isEmpty ? (Config.allValues["EXPO_PUBLIC_SUPABASE_URL"] ?? "") : mine
    }
    private static var supabaseAnonKey: String {
        let mine = Config.allValues["EXPO_PUBLIC_MY_SUPABASE_ANON_KEY"] ?? ""
        return mine.isEmpty ? (Config.allValues["EXPO_PUBLIC_SUPABASE_ANON_KEY"] ?? "") : mine
    }

    private init() {
        let urlString = Self.supabaseURLString
        let anonKey = Self.supabaseAnonKey
        isConfigured = !urlString.isEmpty && !anonKey.isEmpty
        client = SupabaseClient(
            supabaseURL: URL(string: urlString) ?? URL(string: "https://placeholder.supabase.co")!,
            supabaseKey: anonKey,
            options: .init(
                auth: .init(
                    // Synchronous: hand the Rork JWT to PostgREST/RLS.
                    accessToken: {
                        AuthTokenStore.currentAccessToken() ?? ""
                    }
                )
            )
        )
    }
}
