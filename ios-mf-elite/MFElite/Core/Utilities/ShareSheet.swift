//
//  ShareSheet.swift
//  MFElite
//
//  Thin UIActivityViewController wrapper for sharing files and images
//  (PDF report cards, certificate images) via the native share sheet.
//

import SwiftUI
import UIKit

/// Presents the system share sheet for the given items (URLs, images, text).
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
