//
//  MFArtwork.swift
//  MFElite
//
//  The app's photographic library, in one place.
//
//  Every image ships in the asset catalog under a stable name. Views never
//  spell those names out — they ask `MFArtwork` for the picture that belongs
//  to a discipline or a section, so renaming or re-shooting an image is a
//  one-line change here instead of a hunt through the feature folders.
//
//  Each photograph is cut to the shape it is actually displayed at, not to
//  one convenient source ratio: a banner shown 353pt wide and 180pt tall is
//  a 1.95:1 crop on disk. Shipping a taller source and letting `.fill` throw
//  away the difference is how heads end up cropped off in a header nobody
//  looked at on device.
//
//  Discipline photos also ship a portrait `_thumb` at list-row size, and the
//  card backdrops ship one at swatch size. A 62pt row tile drawn from the
//  full-size file would hold a multi-megabyte decode for eighty pixels of
//  screen, and the theme picker builds seven of them at once.
//
//  Everything is dark-toned by design, and `ArtworkBanner` lays a scrim over
//  it, so white text sits on top of any of them safely.
//

import SwiftUI

enum MFArtwork {

    // MARK: - Disciplines

    /// The hero photo for a development pathway, keyed on the discipline's
    /// stable curriculum id with a name fallback for safety — the bundled
    /// curriculum can be re-authored, and a missing photo should degrade to
    /// no photo rather than a blank rectangle.
    static func discipline(id: String, name: String) -> String? {
        switch id {
        case "d-tech": return "discipline_technical"
        case "d-phys": return "discipline_physical"
        case "d-tact": return "discipline_tactical"
        case "d-psy":  return "discipline_mental"
        default: break
        }
        switch name.lowercased() {
        case "technical": return "discipline_technical"
        case "physical":  return "discipline_physical"
        case "tactical":  return "discipline_tactical"
        case "mental", "psychological": return "discipline_mental"
        default: return nil
        }
    }

    /// Row-sized portrait crop of the same photograph.
    static func disciplineThumb(id: String, name: String) -> String? {
        discipline(id: id, name: name).map { $0 + "_thumb" }
    }

    // MARK: - Sections

    /// Section header photography. Named for the surface, not the subject, so
    /// swapping the picture later doesn't quietly change a different screen.
    static let ballonDor = "section_ballondor"
    static let certifications = "section_certifications"
    static let coach = "section_coach"
    static let combine = "section_combine"
    static let drills = "section_drills"
    static let leaderboard = "section_leaderboard"
    static let programs = "section_programs"
    static let rank = "section_rank"
    static let teams = "section_teams"
    static let workouts = "section_workouts"

    /// Full-bleed 9:16 backdrop for the mental-exercise player.
    static let mentalBackdrop = "mental_backdrop"

    /// Standard section-header height. The section crops on disk are cut for
    /// this height at a phone's content width — changing one without the
    /// other reintroduces the cropping this constant exists to prevent.
    static let bannerHeight: CGFloat = 180

    /// Discipline heroes run slightly taller than a section header.
    static let heroHeight: CGFloat = 190
}

// MARK: - Banner

/// A photographic header: the image, a scrim, and optional overlay text.
///
/// The scrim is not decoration — it is the reason a caption can be white on
/// every one of these photos without checking each one by hand.
struct ArtworkBanner<Overlay: View>: View {
    let name: String
    var height: CGFloat = MFArtwork.bannerHeight
    var cornerRadius: CGFloat = 18
    @ViewBuilder var overlay: () -> Overlay

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Decorative: the caption, if any, carries the meaning, and it is
            // deliberately outside this group so VoiceOver still reaches it.
            ZStack {
                Image(name)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(height: height)
                    .clipped()

                LinearGradient(
                    colors: [
                        .black.opacity(0.05),
                        .black.opacity(0.35),
                        .black.opacity(0.88)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)

            overlay()
                .padding(.horizontal, DS.Spacing.s16)
                .padding(.bottom, DS.Spacing.s16)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

extension ArtworkBanner where Overlay == EmptyView {
    init(name: String, height: CGFloat = MFArtwork.bannerHeight, cornerRadius: CGFloat = 18) {
        self.init(name: name, height: height, cornerRadius: cornerRadius) { EmptyView() }
    }
}

/// The standard caption on a banner: a small eyebrow over a title.
struct ArtworkCaption: View {
    let eyebrow: String
    let title: String
    var detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s4) {
            Text(eyebrow)
                .style(.micro)
                .foregroundStyle(.white.opacity(0.72))
            Text(title)
                .style(.title2)
                .foregroundStyle(.white)
            if let detail {
                Text(detail)
                    .style(.micro)
                    .foregroundStyle(.white.opacity(0.66))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .shadow(color: .black.opacity(0.6), radius: 6, y: 1)
    }
}

// MARK: - Thumb

/// A small portrait crop, for list rows. Pass a `_thumb` asset name.
struct ArtworkThumb: View {
    let name: String
    var width: CGFloat = 62
    var height: CGFloat = 76
    var cornerRadius: CGFloat = 12

    var body: some View {
        Image(name)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: width, height: height)
            .clipped()
            .overlay(
                LinearGradient(
                    colors: [.clear, .black.opacity(0.45)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            )
            .accessibilityHidden(true)
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            ArtworkBanner(name: "discipline_technical", height: MFArtwork.heroHeight) {
                ArtworkCaption(eyebrow: "Pathway 01", title: "Technical", detail: "5 Categories · 120 Drills")
            }
            ArtworkBanner(name: MFArtwork.combine)
            HStack(spacing: 12) {
                ArtworkThumb(name: "discipline_physical_thumb")
                ArtworkThumb(name: "discipline_tactical_thumb")
                ArtworkThumb(name: "discipline_mental_thumb")
            }
        }
        .padding(20)
    }
    .background(DS.Colors.Bg.base)
}
