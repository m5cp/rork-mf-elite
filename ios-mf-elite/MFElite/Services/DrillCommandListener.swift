//
//  DrillCommandListener.swift
//  MFElite
//
//  Receives commands posted by the Live Activity's interactive buttons (pause /
//  skip) and forwards them to the running drill player. The Darwin notification
//  is delivered in-process because LiveActivityIntents run inside the app.
//

import Foundation

/// C callback for the Darwin notification — bounces to the main actor and asks
/// the shared listener to drain the command channel.
private nonisolated func drillCommandDarwinCallback(
    _ center: CFNotificationCenter?,
    _ observer: UnsafeMutableRawPointer?,
    _ name: CFNotificationName?,
    _ object: UnsafeRawPointer?,
    _ userInfo: CFDictionary?
) {
    Task { @MainActor in
        DrillCommandListener.shared.drain()
    }
}

@MainActor
final class DrillCommandListener {
    static let shared = DrillCommandListener()

    /// Set by the active drill player while a session is running.
    var onCommand: ((DrillLiveActivityCommand) -> Void)?

    private var isObserving = false

    private init() {}

    /// Register the Darwin observer once. Idempotent.
    func startObserving() {
        guard !isObserving else { return }
        isObserving = true
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            drillCommandDarwinCallback,
            DrillLiveActivityCommandBus.darwinName as CFString,
            nil,
            .deliverImmediately
        )
    }

    func drain() {
        if let command = DrillLiveActivityCommandBus.consume() {
            onCommand?(command)
        }
    }
}
