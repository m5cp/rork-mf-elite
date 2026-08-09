//
//  CoachAllowlist.swift
//  MFElite
//
//  A built-in, ship-with-the-app list of emails that unlock the Coach dashboard
//  offline, during testing, and while Apple is reviewing the build. Layered ON
//  TOP of the live server-side `coaches` table so a newly added coach works
//  without an app update.
//
//  It is a fallback, not an override. As of 2026-08-08 an explicit "no role"
//  answer from `my_coach_role()` revokes access even for an address listed
//  here — removing someone from the `coaches` table is enough, and no longer
//  needs an App Store release. Only a FAILED call (offline, 401) falls back to
//  this list.
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
    /// Every address the `coaches` table marks `role = 'head_coach'`. Head
    /// coaches are the only accounts that can upload drill media or edit the
    /// curriculum (server-enforced since 2026-08-08), on top of XP grants and
    /// the Control Center. A regular coach on the list below gets the
    /// dashboard, teams, rosters, announcements, notes and reports.
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
