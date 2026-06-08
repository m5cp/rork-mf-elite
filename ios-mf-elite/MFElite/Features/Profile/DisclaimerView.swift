//
//  DisclaimerView.swift
//  MFElite
//

import SwiftUI

struct DisclaimerView: View {
    var body: some View {
        LegalDocumentView(
            title: "Disclaimer",
            subtitle: "Last Updated: June 2026",
            intro: "Please read this disclaimer carefully before using MF Elite.",
            sections: [
                LegalSection(
                    heading: "Not Medical Advice",
                    body: "MF Elite is a soccer training tool designed for skill development and fitness. It is not a substitute for professional medical advice, diagnosis, or treatment. Always consult a qualified physician or healthcare provider before beginning any new exercise program, particularly if you have pre-existing health conditions, injuries, or concerns about your physical ability to perform the exercises described in the App."
                ),
                LegalSection(
                    heading: "Not Professional Coaching",
                    body: "The training drills, routines, and coaching points provided in the App are for educational and training purposes only. They do not replace instruction from a certified coach, trainer, or physical therapist. Individual technique correction and safety guidance require in-person professional supervision."
                ),
                LegalSection(
                    heading: "Assumption of Risk",
                    body: "Physical exercise carries inherent risks including, but not limited to, muscle strains, sprains, fractures, joint injuries, cardiovascular events, heat-related illness, and other physical harm. By using the App, you acknowledge and voluntarily assume these risks. You agree to train within your physical limits and to stop immediately if you experience pain, dizziness, shortness of breath, or any other discomfort."
                ),
                LegalSection(
                    heading: "Youth Athletes",
                    body: "Parents and guardians are responsible for supervising minors during training sessions and ensuring that exercises are age-appropriate and performed safely. The App does not monitor physical activity in real time and cannot assess whether a particular drill is safe for a specific individual."
                ),
                LegalSection(
                    heading: "Training Environment",
                    body: "You are responsible for ensuring that your training area is safe, free of obstacles, and appropriate for the exercises being performed. The App does not assess your training environment."
                ),
                LegalSection(
                    heading: "Results Not Guaranteed",
                    body: "Individual training outcomes vary based on factors including age, physical condition, frequency of training, nutrition, rest, and genetic factors. The App does not guarantee any specific performance improvements, skill development, or athletic outcomes."
                ),
                LegalSection(
                    heading: "Limitation of Liability",
                    body: "To the maximum extent permitted by law, M5 Capital Partners LLC, its owners, employees, content partners, and affiliates shall not be liable for any injury, damage, or loss resulting from the use of the App or reliance on its content.\n\nBy using MF Elite, you acknowledge that you have read, understood, and agreed to this Disclaimer."
                )
            ]
        )
    }
}
