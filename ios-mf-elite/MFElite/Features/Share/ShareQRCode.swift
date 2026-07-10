//
//  ShareQRCode.swift
//  MFElite
//
//  Generates a scannable QR code with CoreImage's CIQRCodeGenerator (no
//  third-party libraries) and exposes a crisp, non-interpolated SwiftUI view.
//

import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

/// The canonical links encoded / printed on every card footer.
enum ShareLinks {
    static let appStoreURL = "https://apps.apple.com/us/app/mf-elite/id6776419165"
    static let appStoreShort = "apps.apple.com/mf-elite"
}

enum ShareQRCode {
    /// Shared context; creating one per call is wasteful.
    private static let context = CIContext()

    /// A black-on-transparent QR `UIImage` for `string`. `correction` is one of
    /// "L", "M", "Q", "H" — the footer uses "M" per the handoff.
    static func image(from string: String, correction: String = "M") -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = correction
        guard let output = filter.outputImage else { return nil }
        // Scale up the tiny module grid so the exported bitmap is sharp.
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 16, y: 16))
        guard let cg = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}

/// A square QR view that renders module edges crisply (no smoothing).
struct ShareQRView: View {
    let text: String
    let size: CGFloat
    var correction: String = "M"

    var body: some View {
        if let image = ShareQRCode.image(from: text, correction: correction) {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .frame(width: size, height: size)
        } else {
            // Layout never breaks if generation fails.
            Rectangle()
                .fill(Color.black.opacity(0.08))
                .frame(width: size, height: size)
        }
    }
}
