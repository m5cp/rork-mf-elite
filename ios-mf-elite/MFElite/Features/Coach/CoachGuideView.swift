//
//  CoachGuideView.swift
//  MFElite
//

import SwiftUI

struct CoachGuideRoute: Hashable {}

struct CoachGuideView: View {
    var body: some View {
        LegalDocumentView(
            title: "Coach Guide",
            subtitle: "How Coach Mode works",
            intro: "The Coach tab is only visible to coaches on the MF Elite access list. Everything you publish here reaches every player on the roster.",
            sections: [
                LegalSection(
                    heading: "Your Access",
                    body: "Coach access is controlled by the MF Elite coach list. If you can see this tab, you're on it. Access is tied to the email you sign in with — if you change your sign-in email, let the head coach know so the list can be updated."
                ),
                LegalSection(
                    heading: "Workout of the Day",
                    body: "Publish a featured workout and every player sees it on their Today screen (players who committed to their own plan keep their plan — your workout is the default for everyone else). Publish a new one anytime; the newest always wins. If you don't set one, players see a standard rotation, so there's never an empty screen."
                ),
                LegalSection(
                    heading: "Announcements",
                    body: "Send a message to the whole team from the Announcements card. Players see it as a banner on their Today screen. Use it for schedule changes, challenges, and shout-outs."
                ),
                LegalSection(
                    heading: "Editing Drills",
                    body: "Improve the Drills lets you edit any drill's instructions and coaching points, add brand-new drills, or hide a drill from players. Edits go live for the whole team — there's no draft mode, so read your changes before saving."
                ),
                LegalSection(
                    heading: "Drill Videos",
                    body: "Each drill can have a demo video. Film in landscape, keep it 30–60 seconds, and demonstrate at match speed after one slow rep. Upload from the drill's edit screen — the video attaches to that exact drill automatically. Keep files under 100 MB (720p is plenty)."
                ),
                LegalSection(
                    heading: "Your Roster",
                    body: "The roster shows every player, their streaks, XP, and progress. Tap a player for their full detail — mastered drills, combine results, and history. Use the weekly digest to share a team summary."
                ),
                LegalSection(
                    heading: "\(AppConfigStore.shared.awardTitle) Approvals",
                    body: "Players who reach the final tier wait for your invitation. Review them in the approvals card — this is the highest honor in the app, so make it feel earned."
                )
            ]
        )
    }
}
