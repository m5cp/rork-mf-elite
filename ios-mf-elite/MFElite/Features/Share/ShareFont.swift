//
//  ShareFont.swift
//  MFElite
//
//  Typography for share cards. Display uses Anton (bundled Google font, SIL OFL);
//  text uses the system font (SF / Helvetica Neue). Card sizes are fixed design
//  px — cards render at a fixed resolution, so they deliberately do NOT scale
//  with Dynamic Type.
//

import SwiftUI
import UIKit

enum ShareFont {
    /// PostScript / family name of the bundled Anton font.
    static let displayName = "Anton"

    /// True once the bundled Anton font is registered and resolvable.
    static var isDisplayAvailable: Bool {
        UIFont(name: displayName, size: 12) != nil
    }

    /// Ultra-condensed display font for numerals, headlines, eyebrows and the
    /// footer wordmark. Falls back to a heavy system font if Anton is missing.
    static func display(_ size: CGFloat) -> Font {
        isDisplayAvailable ? .custom(displayName, size: size) : .system(size: size, weight: .black)
    }

    /// Anton for IN-APP chrome, scaled with Dynamic Type.
    ///
    /// `display(_:)` above is deliberately fixed because cards render to a
    /// 1080px image. Screen headlines are a different problem: the gallery
    /// headline was frozen at 38pt while the body copy around it doubled at
    /// accessibility sizes, which inverted the hierarchy.
    static func displayScaled(
        _ size: CGFloat,
        relativeTo style: UIFont.TextStyle = .largeTitle
    ) -> Font {
        guard isDisplayAvailable, let base = UIFont(name: displayName, size: size) else {
            // DS.Typography.scaled already takes a UIFont.TextStyle.
            return DS.Typography.scaled(size, weight: .black, relativeTo: style)
        }
        return Font(UIFontMetrics(forTextStyle: style).scaledFont(for: base))
    }

    /// System text font for labels, player line, and captions.
    static func text(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
}
