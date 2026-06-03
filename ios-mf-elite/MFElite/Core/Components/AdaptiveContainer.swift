//
//  AdaptiveContainer.swift
//  MFElite
//
//  Constrains content to a comfortable reading width on larger devices
//  (iPad) while staying edge-to-edge on iPhone. Side margins fall back to
//  the pure-black base color so the framing feels intentional.
//

import SwiftUI

/// Maximum content width on iPad / large canvases. iPhone always fills.
enum AdaptiveLayout {
    static let maxContentWidth: CGFloat = 500
}

private struct AdaptiveWidthModifier: ViewModifier {
    func body(content: Content) -> some View {
        GeometryReader { proxy in
            let needsCap = proxy.size.width > AdaptiveLayout.maxContentWidth
            let width = needsCap ? AdaptiveLayout.maxContentWidth : proxy.size.width

            ZStack {
                DS.Colors.Bg.base
                content
                    .frame(width: width)
                    .frame(maxWidth: .infinity)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

extension View {
    /// Caps content at `AdaptiveLayout.maxContentWidth` and centers it with
    /// black side margins on iPad-sized canvases. No-op on iPhone widths.
    func adaptiveContentWidth() -> some View {
        modifier(AdaptiveWidthModifier())
    }
}
