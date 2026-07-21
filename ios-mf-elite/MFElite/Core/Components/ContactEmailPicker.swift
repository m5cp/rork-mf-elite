//
//  ContactEmailPicker.swift
//  MFElite
//
//  A SwiftUI wrapper around CNContactPickerViewController for choosing a single
//  email address (e.g. a parent's) without requiring Contacts permission — the
//  picker runs out-of-process and only hands back the chosen address.
//

import SwiftUI
import ContactsUI

/// Presents the system contact picker limited to contacts that have an email
/// address, and reports the first email of the chosen contact.
struct ContactEmailPicker: UIViewControllerRepresentable {
    let onPick: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        picker.displayedPropertyKeys = [CNContactEmailAddressesKey]
        picker.predicateForEnablingContact = NSPredicate(format: "emailAddresses.@count > 0")
        return picker
    }

    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick, dismiss: dismiss) }

    final class Coordinator: NSObject, CNContactPickerDelegate {
        private let onPick: (String) -> Void
        private let dismiss: DismissAction
        init(onPick: @escaping (String) -> Void, dismiss: DismissAction) {
            self.onPick = onPick
            self.dismiss = dismiss
        }

        nonisolated func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            let email = contact.emailAddresses.first.map { String($0.value as String) } ?? ""
            Task { @MainActor in
                self.onPick(email)
                self.dismiss()
            }
        }

        nonisolated func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            Task { @MainActor in self.dismiss() }
        }
    }
}
