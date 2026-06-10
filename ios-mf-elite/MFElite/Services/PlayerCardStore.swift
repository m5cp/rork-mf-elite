//
//  PlayerCardStore.swift
//  MFElite
//
//  Persists the player's card design (theme, text stickers, pen strokes) plus an
//  optional custom background photo. Fully local, on-device — mirrors the
//  pattern used by PlayerProfileStore.
//

import SwiftUI
import UIKit
import Observation

@Observable
@MainActor
final class PlayerCardStore {
    static let shared = PlayerCardStore()

    private enum Keys {
        static let design = "MF_CARD_DESIGN"
    }

    private static let photoFileName = "player_card_bg.jpg"

    private let defaults = UserDefaults.standard

    /// The persisted card design.
    private(set) var design: CardDesign
    /// The loaded custom background photo, when `design.hasPhoto` is true.
    private(set) var backgroundPhoto: UIImage?

    private init() {
        if let data = defaults.data(forKey: Keys.design),
           let decoded = try? JSONDecoder().decode(CardDesign.self, from: data) {
            design = decoded
        } else {
            design = CardDesign()
        }
        loadPhoto()
    }

    private static var photoURL: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent(photoFileName)
    }

    private func loadPhoto() {
        guard design.hasPhoto,
              let data = try? Data(contentsOf: Self.photoURL),
              let image = UIImage(data: data) else {
            backgroundPhoto = nil
            return
        }
        backgroundPhoto = image
    }

    /// Save a full design back to disk.
    func save(_ design: CardDesign) {
        self.design = design
        if let data = try? JSONEncoder().encode(design) {
            defaults.set(data, forKey: Keys.design)
        }
    }

    /// Store a custom background photo (downscaled) and flag the design.
    func setBackgroundPhoto(_ image: UIImage) {
        let resized = image.mf_resized(maxDimension: 1400)
        guard let data = resized.jpegData(compressionQuality: 0.9) else { return }
        try? data.write(to: Self.photoURL, options: .atomic)
        backgroundPhoto = resized
    }

    /// Remove the custom background photo.
    func clearBackgroundPhoto() {
        backgroundPhoto = nil
        try? FileManager.default.removeItem(at: Self.photoURL)
    }
}
