//
//  MemberCardView.swift
//  MFElite
//
//  The canonical white "member ID" card. One design powers the onboarding
//  passport moment and the shareable Player Card so they always match and stay
//  in sync with the live profile (name, photo, post, kit, foot, class year).
//
//  Everything is sized off the passed `width` so the card scales identically
//  from a 335pt onboarding card to a 1080px share export.
//

import SwiftUI

struct MemberCardView: View {
    let player: CardPlayerInfo
    /// The player's portrait, mirrored from the profile avatar.
    let avatarPhoto: UIImage?
    let width: CGFloat
    /// Accent used on the kit number / name underline.
    var accent: Color = .black
    /// Append the rank / XP / streak strip (used on the shareable card).
    var showStats: Bool = false
    /// Optional tap on the photo box (onboarding lets you change the avatar).
    var onPhotoTap: (() -> Void)? = nil

    private var pad: CGFloat { width * 0.06 }
    private var photoSide: CGFloat { width * 0.30 }

    /// True when the accent is too pale to read on the card's white stock.
    ///
    /// Measured rather than compared: the accents come from hex strings, so
    /// an equality test against `Color.white` misses them entirely — and
    /// "nearly white" is just as unreadable as white. The cut is at 0.72
    /// luma, which is where an accent drops below roughly 2:1 against white;
    /// Gold, Ice, Sunset, Desert, Rooftop, Emblem and Monolith all sit above
    /// it and have been drawing a kit number nobody could read.
    private var accentIsTooPaleForWhite: Bool {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard UIColor(accent).getRed(&r, green: &g, blue: &b, alpha: &a) else { return false }
        return (0.299 * r + 0.587 * g + 0.114 * b) > 0.72
    }

    var body: some View {
        VStack(alignment: .leading, spacing: width * 0.045) {
            topRow
            HStack(alignment: .top, spacing: width * 0.05) {
                photoBox
                identityFields
            }
            slashRule
            footerRow
            if showStats {
                statsStrip
            }
        }
        .padding(pad)
        .frame(width: width, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: width * 0.06, style: .continuous))
    }

    // MARK: - Top brand row

    private var topRow: some View {
        HStack(alignment: .top) {
            Image("mf-logo-black")
                .resizable()
                .scaledToFit()
                .frame(height: width * 0.05)
                .accessibilityLabel("MF Elite")
            Spacer()
            VStack(alignment: .trailing, spacing: width * 0.006) {
                Text("MF · ACADEMY")
                    .font(.system(size: width * 0.026, weight: .bold, design: .monospaced))
                    .tracking(width * 0.004)
                    .foregroundStyle(DS.Colors.Ground.secondary)
                Text("CLASS · \(player.classYearText)")
                    .font(.system(size: width * 0.026, weight: .bold, design: .monospaced))
                    .tracking(width * 0.004)
                    .foregroundStyle(DS.Colors.Ground.tertiary)
            }
        }
    }

    // MARK: - Photo

    private var photoBox: some View {
        let avatar = AvatarView(
            selection: player.avatar,
            photo: avatarPhoto,
            initials: player.initials,
            kit: nil,
            size: photoSide,
            shape: .roundedRect(width * 0.04)
        )
        return Group {
            if let onPhotoTap {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onPhotoTap()
                } label: {
                    avatar.overlay(alignment: .bottomTrailing) { cameraBadge }
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel("Change photo")
            } else {
                avatar
            }
        }
    }

    private var cameraBadge: some View {
        Image(systemName: "camera.fill")
            .font(.system(size: width * 0.032, weight: .bold))
            .foregroundStyle(.black)
            .frame(width: width * 0.07, height: width * 0.07)
            .background(Color.white)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.black.opacity(0.15), lineWidth: 1))
            .offset(x: width * 0.012, y: width * 0.012)
    }

    // MARK: - Identity fields

    private var identityFields: some View {
        VStack(alignment: .leading, spacing: width * 0.035) {
            fieldGroup(label: "NAME", value: player.name.isEmpty ? "Player" : player.name, big: true)
            HStack(spacing: width * 0.04) {
                fieldGroup(label: "POST", value: player.positionCode.isEmpty ? "—" : player.positionCode.uppercased())
                fieldGroup(label: "KIT", value: player.kitNumber.isEmpty ? "—" : player.kitNumber)
            }
            HStack(spacing: width * 0.04) {
                fieldGroup(label: "FOOT", value: player.foot.isEmpty ? "—" : player.foot)
                fieldGroup(label: "CLASS", value: player.classYearText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func fieldGroup(label: String, value: String, big: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: width * 0.008) {
            Text(label)
                .font(.system(size: width * 0.024, weight: .bold, design: .monospaced))
                .tracking(width * 0.004)
                .foregroundStyle(DS.Colors.Ground.tertiary)
            Text(value)
                .font(.system(size: big ? width * 0.078 : width * 0.05, weight: .heavy))
                .tracking(big ? -width * 0.002 : 0)
                .foregroundStyle(DS.Colors.Ground.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Slash rule

    private var slashRule: some View {
        Canvas { context, size in
            let spacing = width * 0.045
            let count = max(1, Int(size.width / spacing))
            let angle = Angle(degrees: 115).radians
            let len = width * 0.024
            let dx = cos(angle) * len
            let dy = sin(angle) * len
            let midY = size.height / 2
            for i in 0..<count {
                let x = spacing / 2 + CGFloat(i) * spacing
                var path = Path()
                path.move(to: CGPoint(x: x - dx, y: midY + dy))
                path.addLine(to: CGPoint(x: x + dx, y: midY - dy))
                context.stroke(path, with: .color(.black.opacity(0.15)), lineWidth: max(1, width * 0.003))
            }
        }
        .frame(height: width * 0.03)
    }

    // MARK: - Footer

    private var footerRow: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: width * 0.006) {
                Text("ACADEMY")
                    .font(.system(size: width * 0.024, weight: .bold, design: .monospaced))
                    .tracking(width * 0.004)
                    .foregroundStyle(DS.Colors.Ground.tertiary)
                Text(player.academy)
                    .font(.system(size: width * 0.044, weight: .heavy))
                    .foregroundStyle(DS.Colors.Ground.primary)
            }
            Spacer()
            Text(player.kitNumber.isEmpty ? "MF" : "№ \(player.kitNumber)")
                .font(.system(size: width * 0.05, weight: .heavy, design: .monospaced))
                // The member card itself is white, so a pale accent has to
                // fall back to black. Comparing against `Color.white` does
                // NOT catch it: `CardTheme.accent` is built from a hex string,
                // and an sRGB-resolved white is not `==` the system white —
                // which is why Noir, the default theme, has been drawing an
                // invisible kit number.
                .foregroundStyle(accentIsTooPaleForWhite ? .black : accent)
        }
    }

    // MARK: - Stats strip (shareable card only)

    private var statsStrip: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.black.opacity(0.08))
                .frame(height: 1)
                .padding(.bottom, width * 0.04)
            HStack(spacing: 0) {
                statCell(value: "RANK \(player.rankNumeral)", label: player.rankTitle.uppercased())
                statDivider
                statCell(value: player.xp.formatted(), label: "XP")
                statDivider
                statCell(value: "\(player.streak)", label: "DAY STREAK")
            }
        }
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: width * 0.006) {
            Text(value)
                .font(.system(size: width * 0.045, weight: .heavy).monospacedDigit())
                .foregroundStyle(DS.Colors.Ground.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.system(size: width * 0.022, weight: .bold, design: .monospaced))
                .tracking(width * 0.003)
                .foregroundStyle(DS.Colors.Ground.tertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Color.black.opacity(0.1))
            .frame(width: 1, height: width * 0.08)
    }
}
