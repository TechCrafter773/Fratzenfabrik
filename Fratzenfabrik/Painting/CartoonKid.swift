import SwiftUI

/// Ein gezeichnetes Probe-Kind, auf dem die Designs ohne Kamera gezeigt werden.
enum CartoonKid {
    static let skin = Color(hex: 0xF6C7A1)
    static let hair = Color(hex: 0x6B3A1E)

    static func draw(_ face: FaceGeometry, in ctx: GraphicsContext, time: Double, blink: Bool = true) {
        let p = Painter(ctx: ctx, face: face, alpha: 1, time: time)
        let f = face

        // Haare hinten & Ohren
        p.fill(ellipse(pt(0, -0.55), 1.38, 1.45), hair, opacity: 1, soft: 0)
        p.fill([ellipse(pt(-f.faceHalfWidth - 0.02, 0.35), 0.17, 0.27),
                ellipse(pt(f.faceHalfWidth + 0.02, 0.35), 0.17, 0.27)], skin, opacity: 1, soft: 0)
        // Hals
        p.fill(Path(CGRect(x: -0.42, y: 1.2, width: 0.84, height: 1.2)), skin.opacity(0.9), opacity: 1, soft: 0)
        // Gesicht
        p.fill(f.faceOval(), skin, opacity: 1, soft: 0)
        // Pony
        var fringe = Path()
        fringe.move(to: pt(-1.2, -0.8))
        fringe.addQuadCurve(to: pt(1.2, -0.8), control: pt(0, -2.4))
        fringe.addQuadCurve(to: pt(0.2, f.foreheadTop + 0.12), control: pt(0.9, f.foreheadTop - 0.05))
        fringe.addQuadCurve(to: pt(-1.2, -0.8), control: pt(-0.7, f.foreheadTop - 0.1))
        p.fill(fringe, hair, opacity: 1, soft: 0)

        // Bäckchen
        p.fill([circle(pt(-0.72, 0.62), 0.16), circle(pt(0.72, 0.62), 0.16)], Color(hex: 0xFF8E8E), opacity: 0.45, soft: 0.05)

        // Augen (blinzeln ab und zu)
        let blinkPhase = time.truncatingRemainder(dividingBy: 4.2)
        let open: CGFloat = blink && blinkPhase < 0.14 ? 0.15 : 1
        for e in f.eyes {
            p.fill(ellipse(e.center, e.halfWidth * 0.95, e.halfHeight * 1.25 * open), .white, opacity: 1, soft: 0)
            if open > 0.5 {
                let look = CGFloat(sin(time * 0.7)) * 0.05
                p.fill(circle(pt(e.center.x + look, e.center.y + 0.01), 0.085), Color(hex: 0x3B2A1A), opacity: 1, soft: 0)
                p.fill(circle(pt(e.center.x + look + 0.03, e.center.y - 0.03), 0.025), .white, opacity: 1, soft: 0)
            }
            p.stroke(ellipse(e.center, e.halfWidth * 0.95, e.halfHeight * 1.25 * open), Color(hex: 0x3B2A1A), width: 0.02, opacity: 0.8, soft: 0)
        }
        // Augenbrauen
        p.stroke([curve(pt(-0.7, f.browY + 0.02), pt(-0.5, f.browY - 0.08), pt(-0.3, f.browY + 0.02)),
                  curve(pt(0.3, f.browY + 0.02), pt(0.5, f.browY - 0.08), pt(0.7, f.browY + 0.02))],
                 hair, width: 0.05, opacity: 1, soft: 0)
        // Nase
        p.stroke(curve(pt(-0.08, f.noseTip.y - 0.02), pt(0, f.noseTip.y + 0.06), pt(0.08, f.noseTip.y - 0.02)),
                 Color(hex: 0xC98B68), width: 0.035, opacity: 1, soft: 0)
        // Mund
        p.fill(f.mouthPath(), Color(hex: 0xC4495C), opacity: 1, soft: 0)
        p.fill(ellipse(pt(0, 1.07), 0.2, 0.05), .white, opacity: 0.9, soft: 0)
    }
}

/// Zeigt ein Design auf dem Probe-Kind. Mit `visibleSteps` nur bis zu einem bestimmten Schritt.
struct DesignPreview: View {
    let design: DesignID
    var visibleSteps: Int? = nil
    var pulseLast = false
    var animated = true

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !animated)) { timeline in
            let t = animated ? timeline.date.timeIntervalSinceReferenceDate : 0
            Canvas { ctx, size in
                let face = FaceGeometry.cartoon(in: CGRect(origin: .zero, size: size).insetBy(dx: 4, dy: 4))
                CartoonKid.draw(face, in: ctx, time: t, blink: animated)
                FacePainter.draw(design, face: face, in: ctx, visibleSteps: visibleSteps, pulseLast: pulseLast, time: t)
            }
        }
        .accessibilityHidden(true)
    }
}
