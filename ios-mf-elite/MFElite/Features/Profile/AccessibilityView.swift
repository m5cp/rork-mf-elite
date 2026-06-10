//
//  AccessibilityView.swift
//  MFElite
//

import SwiftUI

struct AccessibilityView: View {
    var body: some View {
        LegalDocumentView(
            title: "Accessibility",
            subtitle: "Last Updated: June 2026",
            intro: "M5 Capital Partners LLC is committed to making MF Elite accessible to all athletes, including those with disabilities. This statement outlines our accessibility practices and ongoing efforts.",
            sections: [
                LegalSection(
                    heading: "Our Commitment",
                    body: "We believe every athlete deserves access to quality training tools. We are committed to ensuring that MF Elite meets or exceeds accessibility standards so that all users can train, track progress, and develop their skills regardless of ability."
                ),
                LegalSection(
                    heading: "Accessibility Features",
                    body: "MF Elite includes the following accessibility features:\n\nVoiceOver Support: All screens, buttons, drills, and navigation elements include accessibility labels and hints for full VoiceOver compatibility.\n\nDynamic Type: The App supports Dynamic Type, allowing text to scale according to your device's preferred text size settings.\n\nHigh Contrast: The App uses a high-contrast dark theme with white text on dark backgrounds, meeting WCAG AA contrast ratio requirements.\n\nHaptic Feedback: Key actions such as starting drills, completing sets, and logging progress provide haptic feedback for tactile confirmation.\n\nReduced Motion: The App respects the iOS Reduce Motion setting and reduces or eliminates animations when enabled.\n\nButton Sizing: All interactive elements meet or exceed the minimum 44×44 point touch target size recommended by Apple's Human Interface Guidelines."
                ),
                LegalSection(
                    heading: "Standards We Follow",
                    body: "We design and develop MF Elite with reference to:\n\nApple's Human Interface Guidelines for Accessibility\nWeb Content Accessibility Guidelines (WCAG) 2.1 Level AA (where applicable to native apps)\nSection 508 of the Rehabilitation Act (as a best-practice reference)"
                ),
                LegalSection(
                    heading: "Known Limitations",
                    body: "While we strive for full accessibility, some features may have limitations:\n\nTimer-based drill sessions rely on visual countdown displays. We are working on enhanced audio cues for future updates.\n\nSome decorative visual elements (coaching point animations, celebration screens) may not convey equivalent information through assistive technologies.\n\nWe are continuously improving and welcome feedback on areas where accessibility can be enhanced."
                ),
                LegalSection(
                    heading: "Feedback",
                    body: "If you encounter any accessibility barriers while using MF Elite, or if you have suggestions for improving accessibility, please contact us. Your feedback directly informs our development priorities.\n\nEmail: mf.elitetraining@gmail.com\n\nWhen reporting an accessibility issue, please include:\n\nA description of the issue\nThe screen or feature where you encountered it\nYour device model and iOS version\nAny assistive technology you were using (VoiceOver, Switch Control, etc.)"
                ),
                LegalSection(
                    heading: "Continuous Improvement",
                    body: "Accessibility is an ongoing effort, not a one-time task. We regularly review our app for accessibility issues, test with assistive technologies, and incorporate feedback from users with disabilities. Our goal is to make every future update more accessible than the last."
                )
            ]
        )
    }
}
