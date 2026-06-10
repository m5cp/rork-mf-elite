//
//  EULAView.swift
//  MFElite
//

import SwiftUI

struct EULAView: View {
    var body: some View {
        LegalDocumentView(
            title: "End User License Agreement",
            subtitle: "Last Updated: June 2026",
            intro: "This End User License Agreement is a legal agreement between you and M5 Capital Partners LLC d/b/a M5CAIRIO for the use of the MF Elite mobile application. This agreement supplements the Apple Standard Licensed Application End User License Agreement.",
            sections: [
                LegalSection(
                    heading: "1. License Grant",
                    body: "Subject to your compliance with this Agreement, M5 Capital Partners LLC grants you a limited, non-exclusive, non-transferable, revocable license to download, install, and use the App on any Apple-branded device that you own or control, as permitted by the Apple App Store Terms of Service."
                ),
                LegalSection(
                    heading: "2. Scope of License",
                    body: "This license does not allow you to use the App on any device that you do not own or control. You may not distribute or make the App available over a network where it could be used by multiple devices at the same time, except through Apple's Family Sharing feature as permitted by Apple.\n\nYou may not rent, lease, lend, sell, redistribute, or sublicense the App. You may not copy, decompile, reverse engineer, disassemble, attempt to derive the source code of, modify, or create derivative works of the App, any updates, or any part thereof."
                ),
                LegalSection(
                    heading: "3. Consent to Use of Data",
                    body: "You agree that the Company may collect and use technical data and related information — including but not limited to technical information about your device, system and application software, and peripherals — that is gathered periodically to facilitate the provision of software updates, product support, and other services related to the App. The Company may use this information solely to improve its products or to provide services or technologies to you, and only in a form that does not personally identify you."
                ),
                LegalSection(
                    heading: "4. Subscription Terms",
                    body: "The App offers auto-renewing subscription plans that unlock premium content. Payment is charged to your Apple ID account at confirmation of purchase.\n\nSubscriptions automatically renew unless auto-renew is turned off at least 24 hours before the end of the current period. Your account will be charged for renewal within 24 hours prior to the end of the current period at the same price.\n\nYou can manage and cancel your subscriptions by going to your account settings on the App Store after purchase. Any unused portion of a free trial period will be forfeited when you purchase a subscription.\n\nPrices are in U.S. dollars and may vary in other countries. Prices are subject to change, and we will notify you of any changes."
                ),
                LegalSection(
                    heading: "5. Third-Party Terms",
                    body: "The App may use third-party services that have their own terms and conditions. By using the App, you also agree to the following third-party terms:\n\nApple App Store Terms of Service\nRevenueCat Terms of Service (revenuecat.com/terms)"
                ),
                LegalSection(
                    heading: "6. Maintenance and Support",
                    body: "M5 Capital Partners LLC is solely responsible for providing any maintenance and support services with respect to the App, as specified in this Agreement or as required under applicable law. Apple has no obligation whatsoever to furnish any maintenance and support services with respect to the App."
                ),
                LegalSection(
                    heading: "7. Warranty",
                    body: "M5 Capital Partners LLC is solely responsible for any product warranties, whether express or implied by law, to the extent not effectively disclaimed. In the event of any failure of the App to conform to any applicable warranty, you may notify Apple, and Apple will refund the purchase price (if any) for the App. To the maximum extent permitted by applicable law, Apple will have no other warranty obligation whatsoever with respect to the App."
                ),
                LegalSection(
                    heading: "8. Product Claims",
                    body: "M5 Capital Partners LLC, not Apple, is responsible for addressing any user or third-party claims relating to the App or your possession and/or use of the App, including but not limited to: product liability claims, any claim that the App fails to conform to any applicable legal or regulatory requirement, and claims arising under consumer protection, privacy, or similar legislation."
                ),
                LegalSection(
                    heading: "9. Intellectual Property",
                    body: "In the event of any third-party claim that the App or your possession and use of the App infringes that third party's intellectual property rights, M5 Capital Partners LLC, not Apple, will be solely responsible for the investigation, defense, settlement, and discharge of any such intellectual property infringement claim."
                ),
                LegalSection(
                    heading: "10. Legal Compliance",
                    body: "You represent and warrant that you are not located in a country that is subject to a U.S. Government embargo or that has been designated by the U.S. Government as a \"terrorist supporting\" country, and you are not listed on any U.S. Government list of prohibited or restricted parties."
                ),
                LegalSection(
                    heading: "11. Third-Party Beneficiary",
                    body: "You acknowledge and agree that Apple and Apple's subsidiaries are third-party beneficiaries of this Agreement, and that upon your acceptance of this Agreement, Apple will have the right (and will be deemed to have accepted the right) to enforce this Agreement against you as a third-party beneficiary thereof."
                ),
                LegalSection(
                    heading: "12. Contact",
                    body: "If you have any questions about this Agreement, please contact:\n\nM5 Capital Partners LLC\nEmail: mf.elitetraining@gmail.com\nWebsite: m5cairio.com"
                )
            ]
        )
    }
}
