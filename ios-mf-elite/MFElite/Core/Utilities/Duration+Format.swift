//
//  Duration+Format.swift
//  MFElite
//
//  Helpers for turning a drill's duration in seconds into readable strings.
//

import Foundation

extension Int {
    /// Clock-style "M:SS" (e.g. 42 → "0:42", 360 → "6:00").
    var clockDuration: String {
        let minutes = self / 60
        let seconds = self % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Readable minutes, e.g. 45 → "45s", 360 → "6 min".
    var minutesDuration: String {
        if self < 60 { return "\(self)s" }
        let minutes = self / 60
        let seconds = self % 60
        return seconds == 0 ? "\(minutes) min" : "\(minutes):\(String(format: "%02d", seconds))"
    }

    /// Short uppercase minutes for button hints, e.g. 360 → "6 MIN".
    var minutesHint: String {
        if self < 60 { return "\(self) SEC" }
        let minutes = Int((Double(self) / 60).rounded())
        return "\(minutes) MIN"
    }
}
