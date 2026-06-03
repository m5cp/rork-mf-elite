//
//  MailComposeView.swift
//  MFElite
//
//  A SwiftUI wrapper around MFMailComposeViewController for contacting support
//  with pre-filled device diagnostics. Use `MailRequest` to drive presentation
//  and check `MFMailComposeViewController.canSendMail()` before presenting.
//

import SwiftUI
import MessageUI

/// Describes a pre-filled support email. Drives `.sheet(item:)`.
struct MailRequest: Identifiable {
    let id = UUID()
    let recipient: String
    let subject: String
    let body: String

    /// Standard diagnostics block appended to every support message.
    static func supportBody() -> String {
        """
        App Version: \(AppInfo.versionDisplay)
        Device: \(AppInfo.deviceModel)
        OS: \(AppInfo.osVersion)

        Describe your issue:

        """
    }
}

struct MailComposeView: UIViewControllerRepresentable {
    let request: MailRequest
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let controller = MFMailComposeViewController()
        controller.mailComposeDelegate = context.coordinator
        controller.setToRecipients([request.recipient])
        controller.setSubject(request.subject)
        controller.setMessageBody(request.body, isHTML: false)
        return controller
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(dismiss: dismiss) }

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        private let dismiss: DismissAction
        init(dismiss: DismissAction) { self.dismiss = dismiss }

        nonisolated func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            Task { @MainActor in self.dismiss() }
        }
    }
}
