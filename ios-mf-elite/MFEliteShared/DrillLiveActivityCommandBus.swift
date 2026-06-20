//
//  DrillLiveActivityCommandBus.swift
//  MFEliteShared
//
//  A tiny one-slot command channel between the Live Activity's interactive
//  buttons (which run an App Intent in the app's process) and the running drill
//  player. Commands are written to the shared App Group and announced with a
//  Darwin notification so the live session can react immediately.
//

import Foundation

nonisolated enum DrillLiveActivityCommand: String {
    case pauseToggle
    case skip
}

nonisolated enum DrillLiveActivityCommandBus {
    static let appGroup = "group.app.rork.pgx8pb996dmcvbhdfnx8x"
    private static let key = "liveactivity.command"
    static let darwinName = "app.rork.pgx8pb996dmcvbhdfnx8x.liveactivity.command"

    /// Write a command and broadcast it to the (in-process) listener.
    static func post(_ command: DrillLiveActivityCommand) {
        let defaults = UserDefaults(suiteName: appGroup)
        defaults?.set(command.rawValue, forKey: key)
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(darwinName as CFString),
            nil, nil, true
        )
    }

    /// Read and clear the most recent command, if any.
    static func consume() -> DrillLiveActivityCommand? {
        let defaults = UserDefaults(suiteName: appGroup)
        guard let raw = defaults?.string(forKey: key) else { return nil }
        defaults?.removeObject(forKey: key)
        return DrillLiveActivityCommand(rawValue: raw)
    }
}
