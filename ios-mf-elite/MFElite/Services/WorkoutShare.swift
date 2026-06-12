//
//  WorkoutShare.swift
//  MFElite
//
//  Encodes/decodes a custom workout as a compact mfelite:// URL and renders a
//  scannable QR image for sharing. No camera or networking — purely local.
//

import Foundation
import CoreImage.CIFilterBuiltins
import UIKit

/// Encodes/decodes a workout as a compact mfelite:// URL for QR sharing.
enum WorkoutShare {
    nonisolated struct Payload: Codable, Identifiable {
        var v: Int = 1
        var name: String
        var drills: [String] // drill IDs in order

        /// Stable identity for SwiftUI sheet presentation, derived from contents.
        var id: String { "\(name)|\(drills.joined(separator: ","))" }
    }

    static func url(for name: String, drillIDs: [String]) -> URL? {
        let payload = Payload(name: String(name.prefix(40)), drills: drillIDs)
        guard let data = try? JSONEncoder().encode(payload) else { return nil }
        let b64 = data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
        return URL(string: "mfelite://workout?d=\(b64)")
    }

    static func decode(_ url: URL) -> Payload? {
        guard url.scheme == "mfelite", url.host == "workout",
              let b64 = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "d" })?.value else { return nil }
        let std = b64.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padded = std.padding(toLength: ((std.count + 3) / 4) * 4,
                                 withPad: "=", startingAt: 0)
        guard let data = Data(base64Encoded: padded) else { return nil }
        return try? JSONDecoder().decode(Payload.self, from: data)
    }

    static func qrImage(for url: URL, scale: CGFloat = 12) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(url.absoluteString.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale)) else { return nil }
        guard let cg = CIContext().createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}
