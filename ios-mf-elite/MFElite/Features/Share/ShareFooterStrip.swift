//
//  ShareFooterStrip.swift
//  MFElite
//
//  The branded footer that sits on every share card: MF wordmark logo, the
//  "TRAIN WITH ME / ON MF ELITE" call-out, and a scannable QR + printed link to
//  the App Store page. Sizes are design px at 1080-wide export.
//

import SwiftUI

struct ShareFooterStrip: View {
    let theme: ShareTheme

    private var stripBackground: Color {
        theme.isLight ? Color.black.opacity(0.06) : Color.white.opacity(0.05)
    }

    private var hairline: Color {
        theme.isLight ? Color.black.opacity(0.14) : Color.white.opacity(0.14)
    }

    private var logoAsset: String {
        theme.isLight ? "mf-logo-black" : "mf-logo-white"
    }

    var body: some View {
        HStack(spacing: 44) {
            Image(logoAsset)
                .resizable()
                .scaledToFit()
                .frame(height: 84)

            VStack(alignment: .leading, spacing: 0) {
                Text("TRAIN WITH ME")
                Text("ON MF ELITE")
            }
            .font(ShareFont.display(44))
            .tracking(2)
            .foregroundStyle(theme.ink)
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 12) {
                ShareQRView(text: ShareLinks.appStoreURL, size: 128)
                    .padding(10)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                Text(ShareLinks.appStoreShort)
                    .font(ShareFont.text(24, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(theme.accent)
            }
        }
        .padding(.horizontal, 56)
        .padding(.vertical, 36)
        .frame(maxWidth: .infinity)
        .background(stripBackground)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(hairline)
                .frame(height: 2)
        }
    }
}
