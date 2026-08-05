//
//  CoachAllowlist.swift
//  MFElite
//
//  A built-in, ship-with-the-app list of emails that always unlock the Coach
//  dashboard and full coach capabilities — even offline, during testing, or
//  while Apple is reviewing the build. This is layered ON TOP of the live
//  server-side `coaches` allow-list so newly added coaches still work without
//  an app update.
//

import Foundation

/// Hard-coded coach + Apple-reviewer emails that always grant coach access.
/// Matching is case-insensitive and whitespace-insensitive.
nonisolated enum CoachAllowlist {
    /// Approved coach accounts plus the Apple reviewer's guest email.
    /// Keep in sync with the server-side `coaches` table.
    /// Kept in sync with the `coaches` table in Supabase (verified 2026-08-05).
    private static let emails: Set<String> = [
        // Head coaches — full admin
        "mf.elitetraining@gmail.com",       // Coach Matteo Finazzi
        "matteo.m.finazzi@gmail.com",       // Coach Matteo Finazzi (signed-in account)
        "matteofinazzi.official@gmail.com", // Coach Matteo Finazzi (alt)
        "josephmcgee36@gmail.com",          // Joe McGee
        "joe@m5cairio.com",                 // Joe McGee (alt)
        // Coaches
        "suemcgee83@gmail.com",             // Susan McGee
        "avamcgee2476@gmail.com",           // Ava McGee
        "avam221611@icloud.com",            // Ava McGee (alt)
        "audrey.mcgee1524@gmail.com",       // Audrey McGee
        "audmcgee@icloud.com",              // Audrey McGee (alt)
        // Apple reviewer guest account
        "appreview@mfelite.app"
    ]

    /// Accounts that always hold the full Head Coach role, even offline or before
    /// the server check runs. Layered ON TOP of the live `coaches` table.
    /// Every address the `coaches` table marks `role = 'head_coach'`. All of
    /// these get full admin: media upload, publishing, announcements, XP grants
    /// and the Control Center — offline and before the server check lands.
    private static let headCoachEmails: Set<String> = [
        "mf.elitetraining@gmail.com",       // Coach Matteo Finazzi
        "matteo.m.finazzi@gmail.com",       // Coach Matteo Finazzi (signed-in account)
        "matteofinazzi.official@gmail.com", // Coach Matteo Finazzi (alt)
        "josephmcgee36@gmail.com",          // Joe McGee
        "joe@m5cairio.com"                  // Joe McGee (alt)
    ]

    /// Normalize an email for comparison (trimmed + lowercased).
    private static func normalize(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// True when the email is on the built-in coach allow-list.
    static func contains(_ email: String?) -> Bool {
        guard let email, !email.isEmpty else { return false }
        return emails.contains(normalize(email))
    }

    /// True when the email is a built-in Head Coach (full head-coach access).
    static func isHeadCoach(_ email: String?) -> Bool {
        guard let email, !email.isEmpty else { return false }
        return headCoachEmails.contains(normalize(email))
    }
}
