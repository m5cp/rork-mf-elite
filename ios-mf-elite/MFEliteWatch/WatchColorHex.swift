//
//  WatchColorHex.swift
//  MFEliteWatch
//
//  Minimal hex → Color initializer for the watch target (the phone app has its
//  own copy in the design system). Accepts "#RRGGBB" or "RRGGBB".
//

import SwiftUI

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r = Double((value & 0xFF0000) >> 16) / 255
        let g = Double((value & 0x00FF00) >> 8) / 255
        let b = Double(value & 0x0000FF) / 255
        self = Color(red: r, green: g, blue: b)
    }
}
