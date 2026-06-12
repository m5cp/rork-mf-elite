//
//  SupabaseConfig.swift
//  MFElite
//
//  Connection details for the self-owned Supabase project. The publishable
//  ("anon"/"sb_publishable") key is safe to embed in the client — row-level
//  security on the server is what actually protects data.
//

import Foundation

enum SupabaseConfig {
    /// Base URL of the Supabase project (no trailing slash).
    static let url = "https://twzukrzcfquxfmrnffze.supabase.co"

    /// Publishable API key sent as the `apikey` header on every request.
    static let apiKey = "sb_publishable_XrrGiFzMHI_baTETn3M_Rg_SeaotI_c"
}
