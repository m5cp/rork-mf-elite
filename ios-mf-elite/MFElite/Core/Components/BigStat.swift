//
//  BigStat.swift
//  MFElite
//
//  A vertical stat block: eyebrow label above a large number.
//

import SwiftUI

struct BigStat: View {
    let label: String
    let value: String
    var unit: String? = nil
    var size: CGFloat = 40

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Eyebrow(text: label)
            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.s4) {
                Text(value)
                    .font(DS.Typography.num(size: size))
                    .tracking(-1)
                    .foregroundStyle(DS.Colors.Ink.primary)
                if let unit {
                    Text(unit)
                        .style(.foot)
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                }
            }
        }
    }
}

#Preview {
    ZStack {
        DS.Colors.Bg.base.ignoresSafeArea()
        HStack(spacing: DS.Spacing.s32) {
            BigStat(label: "Sessions", value: "128")
            BigStat(label: "Streak", value: "14", unit: "days")
        }
    }
}
