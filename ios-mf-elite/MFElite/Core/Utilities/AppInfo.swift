//
//  AppInfo.swift
//  MFElite
//
//  Lightweight accessors for the app version, device model, and OS version.
//  Used to pre-fill support emails and the settings footer.
//

import UIKit

enum AppInfo {
    /// e.g. "1.0.0"
    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    /// e.g. "42"
    static var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    /// e.g. "1.0.0 (42)"
    static var versionDisplay: String {
        "\(version) (\(build))"
    }

    /// e.g. "iPhone15,2"
    static var deviceModel: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let mirror = Mirror(reflecting: systemInfo.machine)
        let identifier = mirror.children.reduce("") { partial, element in
            guard let value = element.value as? Int8, value != 0 else { return partial }
            return partial + String(UnicodeScalar(UInt8(value)))
        }
        return identifier.isEmpty ? UIDevice.current.model : identifier
    }

    /// e.g. "iOS 18.0"
    static var osVersion: String {
        "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
    }
}
