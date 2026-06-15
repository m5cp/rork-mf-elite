//
//  TermsOfUseView.swift
//  MFElite
//

import SwiftUI

struct TermsOfUseView: View {
    var body: some View {
        LegalDocumentView(
            title: "Terms of Use",
            subtitle: "Last Updated: June 2026",
            intro: "These Terms of Use govern your access to and use of the MF Elite mobile application, operated by M5 Capital Partners LLC d/b/a M5CAIRIO. By downloading, installing, or using the App, you agree to be bound by these Terms. If you do not agree, do not use the App.",
            sections: [
                LegalSection(
                    heading: "1. Eligibility",
                    body: "The App is designed for youth athletes. If you are under 18, you must have a parent or legal guardian review and agree to these Terms on your behalf before using the App. By allowing a minor to use the App, the parent or guardian agrees to these Terms and accepts responsibility for the minor's use."
                ),
                LegalSection(
                    heading: "2. Account and Data",
                    body: "You can create an optional account (with email and password, or with Sign in with Apple) to sync your profile and training data across devices. When signed in, your profile and training data are stored on your device and synced to our backend. You are responsible for keeping your account credentials and device secure.\n\nDeleting the App or resetting your device erases data stored on that device. To delete data synced to your account, contact us at mf.elitetraining@gmail.com.\n\nOur collection and use of your information is described in our Privacy Policy, which is part of these Terms."
                ),
                LegalSection(
                    heading: "3. Subscriptions and Payments",
                    body: "The App offers a free tier with limited content and a paid \"Elite\" subscription with full access to all drills, levels, certifications, and features.\n\nPayment is charged to your Apple ID account at confirmation of purchase. Subscriptions automatically renew unless canceled at least 24 hours before the end of the current billing period.\n\nYou may manage or cancel your subscription at any time through your Apple ID account settings (Settings > Apple ID > Subscriptions).\n\nRefunds are handled exclusively by Apple in accordance with their refund policies. We do not process refunds directly.\n\nPrices are subject to change. We will provide notice of price changes through the App or App Store listing before they take effect."
                ),
                LegalSection(
                    heading: "4. Acceptable Use",
                    body: "You agree not to:\n\n(a) Use the App for any unlawful purpose or in violation of any applicable laws or regulations.\n\n(b) Reverse engineer, decompile, disassemble, or attempt to derive the source code of the App.\n\n(c) Modify, adapt, translate, or create derivative works based on the App.\n\n(d) Remove, alter, or obscure any copyright, trademark, or other proprietary rights notices.\n\n(e) Use the App in any manner that could damage, disable, overburden, or impair any server, network, or system.\n\n(f) Share, transfer, or sublicense your subscription access to third parties outside your household."
                ),
                LegalSection(
                    heading: "5. Intellectual Property",
                    body: "All content in the App — including but not limited to drill descriptions, coaching points, training methodologies, graphics, logos, icons, the curriculum structure, and the MF Elite brand — is the intellectual property of the Company and/or its content partners and is protected by copyright, trademark, and other intellectual property laws.\n\nYour subscription grants you a limited, non-exclusive, non-transferable, revocable license to access and use the App content for personal, non-commercial training purposes only.\n\nYou may not reproduce, distribute, publicly display, or create derivative works from any App content without prior written permission."
                ),
                LegalSection(
                    heading: "6. Disclaimer of Warranties",
                    body: "THE APP IS PROVIDED \"AS IS\" AND \"AS AVAILABLE\" WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, AND NON-INFRINGEMENT.\n\nWe do not warrant that the App will be uninterrupted, error-free, or free of viruses or other harmful components.\n\nThe App is a training tool and does not replace professional coaching, medical advice, physical therapy, or any form of licensed professional guidance."
                ),
                LegalSection(
                    heading: "7. Limitation of Liability",
                    body: "TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE LAW, IN NO EVENT SHALL THE COMPANY, ITS OFFICERS, DIRECTORS, EMPLOYEES, AGENTS, OR CONTENT PARTNERS BE LIABLE FOR ANY INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES, INCLUDING BUT NOT LIMITED TO LOSS OF DATA, LOSS OF PROFITS, PERSONAL INJURY, OR PROPERTY DAMAGE ARISING OUT OF OR RELATED TO YOUR USE OF THE APP.\n\nOUR TOTAL LIABILITY FOR ALL CLAIMS ARISING OUT OF OR RELATING TO THESE TERMS OR THE APP SHALL NOT EXCEED THE AMOUNT YOU PAID TO US IN THE TWELVE (12) MONTHS PRECEDING THE EVENT GIVING RISE TO THE CLAIM."
                ),
                LegalSection(
                    heading: "8. Indemnification",
                    body: "You agree to indemnify, defend, and hold harmless the Company and its officers, directors, employees, and agents from and against any claims, liabilities, damages, losses, costs, or expenses (including reasonable attorneys' fees) arising out of or related to your use of the App, your violation of these Terms, or your violation of any rights of any third party."
                ),
                LegalSection(
                    heading: "9. Modifications",
                    body: "We reserve the right to modify these Terms at any time. Updated Terms will be posted within the App with a revised \"Last Updated\" date. Your continued use of the App after any changes constitutes acceptance of the revised Terms."
                ),
                LegalSection(
                    heading: "10. Termination",
                    body: "We may suspend or terminate your access to the App at any time, with or without cause, and with or without notice. Upon termination, your license to use the App is immediately revoked."
                ),
                LegalSection(
                    heading: "11. Governing Law",
                    body: "These Terms are governed by and construed in accordance with the laws of the State of Tennessee, without regard to conflict of law principles. Any disputes arising under these Terms shall be resolved exclusively in the state or federal courts located in Davidson County, Tennessee."
                ),
                LegalSection(
                    heading: "12. Contact",
                    body: "For questions about these Terms, contact us at:\n\nM5 Capital Partners LLC\nEmail: mf.elitetraining@gmail.com\nWebsite: m5cairio.com"
                )
            ]
        )
    }
}
