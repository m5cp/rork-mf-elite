//
//  ShareCardItemSource.swift
//  MFElite
//
//  Native saving & sharing for finished share cards. Supplies rich link
//  metadata (title + MF icon + App Store URL) to the system share sheet so the
//  card previews nicely and carries a discoverable link back to the app. Also
//  provides an Instagram Stories fast-path via the documented pasteboard scheme,
//  falling back to the share sheet when Instagram is not installed.
//

import UIKit
import LinkPresentation

/// Feeds the App Store link + metadata to `UIActivityViewController` alongside
/// the exported card image, so shares show a branded preview and a tappable link.
final class ShareCardItemSource: NSObject, UIActivityItemSource {
    /// The public App Store page for MF Elite.
    static let appStoreURL = URL(string: "https://apps.apple.com/us/app/mf-elite/id6776419165")!

    private let title: String

    init(title: String = "Train with me on MF Elite") {
        self.title = title
    }

    func activityViewControllerPlaceholderItem(_ controller: UIActivityViewController) -> Any {
        Self.appStoreURL
    }

    func activityViewController(
        _ controller: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        Self.appStoreURL
    }

    func activityViewController(
        _ controller: UIActivityViewController,
        subjectForActivityType activityType: UIActivity.ActivityType?
    ) -> String {
        title
    }

    func activityViewControllerLinkMetadata(_ controller: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = title
        metadata.originalURL = Self.appStoreURL
        metadata.url = Self.appStoreURL
        if let icon = UIImage(named: "mf-logo-white") {
            metadata.iconProvider = NSItemProvider(object: icon)
        }
        return metadata
    }
}

/// Fast-path for dropping a finished card straight into an Instagram Story via
/// the documented `instagram-stories://share` pasteboard hand-off. Callers should
/// check `isAvailable` and fall back to the system share sheet when it's false.
@MainActor
enum InstagramStoriesSharer {
    private static var shareURL: URL {
        let source = Bundle.main.bundleIdentifier ?? "app.rork.mfelite"
        return URL(string: "instagram-stories://share?source_application=\(source)")
            ?? URL(string: "instagram-stories://share")!
    }

    /// Whether Instagram is installed and can receive a Stories hand-off.
    /// Requires the `instagram-stories` entry in `LSApplicationQueriesSchemes`.
    static var isAvailable: Bool {
        guard let probe = URL(string: "instagram-stories://share") else { return false }
        return UIApplication.shared.canOpenURL(probe)
    }

    /// Puts the card on the pasteboard as the Story background and opens Instagram.
    /// Returns `false` (do nothing) when Instagram isn't installed or encoding fails,
    /// so the caller can fall back to the share sheet.
    @discardableResult
    static func share(_ image: UIImage) -> Bool {
        guard isAvailable, let data = image.pngData() else { return false }
        let item: [String: Any] = [
            "com.instagram.sharedSticker.backgroundImage": data
        ]
        let options: [UIPasteboard.OptionsKey: Any] = [
            .expirationDate: Date().addingTimeInterval(60 * 5)
        ]
        UIPasteboard.general.setItems([item], options: options)
        UIApplication.shared.open(shareURL, options: [:], completionHandler: nil)
        return true
    }
}
