//
//  SectionIcon.swift
//  MFElite
//
//  The one recipe for a section-leading icon.
//
//  Before this existed the same element was built five different ways:
//    • Ink.primary, size 20, no container            (CoachView ×8)
//    • Gold.base in a Gold.soft circle, 40pt          (ControlCenterView)
//    • Gold.base in a Bg.raised rounded rect, 44pt    (CoachTeamsView)
//    • Ink.primary in a Bg.raised circle, 36pt        (Profile, Settings, Family)
//    • Ink.primary, bare .frame(width: 26)            (ProgressReportBuilderView)
//
//  …which is exactly the "some are gold, some are white" the owner reported.
//  Everything now goes through this, so the accent preference lands in one
//  place and the geometry matches across every tab.
//

import SwiftUI

struct SectionIcon: View {
    let systemName: String
    /// Container diameter. 44 is the standard row icon; 36 for denser lists.
    var size: CGFloat = 44
    /// Overrides the accent finish — for semantic icons (a red warning
    /// triangle) that must not be recolored by the accent.
    var tint: Color?

    private var glyphSize: CGFloat { size * 0.45 }

    var body: some View {
        ZStack {
            Circle()
                .fill(DS.Colors.Bg.raised)
                .overlay(
                    Circle().stroke(DS.Colors.Line.hairline, lineWidth: 1)
                )

            glyph
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var glyph: some View {
        let image = Image(systemName: systemName)
            .font(.system(size: glyphSize, weight: .semibold))

        if let tint {
            image.foregroundStyle(tint)
        } else {
            image.metallicSymbol(.gold)
        }
    }
}

#Preview {
    ZStack {
        DS.Colors.Bg.base.ignoresSafeArea()
        VStack(spacing: DS.Spacing.s16) {
            HStack(spacing: DS.Spacing.s16) {
                SectionIcon(systemName: "megaphone.fill")
                SectionIcon(systemName: "person.3.fill")
                SectionIcon(systemName: "chart.bar.doc.horizontal.fill")
                SectionIcon(systemName: "exclamationmark.triangle.fill",
                            tint: DS.Colors.Status.bad)
            }
            HStack(spacing: DS.Spacing.s16) {
                SectionIcon(systemName: "gearshape", size: 36)
                SectionIcon(systemName: "medal", size: 36)
                SectionIcon(systemName: "rosette", size: 36)
            }
        }
    }
}
