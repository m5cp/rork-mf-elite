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
    private static let emails: Set<String> = [
        "mf.elitetraining@gmail.com",   // Coach Matteo Finazzi (head coach)
        "josephmcgee36@gmail.com",      // Joe McGee (head coach)
        "appreview@mfelite.app"        // Apple reviewer guest account
    ]

    /// Accounts that always hold the full Head Coach role, even offline or before
    /// the server check runs. Layered ON TOP of the live `coaches` table.
    private static let headCoachEmails: Set<String> = [
        "mf.elitetraining@gmail.com",   // Coach Matteo Finazzi
        "josephmcgee36@gmail.com"       // Joe McGee (developer / head coach)
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
