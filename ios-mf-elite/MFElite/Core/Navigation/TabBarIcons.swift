//
//  TabBarIcons.swift
//  MFElite
//
//  Custom-drawn 22×22 stroked icons for the tab bar.
//

import SwiftUI

/// The tabs of the app. The `coach` tab is only shown to authorized coaches.
enum AppTab: Int, CaseIterable, Identifiable {
    case today
    case hub
    case progress
    case profile
    case coach

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .today:    return "HOME"
        case .hub:      return "MF HUB"
        case .progress: return "PROGRESS"
        case .profile:  return "PROFILE"
        case .coach:    return "COACH"
        }
    }

    /// The tabs visible for the current role. Players never see the Coach tab.
    static func visible(isCoach: Bool) -> [AppTab] {
        var tabs: [AppTab] = [.today, .hub, .progress, .profile]
        if isCoach { tabs.append(.coach) }
        return tabs
    }
}

/// A 22×22 stroked icon for a given tab, drawn with Canvas.
struct TabBarIcon: View {
    let tab: AppTab
    var size: CGFloat = 22
    var color: Color = .white

    private let strokeWidth: CGFloat = 1.6

    var body: some View {
        Canvas { context, canvasSize in
            let path: Path
            switch tab {
            case .today:    path = housePath(in: canvasSize)
            case .hub:      path = gridPath(in: canvasSize)
            case .progress: path = chartPath(in: canvasSize)
            case .profile:  path = personPath(in: canvasSize)
            case .coach:    path = shieldPath(in: canvasSize)
            }

            context.stroke(
                path,
                with: .color(color),
                style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)
            )

            // Progress chart gets a filled dot at the peak.
            if tab == .progress {
                let w = canvasSize.width
                let h = canvasSize.height
                let peak = CGPoint(x: w * 0.78, y: h * 0.26)
                let dotR: CGFloat = 1.8
                let dot = Path(ellipseIn: CGRect(
                    x: peak.x - dotR, y: peak.y - dotR,
                    width: dotR * 2, height: dotR * 2
                ))
                context.fill(dot, with: .color(color))
            }
        }
        .frame(width: size, height: size)
    }

    // MARK: - Icon Paths

    private func housePath(in s: CGSize) -> Path {
        var p = Path()
        let w = s.width, h = s.height
        let roofPeak = CGPoint(x: w * 0.5, y: h * 0.14)
        let leftWall = CGPoint(x: w * 0.18, y: h * 0.42)
        let rightWall = CGPoint(x: w * 0.82, y: h * 0.42)
        let baseY = h * 0.86

        // Roof
        p.move(to: leftWall)
        p.addLine(to: roofPeak)
        p.addLine(to: rightWall)

        // Walls
        p.move(to: CGPoint(x: w * 0.24, y: h * 0.40))
        p.addLine(to: CGPoint(x: w * 0.24, y: baseY))
        p.addLine(to: CGPoint(x: w * 0.76, y: baseY))
        p.addLine(to: CGPoint(x: w * 0.76, y: h * 0.40))

        // Door
        p.move(to: CGPoint(x: w * 0.42, y: baseY))
        p.addLine(to: CGPoint(x: w * 0.42, y: h * 0.62))
        p.addLine(to: CGPoint(x: w * 0.58, y: h * 0.62))
        p.addLine(to: CGPoint(x: w * 0.58, y: baseY))

        return p
    }

    private func targetPath(in s: CGSize) -> Path {
        var p = Path()
        let w = s.width, h = s.height
        let c = CGPoint(x: w * 0.5, y: h * 0.5)
        let rOuter = w * 0.34
        let rInner = w * 0.16
        p.addEllipse(in: CGRect(x: c.x - rOuter, y: c.y - rOuter, width: rOuter * 2, height: rOuter * 2))
        p.addEllipse(in: CGRect(x: c.x - rInner, y: c.y - rInner, width: rInner * 2, height: rInner * 2))
        return p
    }

    private func gridPath(in s: CGSize) -> Path {
        var p = Path()
        let w = s.width, h = s.height
        let cell = w * 0.34
        let gap = w * 0.12
        let originX = (w - (cell * 2 + gap)) / 2
        let originY = (h - (cell * 2 + gap)) / 2
        let radius: CGFloat = 2.2

        for row in 0..<2 {
            for col in 0..<2 {
                let x = originX + CGFloat(col) * (cell + gap)
                let y = originY + CGFloat(row) * (cell + gap)
                p.addPath(Path(roundedRect: CGRect(x: x, y: y, width: cell, height: cell), cornerRadius: radius))
            }
        }
        return p
    }

    private func chartPath(in s: CGSize) -> Path {
        var p = Path()
        let w = s.width, h = s.height
        p.move(to: CGPoint(x: w * 0.14, y: h * 0.70))
        p.addLine(to: CGPoint(x: w * 0.38, y: h * 0.52))
        p.addLine(to: CGPoint(x: w * 0.56, y: h * 0.60))
        p.addLine(to: CGPoint(x: w * 0.78, y: h * 0.26))
        return p
    }

    private func shieldPath(in s: CGSize) -> Path {
        var p = Path()
        let w = s.width, h = s.height
        // Shield outline.
        p.move(to: CGPoint(x: w * 0.5, y: h * 0.14))
        p.addLine(to: CGPoint(x: w * 0.82, y: h * 0.28))
        p.addLine(to: CGPoint(x: w * 0.82, y: h * 0.50))
        p.addQuadCurve(to: CGPoint(x: w * 0.5, y: h * 0.88),
                       control: CGPoint(x: w * 0.80, y: h * 0.74))
        p.addQuadCurve(to: CGPoint(x: w * 0.18, y: h * 0.50),
                       control: CGPoint(x: w * 0.20, y: h * 0.74))
        p.addLine(to: CGPoint(x: w * 0.18, y: h * 0.28))
        p.closeSubpath()
        // Inner check mark.
        p.move(to: CGPoint(x: w * 0.37, y: h * 0.48))
        p.addLine(to: CGPoint(x: w * 0.46, y: h * 0.58))
        p.addLine(to: CGPoint(x: w * 0.64, y: h * 0.37))
        return p
    }

    private func personPath(in s: CGSize) -> Path {
        var p = Path()
        let w = s.width, h = s.height

        // Head
        let headR = w * 0.16
        let headCenter = CGPoint(x: w * 0.5, y: h * 0.34)
        p.addEllipse(in: CGRect(
            x: headCenter.x - headR, y: headCenter.y - headR,
            width: headR * 2, height: headR * 2
        ))

        // Shoulders arc
        p.move(to: CGPoint(x: w * 0.22, y: h * 0.82))
        p.addQuadCurve(
            to: CGPoint(x: w * 0.78, y: h * 0.82),
            control: CGPoint(x: w * 0.5, y: h * 0.54)
        )

        return p
    }
}

#Preview {
    ZStack {
        DS.Colors.Bg.base.ignoresSafeArea()
        HStack(spacing: 24) {
            ForEach(AppTab.allCases) { tab in
                TabBarIcon(tab: tab)
            }
        }
    }
}
