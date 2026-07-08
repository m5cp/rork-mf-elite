import SwiftUI
import UIKit

// MARK: - MF Elite App Opening
// Soccer ball kicked into the screen → glass shatters → MF logo emerges.
// Requires iOS 17+ (KeyframeAnimator). Uses "SoccerBall" and the existing
// "mf-logo-white" assets.

// MARK: Timeline (seconds)
private enum T {
 static let flight: Double = 1.20 // ball launch → contact
 static let hitStop: Double = 0.07 // world freeze at contact (game-feel)
 static let impact: Double = flight + hitStop
 static let recoil: Double = 0.64
 static let logoIn: Double = impact + 0.52
 static let wordmarkIn: Double = impact + 0.90
 static let crackFade: Double = impact + 0.75
 static let aftershock: Double = impact + 0.95
 static let loadbarIn: Double = impact + 1.10
 static let homeIn: Double = impact + 1.70
}

// MARK: - Root view

public struct MFEliteOpeningView: View {
 public var onFinished: (() -> Void)? = nil

 @State private var ballTrigger = 0
 @State private var crackField: CrackField?
 @State private var ringsShown = 0
 @State private var crackOpacity: Double = 1.0
 @State private var showAftershock = false
 @State private var flash: Double = 0
 @State private var loom: Double = 0
 @State private var shockScale: CGFloat = 0.25
 @State private var shockOpacity: Double = 0
 @State private var screenShake: CGFloat = 0 // 0 → 1 runs one decaying shake
 @State private var settleShake: CGFloat = 0
 @State private var showLogo = false
 @State private var showWordmark = false
 @State private var loadProgress: CGFloat = 0
 @State private var loadbarVisible = false

 public init(onFinished: (() -> Void)? = nil) { self.onFinished = onFinished }

 public var body: some View {
 GeometryReader { geo in
 let size = geo.size
 let impactPoint = CGPoint(x: size.width * 0.5, y: size.height * 0.47)

 ZStack {
 Color.black.ignoresSafeArea()

 // Logo lockup (revealed after impact)
 VStack(spacing: 22) {
 Image("mf-logo-white")
 .resizable().scaledToFit()
 .frame(width: 186)
 if showWordmark {
 VStack(spacing: 8) {
 Text("MF ELITE")
 .font(.system(size: 26, weight: .heavy))
 .kerning(8)
 .foregroundStyle(.white)
 Text("TRAINING SYSTEM")
 .font(.system(size: 11, weight: .semibold))
 .kerning(5)
 .foregroundStyle(.white.opacity(0.5))
 }
 .transition(.opacity.combined(with: .move(edge: .bottom)))
 }
 }
 .position(x: size.width * 0.5, y: size.height * 0.47)
 .opacity(showLogo ? 1 : 0)
 .scaleEffect(showLogo ? 1 : 0.7)

 // Looming shadow as the ball closes in
 RadialGradient(colors: [.black.opacity(0.6), .clear],
 center: .init(x: 0.5, y: 0.47),
 startRadius: 0, endRadius: size.width * 0.62)
 .opacity(loom)
 .allowsHitTesting(false)

 // Shattered glass
 if let field = crackField {
 CrackCanvas(field: field,
 ringsShown: ringsShown,
 showAftershock: showAftershock)
 .opacity(crackOpacity)
 .allowsHitTesting(false)
 }

 // Shockwave ring
 Circle()
 .strokeBorder(Color.white.opacity(0.65), lineWidth: 1.5)
 .frame(width: 64, height: 64)
 .shadow(color: .white.opacity(0.25), radius: 10)
 .scaleEffect(shockScale)
 .opacity(shockOpacity)
 .position(impactPoint)
 .allowsHitTesting(false)

 // Soccer ball — keyframe flight, hit-stop hold, recoil
 BallView(trigger: ballTrigger, size: size)

 // White flash
 Color.white.opacity(flash).ignoresSafeArea().allowsHitTesting(false)

 // Loading hairline
 if loadbarVisible {
 ZStack(alignment: .leading) {
 Capsule().fill(.white.opacity(0.14))
 Capsule().fill(.white)
 .frame(width: 96 * loadProgress)
 }
 .frame(width: 96, height: 2)
 .position(x: size.width * 0.5, y: size.height - 120)
 }
 }
 .modifier(ShakeEffect(travel: 16, progress: screenShake))
 .modifier(ShakeEffect(travel: 2.5, progress: settleShake))
 .onAppear { run(size: size) }
 }
 .statusBarHidden()
 }

 // MARK: Orchestration
 private func run(size: CGSize) {
 crackField = CrackField.generate(in: size)
 Haptics.prepare()
 after(0) {
 ballTrigger += 1
 withAnimation(.easeIn(duration: T.flight - 0.2).delay(0.2)) { loom = 0.75 }
 }
 // Contact: flash + heavy haptic fire DURING the hit-stop freeze
 after(T.flight) {
 withAnimation(.easeOut(duration: 0.10)) { flash = 0.85 }
 withAnimation(.easeOut(duration: 0.16).delay(0.10)) { flash = 0 }
 withAnimation(.easeOut(duration: 0.2)) { loom = 0 }
 Haptics.impact()
 }
 // Post hit-stop: the world erupts
 after(T.impact) {
 withAnimation(.linear(duration: 0.64)) { screenShake = 1 }
 shockOpacity = 0.9
 withAnimation(.easeOut(duration: 0.52)) { shockScale = 5.2; shockOpacity = 0 }
 // fracture propagates outward ring by ring
 for ring in 0...CrackField.ringCount {
 after(Double(ring) * 0.022) { ringsShown = ring }
 }
 }
 after(T.logoIn) {
 withAnimation(.spring(response: 0.5, dampingFraction: 0.62)) { showLogo = true }
 }
 after(T.wordmarkIn) {
 withAnimation(.easeOut(duration: 0.62)) { showWordmark = true }
 }
 after(T.crackFade) {
 withAnimation(.easeInOut(duration: 0.7)) { crackOpacity = 0.34 }
 }
 after(T.aftershock) {
 showAftershock = true
 withAnimation(.linear(duration: 0.14)) { settleShake = 1 }
 Haptics.settleTick()
 }
 after(T.loadbarIn) {
 loadbarVisible = true
 withAnimation(.easeInOut(duration: 0.9).delay(0.1)) { loadProgress = 1 }
 }
 after(T.homeIn + 0.6) { onFinished?() }
 }

 private func after(_ s: Double, _ block: @escaping () -> Void) {
 DispatchQueue.main.asyncAfter(deadline: .now() + s, execute: block)
 }
}

// MARK: - Ball flight (iOS 17 KeyframeAnimator)

private struct BallState {
 var offset: CGSize = .zero // unit offsets × screen size
 var scale: CGFloat = 0.09
 var rotation: Angle = .degrees(-14)
 var blur: CGFloat = 0
 var opacity: Double = 0
 var squashX: CGFloat = 1
}

private struct BallView: View {
 let trigger: Int
 let size: CGSize

 var body: some View {
 KeyframeAnimator(initialValue: BallState(), trigger: trigger) { s in
 Image("SoccerBall")
 .resizable().scaledToFit()
 .frame(width: 300)
 .scaleEffect(x: s.scale * s.squashX, y: s.scale)
 .rotationEffect(s.rotation)
 .blur(radius: s.blur)
 .opacity(s.opacity)
 .position(x: size.width * (0.5 + s.offset.width),
 y: size.height * (0.47 + s.offset.height))
 } keyframes: { _ in
 // Curving approach (accelerating), 70ms hit-stop hold, recoil + fall away
 KeyframeTrack(\.offset) {
 LinearKeyframe(CGSize(width: -0.03, height: 0.12), duration: T.flight * 0.22)
 CubicKeyframe(CGSize(width: -0.05, height: 0.014), duration: T.flight * 0.38)
 CubicKeyframe(CGSize(width: -0.025, height: 0.005), duration: T.flight * 0.25)
 CubicKeyframe(.zero, duration: T.flight * 0.15)
 LinearKeyframe(.zero, duration: T.hitStop) // hit-stop
 CubicKeyframe(CGSize(width: 0.03, height: 0.20), duration: T.recoil * 0.55)
 CubicKeyframe(CGSize(width: 0.08, height: 1.05), duration: T.recoil * 0.45)
 }
 KeyframeTrack(\.scale) {
 LinearKeyframe(0.22, duration: T.flight * 0.22)
 CubicKeyframe(0.55, duration: T.flight * 0.38)
 CubicKeyframe(0.90, duration: T.flight * 0.25)
 CubicKeyframe(1.16, duration: T.flight * 0.15)
 LinearKeyframe(1.16, duration: T.hitStop) // hit-stop
 CubicKeyframe(0.86, duration: T.recoil * 0.55)
 CubicKeyframe(0.50, duration: T.recoil * 0.45)
 }
 KeyframeTrack(\.squashX) {
 LinearKeyframe(1.0, duration: T.flight)
 LinearKeyframe(1.0, duration: T.hitStop * 0.3)
 LinearKeyframe(1.10, duration: T.hitStop * 0.7) // squash at contact
 CubicKeyframe(1.0, duration: 0.2)
 }
 KeyframeTrack(\.rotation) {
 LinearKeyframe(.degrees(30), duration: T.flight * 0.22)
 LinearKeyframe(.degrees(112), duration: T.flight * 0.38)
 LinearKeyframe(.degrees(172), duration: T.flight * 0.25)
 LinearKeyframe(.degrees(210), duration: T.flight * 0.15)
 LinearKeyframe(.degrees(210), duration: T.hitStop) // hit-stop
 LinearKeyframe(.degrees(276), duration: T.recoil * 0.55)
 LinearKeyframe(.degrees(370), duration: T.recoil * 0.45)
 }
 KeyframeTrack(\.blur) {
 LinearKeyframe(0.4, duration: T.flight * 0.22)
 LinearKeyframe(1.4, duration: T.flight * 0.38)
 LinearKeyframe(2.4, duration: T.flight * 0.25)
 LinearKeyframe(0.0, duration: T.flight * 0.15) // sharp at contact
 LinearKeyframe(0.0, duration: T.hitStop + T.recoil * 0.55)
 LinearKeyframe(2.5, duration: T.recoil * 0.45)
 }
 KeyframeTrack(\.opacity) {
 LinearKeyframe(1.0, duration: 0.12)
 LinearKeyframe(1.0, duration: T.flight - 0.12 + T.hitStop + T.recoil * 0.55)
 LinearKeyframe(0.0, duration: T.recoil * 0.45)
 }
 }
 }
}

// MARK: - Procedural shattered glass

struct CrackSegment {
 let path: Path
 let width: CGFloat
 let opacity: Double
 let ring: Int
 let glow: Bool
}

struct CrackShard {
 let path: Path
 let opacity: Double
 let ring: Int
}

struct CrackField {
 static let ringCount = 7
 let center: CGPoint
 var segments: [CrackSegment] = []
 var shards: [CrackShard] = []
 var aftershock: [CrackSegment] = []

 static func generate(in size: CGSize) -> CrackField {
 let cx = size.width * 0.5, cy = size.height * 0.47
 let center = CGPoint(x: cx, y: cy)
 var field = CrackField(center: center)
 let A = 17, R = ringCount
 let k = size.width / 390.0 // scale radii to screen width

 var angles: [Double] = []
 for a in 0..<A { angles.append(Double(a) / Double(A) * .pi * 2 + .random(in: -0.13...0.13)) }
 var radii: [Double] = [13 * k]
 for _ in 1..<R { radii.append(radii.last! + .random(in: 38...92) * k) }

 var node = [[CGPoint]](repeating: [], count: A)
 for a in 0..<A {
 for r in 0..<R {
 let rr = radii[r] * .random(in: 0.84...1.20)
 let ang = angles[a] + .random(in: -0.055...0.055) * Double(r)
 node[a].append(CGPoint(x: cx + Foundation.cos(ang) * rr, y: cy + Foundation.sin(ang) * rr))
 }
 }

 // fine jagged polyline between two points
 func jag(_ p: CGPoint, _ q: CGPoint, _ amt: CGFloat) -> Path {
 var path = Path(); path.move(to: p)
 let dx = q.x - p.x, dy = q.y - p.y
 let len = max(1, hypot(dx, dy))
 let px = -dy / len, py = dx / len
 let n = 2 + Int(len / 26)
 for i in 1..<n {
 let t = CGFloat(i) / CGFloat(n)
 let j = CGFloat.random(in: -amt...amt)
 path.addLine(to: CGPoint(x: p.x + dx * t + px * j, y: p.y + dy * t + py * j))
 }
 path.addLine(to: q)
 return path
 }

 func seg(_ p: Path, w: CGFloat, op: Double, glow: Bool, ring: Int) {
 field.segments.append(.init(path: p, width: w, opacity: op, ring: min(ring, R - 1), glow: glow))
 }

 // translucent shard facets — glass catching the light
 for a in 0..<A {
 for r in 0..<(R - 1) {
 var o = r < 2 ? Double.random(in: 0.03...0.13) : Double.random(in: 0...0.04)
 if Double.random(in: 0...1) < 0.10 { o += 0.07 }
 guard o > 0.012 else { continue }
 var p = Path()
 p.move(to: node[a][r]); p.addLine(to: node[(a + 1) % A][r])
 p.addLine(to: node[(a + 1) % A][r + 1]); p.addLine(to: node[a][r + 1]); p.closeSubpath()
 field.shards.append(.init(path: p, opacity: o, ring: r))
 }
 }
 // radial spokes — thick at impact, tapering to hairline
 for a in 0..<A {
 var prev = center
 for r in 0..<R {
 let w = (2.4 * (1 - CGFloat(r) / CGFloat(R)) + 0.45) * .random(in: 0.85...1.20)
 seg(jag(prev, node[a][r], 3.2), w: w, op: min(1, 0.98 - Double(r) * 0.07), glow: r < 3, ring: r)
 prev = node[a][r]
 }
 // hairline extension past the screen edge
 let last = node[a][R - 1], p2 = node[a][R - 2]
 let dx = last.x - p2.x, dy = last.y - p2.y
 let len = max(1, hypot(dx, dy))
 let ext = CGPoint(x: last.x + dx / len * 500, y: last.y + dy / len * 500)
 seg(jag(last, ext, 4), w: 0.5, op: 0.55, glow: false, ring: R - 1)
 // branch cracks
 if Bool.random() || Double.random(in: 0...1) < 0.2 {
 let rb = Int.random(in: 1...3)
 let from = node[a][rb]
 let bang = angles[a] + (Bool.random() ? 1 : -1) * .random(in: 0.45...0.95)
 let blen = CGFloat.random(in: 34...100) * k
 let to = CGPoint(x: from.x + Foundation.cos(bang) * blen, y: from.y + Foundation.sin(bang) * blen)
 seg(jag(from, to, 2.6), w: .random(in: 0.55...1.05), op: 0.7, glow: false, ring: rb)
 }
 }
 // concentric fracture rings — jagged, occasionally broken
 for r in 1..<R {
 for a in 0..<A {
 if r > 3 && Double.random(in: 0...1) < 0.14 { continue }
 let w = max(0.35, (CGFloat.random(in: 0.4...1.15)) * (1.15 - CGFloat(r) * 0.09))
 seg(jag(node[a][r], node[(a + 1) % A][r], 2.8), w: w, op: .random(in: 0.5...0.85), glow: false, ring: r)
 }
 }
 // pulverized micro-cracks at the impact core
 for _ in 0..<16 {
 let ang = Double.random(in: 0...(2 * .pi))
 let r0 = CGFloat.random(in: 3...12), r1 = r0 + .random(in: 5...20)
 var p = Path()
 p.move(to: CGPoint(x: cx + Foundation.cos(ang) * r0, y: cy + Foundation.sin(ang) * r0))
 p.addLine(to: CGPoint(x: cx + Foundation.cos(ang) * r1, y: cy + Foundation.sin(ang) * r1))
 seg(p, w: .random(in: 0.5...1.4), op: 0.9, glow: false, ring: 0)
 }
 // aftershock — late settling cracks
 for _ in 0..<3 {
 let a = Int.random(in: 0..<A), rb = Int.random(in: 2...4)
 let from = node[a][rb]
 let bang = angles[a] + (Bool.random() ? 1 : -1) * .random(in: 0.6...1.1)
 let blen = CGFloat.random(in: 50...130) * k
 let to = CGPoint(x: from.x + Foundation.cos(bang) * blen, y: from.y + Foundation.sin(bang) * blen)
 field.aftershock.append(.init(path: jag(from, to, 3), width: 0.6, opacity: 0.8, ring: 0, glow: false))
 }
 return field
 }
}

private struct CrackCanvas: View {
 let field: CrackField
 let ringsShown: Int
 let showAftershock: Bool

 var body: some View {
 Canvas { ctx, _ in
 for shard in field.shards where shard.ring < ringsShown {
 ctx.fill(shard.path, with: .color(.white.opacity(shard.opacity)))
 }
 for s in field.segments where s.ring < ringsShown {
 let dark = s.path.applying(.init(translationX: 0.7, y: 0.9))
 ctx.stroke(dark, with: .color(.black.opacity(0.6)),
 style: .init(lineWidth: s.width + 0.7, lineCap: .round, lineJoin: .round))
 if s.glow {
 ctx.stroke(s.path, with: .color(.white.opacity(0.10)),
 style: .init(lineWidth: s.width * 3.4, lineCap: .round))
 }
 ctx.stroke(s.path, with: .color(.white.opacity(s.opacity)),
 style: .init(lineWidth: s.width, lineCap: .round, lineJoin: .round))
 }
 if showAftershock {
 for s in field.aftershock {
 let dark = s.path.applying(.init(translationX: 0.7, y: 0.9))
 ctx.stroke(dark, with: .color(.black.opacity(0.6)),
 style: .init(lineWidth: 1.3, lineCap: .round))
 ctx.stroke(s.path, with: .color(.white.opacity(s.opacity)),
 style: .init(lineWidth: s.width, lineCap: .round))
 }
 }
 if ringsShown > 0 {
 let glow = Path(ellipseIn: CGRect(x: field.center.x - 38, y: field.center.y - 38, width: 76, height: 76))
 ctx.fill(glow, with: .radialGradient(
 Gradient(stops: [.init(color: .white.opacity(0.9), location: 0),
 .init(color: .white.opacity(0.25), location: 0.35),
 .init(color: .clear, location: 1)]),
 center: field.center, startRadius: 0, endRadius: 38))
 ctx.fill(Path(ellipseIn: CGRect(x: field.center.x - 2.6, y: field.center.y - 2.6, width: 5.2, height: 5.2)),
 with: .color(.white))
 }
 }
 .ignoresSafeArea()
 }
}

// MARK: - Decaying screen shake

private struct ShakeEffect: GeometryEffect {
 var travel: CGFloat // max px displacement
 var progress: CGFloat // animate 0 → 1
 var animatableData: CGFloat {
 get { progress }
 set { progress = newValue }
 }
 func effectValue(size: CGSize) -> ProjectionTransform {
 guard progress > 0, progress < 1 else { return ProjectionTransform(.identity) }
 let decay = pow(1 - progress, 1.6)
 let x = sin(progress * .pi * 22) * travel * decay
 let y = cos(progress * .pi * 27) * travel * 0.75 * decay
 let rot = sin(progress * .pi * 16) * 0.018 * decay
 let t = CGAffineTransform(translationX: x, y: y).rotated(by: rot)
 return ProjectionTransform(t)
 }
}

// MARK: - Haptics

private enum Haptics {
 private static let heavy = UIImpactFeedbackGenerator(style: .heavy)
 private static let rigid = UIImpactFeedbackGenerator(style: .rigid)

 static func prepare() { heavy.prepare(); rigid.prepare() }

 /// Heavy hit followed by a decaying rumble — matches the screen-shake envelope.
 static func impact() {
 heavy.impactOccurred(intensity: 1.0)
 let ticks: [(Double, CGFloat)] = [(0.07, 0.8), (0.15, 0.6), (0.24, 0.45), (0.36, 0.3)]
 for (t, intensity) in ticks {
 DispatchQueue.main.asyncAfter(deadline: .now() + t) {
 rigid.impactOccurred(intensity: intensity)
 }
 }
 }

 /// Small tick when the late aftershock crack creaks in.
 static func settleTick() {
 rigid.impactOccurred(intensity: 0.35)
 }
}

// MARK: - Preview

#Preview {
 MFEliteOpeningView()
}
