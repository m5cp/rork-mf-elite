//
//  AvatarView.swift
//  MFElite
//
//  Renders the player's avatar: a custom photo, a built-in MF design, or the
//  initials monogram fallback. Used on the onboarding passport card and the
//  profile header.
//

import SwiftUI

enum AvatarShape {
    case circle
    case roundedRect(CGFloat)
}

/// Maps a built-in avatar id to its on-brand SF Symbol glyph.
enum BuiltinAvatar {
    static func glyph(for id: String) -> String {
        switch id {
        case "crest": return "seal.fill"
        case "slash": return "line.diagonal"
        case "flame": return "flame.fill"
        case "shield": return "shield.lefthalf.filled"
        case "target": return "scope"
        case "bolt": return "bolt.fill"
        case "star": return "star.fill"
        case "crown": return "crown.fill"
        case "trophy": return "trophy.fill"
        case "diamond": return "diamond.fill"
        case "globe": return "globe"
        case "moon": return "moon.fill"
        case "flag": return "flag.fill"
        case "heart": return "heart.fill"
        case "leaf": return "leaf.fill"
        case "sun": return "sun.max.fill"
        case "mountain": return "mountain.2.fill"
        case "lion": return "pawprint.fill"
        default: return "seal.fill"
        }
    }
}

struct AvatarView: View {
    var selection: AvatarSelection
    var photo: UIImage?
    var initials: String
    var kit: String?
    var size: CGFloat
    var shape: AvatarShape = .circle

    private var clip: AnyShape {
        switch shape {
        case .circle: return AnyShape(Circle())
        case .roundedRect(let r): return AnyShape(RoundedRectangle(cornerRadius: r))
        }
    }

    private var strokeColor: Color { DS.Colors.Line.strong }

    var body: some View {
        content
            .frame(width: size, height: size)
            .clipShape(clip)
            .overlay(clip.stroke(strokeColor, lineWidth: 1))
    }

    @ViewBuilder
    private var content: some View {
        switch selection {
        case .photo:
            if let photo {
                Color.clear.overlay {
                    Image(uiImage: photo)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .allowsHitTesting(false)
                }
            } else {
                monogramBase
            }
        case .builtin(let id):
            builtin(id)
        case .none:
            monogramBase
        }
    }

    // MARK: - Built-in

    private func builtin(_ id: String) -> some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#1C1C1C"), Color(hex: "#0A0A0A"), Color(hex: "#050505")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            slashTexture
            Image(systemName: BuiltinAvatar.glyph(for: id))
                .font(.system(size: size * 0.42, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    // MARK: - Monogram fallback

    private var monogramBase: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#1A1A1A"), Color(hex: "#0A0A0A"), Color(hex: "#050505")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            slashTexture
            Text(initials)
                .font(.system(size: size * 0.42, weight: .heavy))
                .tracking(-1.2)
                .foregroundStyle(.white)
            if let kit, !kit.isEmpty {
                VStack {
                    HStack {
                        Spacer()
                        Text("#\(kit)")
                            .style(.micro)
                            .foregroundStyle(Color.white.opacity(0.78))
                    }
                    Spacer()
                }
                .padding(6)
            }
        }
    }

    private var slashTexture: some View {
        Canvas { context, canvasSize in
            let spacing = canvasSize.width / 4
            for i in 1..<4 {
                let offset = CGFloat(i) * spacing
                var path = Path()
                path.move(to: CGPoint(x: offset, y: canvasSize.height))
                path.addLine(to: CGPoint(x: offset + canvasSize.height, y: 0))
                context.stroke(path, with: .color(Color.white.opacity(0.06)), lineWidth: 1)
            }
        }
        .allowsHitTesting(false)
    }
}

#Preview {
    ZStack {
        DS.Colors.Bg.base.ignoresSafeArea()
        VStack(spacing: 24) {
            AvatarView(selection: .none, photo: nil, initials: "JF", kit: "11", size: 92, shape: .roundedRect(8))
            AvatarView(selection: .builtin("flame"), photo: nil, initials: "JF", kit: "11", size: 80)
        }
    }
}
