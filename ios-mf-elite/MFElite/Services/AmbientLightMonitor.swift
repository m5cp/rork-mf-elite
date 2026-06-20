//
//  AmbientLightMonitor.swift
//  MFElite
//
//  iOS has no public ambient-light sensor API (the raw sensor is private and
//  using it risks App Store rejection). The supported, store-safe proxy is the
//  display's brightness: with auto-brightness on, the system raises/lowers the
//  screen to match the room, so a low brightness reading means a dim environment.
//
//  This monitor exposes the current normalized screen brightness (0…1) and a
//  derived `isLowLight` flag, updating live as the room/brightness changes. It's
//  used to gently auto-dim the drill player so the screen isn't harsh in the dark.
//

import SwiftUI
import Observation

@MainActor
@Observable
final class AmbientLightMonitor {
    static let shared = AmbientLightMonitor()

    /// Current display brightness, 0 (darkest) → 1 (brightest).
    private(set) var brightness: CGFloat = UIScreen.main.brightness

    /// Brightness at or below this is treated as a low-light environment.
    private let lowLightThreshold: CGFloat = 0.35

    /// True when the room/screen is dim enough to warrant softening the UI.
    var isLowLight: Bool { brightness <= lowLightThreshold }

    private nonisolated(unsafe) var observer: NSObjectProtocol?

    private init() {
        observer = NotificationCenter.default.addObserver(
            forName: UIScreen.brightnessDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    /// Re-read the current brightness. Call on appear so the value is fresh even
    /// if it changed while the monitor wasn't observing.
    func refresh() {
        brightness = UIScreen.main.brightness
    }
}
