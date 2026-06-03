//
//  SafariView.swift
//  MFElite
//
//  A SwiftUI wrapper around SFSafariViewController for presenting legal pages
//  (Terms, Privacy) in-app without leaving the experience.
//

import SwiftUI
import SafariServices

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.barCollapsingEnabled = true
        let controller = SFSafariViewController(url: url, configuration: config)
        controller.preferredControlTintColor = .white
        controller.preferredBarTintColor = .black
        controller.dismissButtonStyle = .close
        return controller
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

/// Identifiable wrapper so a URL can drive `.sheet(item:)`.
struct IdentifiableURL: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}
