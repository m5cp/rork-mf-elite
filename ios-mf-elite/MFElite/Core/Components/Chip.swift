//
//  Chip.swift
//  MFElite
//
//  Small filter/tag pill for horizontal filter rows.
//

import SwiftUI

struct Chip: View {
    let label: String
    var active: Bool = false
    var icon: String? = nil
    var action: (() -> Void)? = nil

    private var foreground: Color {
        active ? DS.Colors.Ground.primary : DS.Colors.Ink.secondary
    }

    private var border: Color {
        active ? Color.white : DS.Colors.Line.subtle
    }

    var body: some View {
        Group {
            if let action {
                Button(action: action) { content }
                    .buttonStyle(PressableButtonStyle())
            } else {
                content
            }
        }
    }

    private var content: some View {
        HStack(spacing: DS.Spacing.s4 + 2) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(foreground)
            }
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(foreground)
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 14)
        .background(active ? Color.white : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.pill))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.pill)
                .stroke(border, lineWidth: 1)
        )
    }
}

#Preview {
    ZStack {
        DS.Colors.Bg.base.ignoresSafeArea()
        HStack(spacing: DS.Spacing.s8) {
            Chip(label: "All", active: true) {}
            Chip(label: "Passing", icon: "arrow.up.right") {}
            Chip(label: "Finishing") {}
        }
    }
}
