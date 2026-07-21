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
/// `onComplete` reports the destination activity and whether the user actually
/// completed the share (false = cancelled) — the only confirmation iOS provides.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    var onComplete: ((_ activityRawValue: String?, _ completed: Bool) -> Void)? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        if let onComplete {
            controller.completionWithItemsHandler = { activity, completed, _, _ in
                onComplete(activity?.rawValue, completed)
            }
        }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
