//
//  Hairline.swift
//  MFElite
//
//  A simple 1px horizontal divider.
//

import SwiftUI

struct Hairline: View {
    var color: Color = DS.Colors.Line.hairline

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(height: 1)
    }
}

#Preview {
    ZStack {
        DS.Colors.Bg.base.ignoresSafeArea()
        Hairline()
            .padding(.horizontal, DS.Spacing.s20)
    }
}
