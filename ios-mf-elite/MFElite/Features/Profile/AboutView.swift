//
//  AboutView.swift
//  MFElite
//

import SwiftUI

struct AboutView: View {
    var body: some View {
        LegalDocumentView(
            title: "About MF Elite",
            subtitle: "Founded by Coach Matteo Finazzi",
            intro: "MF Elite Training develops complete soccer players — technically, physically, tactically, and mentally. This app puts our academy's full training methodology in your pocket.",
            sections: [
                LegalSection(
                    heading: "Coach Matteo Finazzi",
                    body: "Former professional player, born in Argentina and raised in Spain. Matteo came up through Atlético de Madrid's academy, playing for the club through the U19 level, and went on to play professionally for Lyn FK in Norway."
                ),
                LegalSection(
                    heading: "Coaching Career",
                    body: "Matteo brings more than 10 years of experience coaching high-level players across five top-tier soccer countries: Spain, Norway, England, Portugal, and the USA. His players include the 2025 Player of the Year, the 2025 Offensive Player of the Year, and numerous other award winners and standout athletes."
                ),
                LegalSection(
                    heading: "MF Elite Training",
                    body: "MF Elite Training coaches more than 1,000 players per year at our physical training locations. The same curriculum, standards, and coaching points used on our fields power every drill in this app — so every player trains the way our academy players train."
                ),
                LegalSection(
                    heading: "The Method",
                    body: "The MF Elite curriculum covers four disciplines — Technical, Physical, Tactical, and Mental — through a progressive level system. Master the fundamentals, earn your certifications, and build the habits that separate elite players: consistency, accountability, and honest work."
                )
            ]
        )
    }
}
