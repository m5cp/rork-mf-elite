//
//  PrivacyPolicyView.swift
//  MFElite
//

import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        LegalDocumentView(
            title: "Privacy Policy",
            subtitle: "Last Updated: June 2026",
            intro: "M5 Capital Partners LLC d/b/a M5CAIRIO operates the MF Elite mobile application. This Privacy Policy explains how we collect, use, and protect information when you use the App.",
            sections: [
                LegalSection(
                    heading: "1. Information We Collect",
                    body: "Account Information:\nIf you create an account or sign in (with email and password, or with Sign in with Apple), we collect and store an email address and an account identifier. This is used to authenticate you and sync your data across devices.\n\nProfile and Training Data:\nWhen you use the App you may provide a player name, initials, kit number, age, playing position, goals, and an avatar selection. You also generate training data such as completed drills, sessions, progress, achievements, streaks, XP, post-session ratings, and reflection notes. This data is stored on your device and, when you are signed in, synced to our backend so it persists and follows you across devices.\n\nFitness Data:\nCompleted training sessions are recorded as fitness/activity data within the App. If you enable the Apple Health integration, the App writes completed sessions to Apple Health as workouts/active time. We never read your existing Health data.\n\nSubscription and Purchase Data:\nSubscription status and purchase history are processed by Apple and RevenueCat, which receive purchase receipts and device/user identifiers needed to validate your subscription.\n\nGame Center:\nIf you participate in leaderboards and achievements, Apple's Game Center handles your Game Center identity, scores, and ranking.\n\nAutomatically Collected Information:\nApple may collect device type, operating system version, app usage data, and crash reports for App Store analytics.\n\nInformation We Do NOT Collect:\nWe do not collect phone numbers, physical addresses (unless you contact support), precise location data, your camera roll or photos beyond an avatar you choose, contacts, browsing history, or biometric data. We do not use your data for advertising or share it with data brokers."
                ),
                LegalSection(
                    heading: "2. How We Use Information",
                    body: "Account and Sync: Your email and account ID are used to authenticate you, secure your account, and sync your profile and training data across your devices.\n\nApp Functionality and Personalization: Profile information and training data power the training experience — building your adaptive daily plan, tracking progress and achievements, and personalizing what you see (for example, your profile card, focus areas, and coach context).\n\nFitness Data: Used to track your training activity and, with your permission, to log workouts to Apple Health.\n\nSubscription Data: We use RevenueCat to manage and validate subscription status.\n\nAnalytics: We may use Apple's built-in App Analytics to understand aggregate usage patterns. This data is anonymized and aggregated by Apple.\n\nSupport Communications: If you contact us via email, we retain your email address and message content solely to respond to your inquiry.\n\nWe do not use any of this data for third-party advertising, and we do not sell your personal information."
                ),
                LegalSection(
                    heading: "3. Data Storage and Security",
                    body: "Training data, progress, achievements, and profile information are stored on your device using Apple's SwiftData framework. When you are signed in, this data is also synced to and stored on our backend (Supabase) so it persists and is available across your devices.\n\nAccount session tokens are stored securely in the device Keychain. Data in transit is protected using encrypted (HTTPS) connections.\n\nDeleting the App or resetting your device removes locally stored data. If you have an account, you can permanently delete it — and all of your data on our servers — directly in the App under Profile > Settings > Delete account. You may also contact us at mf.elitetraining@gmail.com for assistance.\n\nWe implement reasonable technical measures to keep your data secure, but no method of electronic storage or transmission is 100% secure."
                ),
                LegalSection(
                    heading: "4. Third-Party Services",
                    body: "The App integrates with the following third-party services:\n\nApple App Store — Distribution and payments. Receives purchase data and device info.\n\nApple Game Center — Leaderboards and achievements. Handles Game Center identity and scores.\n\nApple Health (optional) — Receives completed workout/active-time data you choose to log.\n\nRevenueCat — Subscription management. Receives a user/device identifier and purchase receipts.\n\nSupabase — Backend hosting for account authentication and data sync. Stores your account email, profile, and training data.\n\nWe do not sell, rent, or share your personal information with third parties for their marketing purposes."
                ),
                LegalSection(
                    heading: "5. Children's Privacy",
                    body: "The App is designed for use by youth athletes, which may include children under 13. We comply with the Children's Online Privacy Protection Act (COPPA) and similar regulations.\n\nA parent or legal guardian must review this policy and create or authorize any account on a child's behalf before the child uses account-based features. We collect only the limited information needed to operate the App (such as profile and training data), and we never use a child's information for advertising or sell it.\n\nParents and guardians can review, correct, or delete a child's information at any time by using the in-App Delete account option (Profile > Settings), by deleting the App to remove on-device data, or by contacting us at mf.elitetraining@gmail.com.\n\nIf you believe we have collected information from a child without appropriate consent, please contact us immediately and we will take steps to delete it."
                ),
                LegalSection(
                    heading: "6. Your Rights",
                    body: "Depending on your jurisdiction, you may have the right to access the personal information we hold about you, request correction of inaccurate information, request deletion of your information, object to or restrict processing, and request data portability.\n\nYou can edit your profile and delete on-device data at any time within the App. If you have an account, you can permanently delete it and all associated server data in the App under Profile > Settings > Delete account. You may also contact us at mf.elitetraining@gmail.com and we will respond as required by applicable law."
                ),
                LegalSection(
                    heading: "7. Changes to This Policy",
                    body: "We may update this Privacy Policy from time to time. We will notify you of changes by posting the updated policy within the App with a revised \"Last Updated\" date. Your continued use of the App after any changes constitutes acceptance of the updated policy."
                ),
                LegalSection(
                    heading: "8. Contact Us",
                    body: "For privacy-related questions or concerns:\n\nM5 Capital Partners LLC\nEmail: mf.elitetraining@gmail.com\nWebsite: m5cairio.com"
                )
            ]
        )
    }
}
