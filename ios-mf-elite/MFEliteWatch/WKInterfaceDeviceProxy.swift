//
//  WKInterfaceDeviceProxy.swift
//  MFEliteWatch
//
//  Tiny haptics helper so views don't import WatchKit directly everywhere.
//

import WatchKit

enum WKInterfaceDeviceProxy {
    static func playClick() {
        WKInterfaceDevice.current().play(.click)
    }

    static func playSuccess() {
        WKInterfaceDevice.current().play(.success)
    }

    static func playStop() {
        WKInterfaceDevice.current().play(.stop)
    }
}
