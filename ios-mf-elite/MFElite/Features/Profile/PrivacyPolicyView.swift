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
                    body: "Information You Provide:\nWhen you use the App, you may provide a player name, initials, kit number, playing position, and avatar selection. This information is stored locally on your device and is not transmitted to our servers.\n\nAutomatically Collected Information:\nThe App may collect device type and operating system version, app usage data and crash reports (collected by Apple for App Store analytics), and subscription status and purchase history (processed by Apple and RevenueCat).\n\nInformation We Do NOT Collect:\nWe do not collect real names, email addresses, phone numbers, physical addresses (unless you contact support), location data, photos or camera data (avatar photos remain on-device only), contacts or social media information, browsing history, or biometric data."
                ),
                LegalSection(
                    heading: "2. How We Use Information",
                    body: "On-Device Data: Player profile information and training progress are used solely to provide the training experience within the App. This data remains on your device and is not accessible to us.\n\nSubscription Data: We use RevenueCat to manage subscription status. RevenueCat receives an anonymous app user ID, purchase receipts, and device identifiers necessary to validate your subscription.\n\nAnalytics: We may use Apple's built-in App Analytics to understand aggregate usage patterns such as session counts and feature adoption. This data is anonymized and aggregated by Apple.\n\nSupport Communications: If you contact us via email, we retain your email address and message content solely to respond to your inquiry and improve the App."
                ),
                LegalSection(
                    heading: "3. Data Storage and Security",
                    body: "All training data, progress, achievements, and profile information are stored locally on your device using Apple's SwiftData framework.\n\nWe do not operate servers that store your personal data.\n\nDeleting the App or resetting your device will permanently delete all locally stored data. We cannot recover this data.\n\nWe implement reasonable technical measures to ensure the App functions securely, but no method of electronic storage is 100% secure."
                ),
                LegalSection(
                    heading: "4. Third-Party Services",
                    body: "The App integrates with the following third-party services:\n\nApple App Store — Distribution and payments. Receives purchase data and device info.\n\nRevenueCat — Subscription management. Receives anonymous user ID and purchase receipts.\n\nWe do not sell, rent, or share your personal information with third parties for their marketing purposes."
                ),
                LegalSection(
                    heading: "5. Children's Privacy",
                    body: "The App is designed for use by youth athletes, including children under 13. We comply with the Children's Online Privacy Protection Act (COPPA) and similar regulations.\n\nWe do not knowingly collect personal information from children. All data remains on-device. No data is transmitted to our servers.\n\nParents and guardians can review and delete any data stored in the App by accessing the App on the child's device or by deleting and reinstalling the App.\n\nIf you believe we have inadvertently collected personal information from a child, please contact us immediately at mf.elitetraining@gmail.com and we will take steps to delete such information."
                ),
                LegalSection(
                    heading: "6. Your Rights",
                    body: "Depending on your jurisdiction, you may have the right to access the personal information we hold about you, request correction of inaccurate information, request deletion of your information, object to or restrict processing of your information, and data portability.\n\nBecause all training data is stored locally on your device, you have direct control over it at all times. You can delete all data by deleting the App."
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
