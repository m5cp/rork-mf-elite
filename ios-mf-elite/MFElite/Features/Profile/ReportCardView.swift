//
//  ReportCardView.swift
//  MFElite
//
//  The formal white credential — the only light surface in the app.
//

import SwiftUI
import SwiftData

/// Navigation route to the academy report card.
struct ReportCardRoute: Hashable {}

struct ReportCardView: View {
    @Query(sort: \Discipline.sortIndex) private var disciplines: [Discipline]
    @Query private var players: [PlayerState]
    @Query private var progress: [DrillProgress]

    /// Hairline tuned for the white card.
    private let inkLine = Color.black.opacity(0.12)

    private var viewModel: ParentReportViewModel {
        ParentReportViewModel(
            disciplines: disciplines,
            xp: players.first?.xp ?? 0,
            streak: players.first?.streak ?? 0,
            lastTrainedDate: players.first?.lastTrainedDate,
            masteredDrillIDs: Set(progress.filter { $0.isMastered }.map { $0.drillID }),
            sessionsLogged: progress.reduce(0) { $0 + $1.passesLogged }
        )
    }

    var body: some View {
        let vm = viewModel
        ScrollView {
            VStack(spacing: 0) {
                reportCard(vm)
                ctas
            }
            .padding(.bottom, 120)
        }
        .background(DS.Colors.Bg.base)
        .scrollIndicators(.hidden)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - The white card

    private func reportCard(_ vm: ParentReportViewModel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            letterhead
            playerInfo(vm)
            grades(vm)
            certifications(vm)
            signature
        }
        .padding(DS.Spacing.s32)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl))
        .raisedElevation()
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s24)
    }

    // MARK: - Letterhead

    private var letterhead: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("MF ELITE")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(Color.black)
                Spacer()
                Text("ACADEMY REPORT CARD")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(DS.Colors.Ground.secondary)
            }
            Rectangle()
                .fill(inkLine)
                .frame(height: 1)
                .padding(.top, DS.Spacing.s12)
        }
    }

    // MARK: - Player info

    private func playerInfo(_ vm: ParentReportViewModel) -> some View {
        let rank = vm.currentRank
        return VStack(alignment: .leading, spacing: DS.Spacing.s4) {
            Text("Player One")
                .style(.title1)
                .foregroundStyle(Color.black)
            Text("Rank \(rank.numeral) · \(rank.title) · Season 25—26")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(DS.Colors.Ground.secondary)
        }
        .padding(.top, DS.Spacing.s20)
    }

    // MARK: - Grade rows

    private func grades(_ vm: ParentReportViewModel) -> some View {
        let rows: [(String, String)] = [
            ("Consistency", vm.consistencyGrade.rawValue),
            ("Discipline", vm.disciplineGrade.rawValue),
            ("Accountability", vm.accountabilityGrade.rawValue),
            ("Growth", vm.growthGrade.rawValue)
        ]
        return VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                VStack(spacing: 0) {
                    HStack {
                        Text(row.0)
                            .style(.callout)
                            .foregroundStyle(Color.black)
                        Spacer()
                        Text(row.1)
                            .style(.title2)
                            .foregroundStyle(Color.black)
                    }
                    .padding(.vertical, DS.Spacing.s12 + 2)

                    if index < rows.count - 1 {
                        Rectangle().fill(inkLine).frame(height: 1)
                    }
                }
            }
        }
        .padding(.top, DS.Spacing.s24)
    }

    // MARK: - Certifications

    private func certifications(_ vm: ParentReportViewModel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Certifications")
                .style(.callout)
                .fontWeight(.semibold)
                .foregroundStyle(Color.black)

            let names = vm.certifiedCategoryNames
            if names.isEmpty {
                Text("None earned yet")
                    .style(.foot)
                    .foregroundStyle(DS.Colors.Ground.secondary)
                    .padding(.top, DS.Spacing.s8 + 2)
            } else {
                FlowLayout(spacing: DS.Spacing.s8) {
                    ForEach(names, id: \.self) { name in
                        Text(name)
                            .style(.microSm)
                            .foregroundStyle(Color.white)
                            .padding(.vertical, 4)
                            .padding(.horizontal, DS.Spacing.s8 + 2)
                            .background(Color.black)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.pill))
                    }
                }
                .padding(.top, DS.Spacing.s8 + 2)
            }
        }
        .padding(.top, DS.Spacing.s24)
    }

    // MARK: - Coach signature

    private var signature: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                Text("Coach Williams")
                    .font(.system(size: 22, weight: .bold))
                    .italic()
                    .foregroundStyle(Color.black)
                Spacer()
                CertSeal(size: 40, earned: true, dark: true)
            }
            Text("Head Coach · MF Elite Academy")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(DS.Colors.Ground.secondary)
                .padding(.top, DS.Spacing.s8)
        }
        .padding(.top, DS.Spacing.s32 - 4)
    }

    // MARK: - CTAs (outside the white card)

    private var ctas: some View {
        VStack(spacing: DS.Spacing.s12) {
            PrimaryButton(label: "Download PDF") {
                // TODO: PDF export via ImageRenderer/PDFKit in the polish phase.
            }
            SecondaryButton(label: "Share with family") {
                // TODO: share sheet.
            }
            Text("Official academy document")
                .style(.microSm)
                .foregroundStyle(DS.Colors.Ink.quaternary)
                .frame(maxWidth: .infinity)
                .padding(.top, DS.Spacing.s4)
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s24)
    }
}

// MARK: - Flow Layout (wrapping pills)

/// A simple wrapping layout for the certification pills.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth, rowWidth > 0 {
                totalHeight += rowHeight + spacing
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        return CGSize(width: maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading,
                          proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#Preview {
    NavigationStack {
        ReportCardView()
            .preferredColorScheme(.dark)
            .modelContainer(for: [
                Discipline.self, Category.self, MasteryLevel.self,
                Drill.self, DrillProgress.self, PlayerState.self
            ])
    }
}
