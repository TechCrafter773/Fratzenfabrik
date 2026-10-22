import SwiftUI

/// Malt die Schmink-Designs. Jede Ebene entspricht genau einem Schritt der Anleitung,
/// so kann man ein Design Schritt für Schritt auf dem Gesicht entstehen lassen.
enum FacePainter {
    typealias Layer = (Painter) -> Void

    static func draw(
        _ id: DesignID,
        face: FaceGeometry,
        in ctx: GraphicsContext,
        opacity: Double = 1,
        visibleSteps: Int? = nil,
        pulseLast: Bool = false,
        time: Double = 0
    ) {
        let all = layers(for: id)
        let count = max(0, min(visibleSteps ?? all.count, all.count))
        for i in 0..<count {
            var a = opacity
            if pulseLast, i == count - 1 {
                a *= 0.45 + 0.55 * (sin(time * 4) + 1) / 2
            }
            all[i](Painter(ctx: ctx, face: face, alpha: a, time: time))
        }
    }

    static func layers(for id: DesignID) -> [Layer] {
        switch id {
        case .ghost: ghost
        case .cat: cat
        case .pumpkin: pumpkin
        case .witch: witch
        case .spiderweb: spiderweb
        case .bat: bat
        case .vampire: vampire
        case .skeleton: skeleton
        case .frankenstein: frankenstein
        }
    }

    // MARK: - 👻 Gespenst

    static let ghost: [Layer] = [
        { p in
            let f = p.face
            p.without(f.eyeHoles()).fill(f.faceOval(), Paint.white.color, opacity: 0.94, soft: 0.04)
        },
        { p in
            let f = p.face
            let paths = f.eyes.flatMap { e -> [Path] in
                let c = e.center
                var drip = Path()
                drip.move(to: pt(c.x - 0.23, c.y + 0.16))
                drip.addQuadCurve(to: pt(c.x, c.y + 0.64), control: pt(c.x - 0.16, c.y + 0.5))
                drip.addQuadCurve(to: pt(c.x + 0.23, c.y + 0.16), control: pt(c.x + 0.16, c.y + 0.5))
                drip.closeSubpath()
                return [ellipse(pt(c.x, c.y + 0.04), 0.34, 0.3), drip]
            }
            p.without(f.eyeHoles(padX: 0.02, padY: 0.03)).fill(paths, Paint.black.color, soft: 0.01)
        },
        { p in
            let f = p.face
            let rx = max(0.2, f.mouthHalfWidth * 0.62)
            let ry = max(0.27, (f.mouthBottom - f.mouthTop) / 2 + 0.13)
            p.fill(ellipse(pt(f.mouthCenter.x, f.mouthCenter.y + 0.03), rx, ry), Paint.black.color)
        },
        { p in
            let f = p.face
            let cheeks = [-1.0, 1.0].map { (s: CGFloat) in ellipse(pt(s * f.faceHalfWidth * 0.72, 0.72), 0.2, 0.36) }
            p.within(f.faceOval()).fill(cheeks, Paint.grey.color, opacity: 0.55, soft: 0.12)
        },
    ]

    // MARK: - 🐱 Katze

    private static func muzzleY(_ f: FaceGeometry) -> CGFloat { (f.noseTip.y + f.mouthTop) / 2 + 0.02 }

    static let cat: [Layer] = [
        { p in
            let f = p.face
            let y = FacePainter.muzzleY(f)
            let puffs = [-1.0, 1.0].map { (s: CGFloat) in circle(pt(f.noseTip.x + s * 0.19, y), 0.21) }
            p.without(f.mouthPath()).fill(puffs, Paint.white.color, opacity: 0.92, soft: 0.03)
        },
        { p in
            let f = p.face
            let n = f.noseTip
            let nose = polygon([pt(n.x - 0.15, n.y - 0.12), pt(n.x + 0.15, n.y - 0.12), pt(n.x, n.y + 0.06)])
            p.fill(nose, Paint.pink.color, opacity: 0.97, soft: 0.005)
            p.stroke(nose, Paint.black.color, width: 0.025)
            p.stroke(line(pt(n.x, n.y + 0.06), pt(n.x, f.mouthTop + 0.01)), Paint.black.color, width: 0.03)
        },
        { p in
            let f = p.face
            let n = f.noseTip
            let y = FacePainter.muzzleY(f)
            var whiskers: [Path] = []
            var dots: [Path] = []
            for s in [-1.0, 1.0] as [CGFloat] {
                for ki in 0..<3 {
                    let k = CGFloat(ki)
                    let start = pt(n.x + s * 0.32, y - 0.06 + k * 0.08)
                    let end = pt(n.x + s * 1.02, y - 0.25 + k * 0.18)
                    let wiggle = CGFloat(sin(p.time * 3 + Double(ki))) * 0.015
                    let ctrl = pt((start.x + end.x) / 2, (start.y + end.y) / 2 - 0.07 + wiggle)
                    whiskers.append(curve(start, ctrl, end))
                }
                for ji in 0..<3 {
                    let j = CGFloat(ji)
                    dots.append(circle(pt(n.x + s * (0.11 + j * 0.08), y + (j == 1 ? -0.05 : 0.03)), 0.022))
                }
            }
            p.stroke(whiskers, Paint.black.color, width: 0.028)
            p.fill(dots, Paint.black.color, soft: 0.003)
        },
        { p in
            let f = p.face
            let flicks = f.eyes.map { e -> Path in
                let side: CGFloat = e.center.x < 0 ? -1 : 1
                let corner = pt(e.center.x + side * (e.halfWidth + 0.03), e.center.y)
                var path = Path()
                path.move(to: pt(e.center.x, e.center.y + e.halfHeight + 0.05))
                path.addQuadCurve(to: corner, control: pt(e.center.x + side * e.halfWidth * 0.8, e.center.y + e.halfHeight + 0.05))
                path.addLine(to: pt(corner.x + side * 0.2, corner.y - 0.17))
                return path
            }
            p.without(f.eyeHoles(padX: 0.0, padY: 0.01)).stroke(flicks, Paint.black.color, width: 0.04)
        },
    ]

    // MARK: - 🎃 Kürbis

    static let pumpkin: [Layer] = [
        { p in
            let f = p.face
            p.without(f.eyeHoles()).fill(f.faceOval(), Paint.orange.color, opacity: 0.93, soft: 0.04)
        },
        { p in
            let f = p.face
            let ridges = [-0.78, -0.3, 0.3, 0.78].map { (x0: CGFloat) -> Path in
                curve(pt(x0 * 0.55, f.foreheadTop + 0.08),
                      pt(x0 * 1.3, (f.foreheadTop + f.chin) / 2),
                      pt(x0 * 0.6, f.chin - 0.08))
            }
            p.within(f.faceOval()).without(f.eyeHoles()).stroke(ridges, Paint.darkOrange.color, width: 0.06, opacity: 0.8, soft: 0.02)
        },
        { p in
            let f = p.face
            var shapes = f.eyes.map { e in
                polygon([pt(e.center.x, e.center.y - 0.52),
                         pt(e.center.x - 0.37, e.center.y + 0.2),
                         pt(e.center.x + 0.37, e.center.y + 0.2)])
            }
            let n = f.noseTip
            shapes.append(polygon([pt(n.x, n.y - 0.26), pt(n.x - 0.16, n.y + 0.04), pt(n.x + 0.16, n.y + 0.04)]))
            p.without(f.eyeHoles(padX: 0.02, padY: 0.03)).fill(shapes, Paint.black.color)
        },
        { p in
            let f = p.face
            let m = f.mouthCenter
            let w = max(0.62, f.mouthHalfWidth + 0.28)
            var grin = Path()
            let teeth = 8
            for i in 0...teeth {
                let x = m.x - w + 2 * w * CGFloat(i) / CGFloat(teeth)
                let edge = abs(x - m.x) / w
                let y = m.y - 0.1 - edge * edge * 0.18 + (i % 2 == 1 ? 0.12 : 0)
                if i == 0 { grin.move(to: pt(x, y)) } else { grin.addLine(to: pt(x, y)) }
            }
            grin.addQuadCurve(to: pt(m.x - w, m.y - 0.28), control: pt(m.x, m.y + 0.75))
            grin.closeSubpath()
            p.fill(grin, Paint.black.color)
        },
        { p in
            let f = p.face
            let top = f.foreheadTop
            var stem = Path(roundedRect: CGRect(x: -0.08, y: top - 0.02, width: 0.17, height: 0.34), cornerRadius: 0.05)
            stem.addPath(ellipse(pt(0.22, top + 0.16), 0.15, 0.07))
            p.fill(stem, Paint.green.color, opacity: 0.97, soft: 0.006)
            var curl = Path()
            for i in 0...30 {
                let a = CGFloat(i) / 30 * .pi * 3
                let r = 0.02 + CGFloat(i) / 30 * 0.09
                let q = pt(-0.2 + cos(a) * r, top + 0.15 + sin(a) * r)
                if i == 0 { curl.move(to: q) } else { curl.addLine(to: q) }
            }
            p.stroke(curl, Paint.darkGreen.color, width: 0.022)
            let shine = [-1.0, 1.0].flatMap { (s: CGFloat) -> [Path] in
                [circle(pt(s * 0.72, 0.44), 0.06), circle(pt(s * 0.62, 0.58), 0.035)]
            }
            p.fill(shine, Paint.yellow.color, opacity: 0.9, soft: 0.01)
        },
    ]

    // MARK: - 🧙 Hexe

    static let witch: [Layer] = [
        { p in
            let f = p.face
            p.without(f.eyeHoles()).without(f.mouthPath()).fill(f.faceOval(), Paint.paleGreen.color, opacity: 0.8, soft: 0.05)
        },
        { p in
            let f = p.face
            let lids = f.eyes.map { e in ellipse(pt(e.center.x, (e.center.y + f.browY) / 2), e.halfWidth + 0.13, 0.24) }
            p.without(f.eyeHoles(padY: 0.03)).fill(lids, Paint.purple.color, opacity: 0.75, soft: 0.07)
        },
        { p in
            let f = p.face
            let c = pt(-f.faceHalfWidth * 0.62, 0.68)
            var spiral = Path()
            for i in 0...60 {
                let a = CGFloat(i) / 60 * .pi * 5
                let r = CGFloat(i) / 60 * 0.22
                let q = pt(c.x + cos(a) * r, c.y + sin(a) * r)
                if i == 0 { spiral.move(to: q) } else { spiral.addLine(to: q) }
            }
            p.stroke(spiral, Paint.purple.color, width: 0.035)
            let x = f.faceHalfWidth * 0.62
            let twinkle = CGFloat(sin(p.time * 2)) * 0.15
            p.fill([star(pt(x, 0.55), 0.14, rotation: twinkle), star(pt(x + 0.18, 0.88), 0.08, rotation: -twinkle)],
                   Paint.purple.color, soft: 0.004)
        },
        { p in
            let f = p.face
            p.fill(f.mouthPath(), Color(hex: 0x4B1F7A), opacity: 0.92, soft: 0.006)
            let n = f.noseTip
            p.fill(circle(pt(n.x + 0.18, n.y - 0.14), 0.05), Paint.brown.color, opacity: 0.97, soft: 0.004)
            p.fill(circle(pt(n.x + 0.165, n.y - 0.16), 0.015), Paint.white.color, opacity: 0.6, soft: 0.003)
            let sparkles = f.eyes.flatMap { e -> [Path] in
                (0..<4).map { i -> Path in
                    let a = Double(i) * 1.7 + (e.center.x < 0 ? 0 : 0.9)
                    return star(pt(e.center.x + CGFloat(cos(a)) * 0.25, (e.center.y + f.browY) / 2 + CGFloat(sin(a)) * 0.08),
                                0.025 + 0.015 * CGFloat((sin(p.time * 3 + a) + 1) / 2), points: 4)
                }
            }
            p.without(f.eyeHoles()).fill(sparkles, Paint.glitter.color, soft: 0.002)
        },
    ]

    // MARK: - 🕸️ Spinnennetz

    private static let webAngles: [CGFloat] = [-55, -92, -128, -162, 165, 132, 100].map { $0 * .pi / 180 }
    private static let webRings: [CGFloat] = [0.22, 0.42, 0.63, 0.86]

    private static func webCenter(_ f: FaceGeometry) -> CGPoint {
        pt(f.leftEye.center.x - f.leftEye.halfWidth - 0.08, f.leftEye.center.y - 0.02)
    }

    private static func webPoint(_ c: CGPoint, _ angle: CGFloat, _ r: CGFloat) -> CGPoint {
        pt(c.x + cos(angle) * r, c.y + sin(angle) * r)
    }

    static let spiderweb: [Layer] = [
        { p in
            let f = p.face
            let c = FacePainter.webCenter(f)
            let spokes = FacePainter.webAngles.map { line(c, FacePainter.webPoint(c, $0, 1.0)) }
            p.within(f.faceOval(inset: -0.05)).without(f.eyeHoles()).stroke(spokes, Paint.black.color, width: 0.026)
        },
        { p in
            let f = p.face
            let c = FacePainter.webCenter(f)
            var threads: [Path] = []
            for r in FacePainter.webRings {
                for i in 0..<(FacePainter.webAngles.count - 1) {
                    let a1 = FacePainter.webAngles[i], a2 = FacePainter.webAngles[i + 1]
                    threads.append(curve(FacePainter.webPoint(c, a1, r), FacePainter.webPoint(c, (a1 + a2) / 2, r * 0.78), FacePainter.webPoint(c, a2, r)))
                }
            }
            p.within(f.faceOval(inset: -0.05)).without(f.eyeHoles()).stroke(threads, Paint.black.color, width: 0.02)
        },
        { p in
            let f = p.face
            let s = pt(f.faceHalfWidth * 0.6, 0.72)
            var legs: [Path] = []
            for side in [-1.0, 1.0] as [CGFloat] {
                for k in 0..<4 {
                    let kk = CGFloat(k)
                    let wiggle = CGFloat(sin(p.time * 9 + Double(k) + Double(side))) * 0.015
                    var leg = Path()
                    leg.move(to: pt(s.x + side * 0.05, s.y - 0.07 + kk * 0.05))
                    leg.addLine(to: pt(s.x + side * 0.2, s.y - 0.17 + kk * 0.09 + wiggle))
                    leg.addLine(to: pt(s.x + side * 0.27, s.y - 0.02 + kk * 0.1 + wiggle))
                    legs.append(leg)
                }
            }
            p.stroke(legs, Paint.black.color, width: 0.022)
            p.fill([ellipse(s, 0.1, 0.12), circle(pt(s.x, s.y - 0.15), 0.065)], Paint.black.color, opacity: 0.97, soft: 0.004)
            p.fill([circle(pt(s.x - 0.025, s.y - 0.16), 0.014), circle(pt(s.x + 0.025, s.y - 0.16), 0.014)],
                   Paint.white.color, soft: 0.002)
        },
        { p in
            let f = p.face
            let c = FacePainter.webCenter(f)
            var drops: [Path] = []
            for (ri, r) in FacePainter.webRings.enumerated() where ri % 2 == 1 {
                for (ai, a) in FacePainter.webAngles.enumerated() where (ai + ri) % 2 == 0 {
                    let twinkle = CGFloat((sin(p.time * 3 + Double(ai * 7 + ri)) + 1) / 2)
                    drops.append(star(FacePainter.webPoint(c, a, r), 0.03 + 0.02 * twinkle, points: 4))
                }
            }
            p.within(f.faceOval(inset: -0.05)).without(f.eyeHoles()).fill(drops, Paint.glitter.color, soft: 0.003)
        },
    ]

    // MARK: - 🦇 Fledermaus

    private static func batPaths(_ f: FaceGeometry, grow: CGFloat = 1) -> [Path] {
        let b = f.browY
        var half = Path()
        half.move(to: pt(0, b - 0.02))
        half.addLine(to: pt(0.06, b - 0.07))
        half.addLine(to: pt(0.1, b - 0.29))
        half.addLine(to: pt(0.15, b - 0.05))
        half.addQuadCurve(to: pt(1.05, b - 0.4), control: pt(0.55, b - 0.33))
        half.addQuadCurve(to: pt(0.8, 0.03), control: pt(0.82, -0.28))
        half.addQuadCurve(to: pt(0.5, 0.18), control: pt(0.63, -0.02))
        half.addQuadCurve(to: pt(0.18, 0.16), control: pt(0.34, 0.04))
        half.addQuadCurve(to: pt(0, 0.3), control: pt(0.1, 0.3))
        half.closeSubpath()
        let scale = CGAffineTransform(translationX: 0, y: -0.15).scaledBy(x: grow, y: grow).translatedBy(x: 0, y: 0.15)
        let right = half.applying(scale)
        return [right, mirrored(right), ellipse(pt(0, (b + 0.3) / 2), 0.12 * grow, (0.3 - b) / 2 * grow)]
    }

    static let bat: [Layer] = [
        { p in
            let f = p.face
            p.without(f.eyeHoles()).fill(FacePainter.batPaths(f, grow: 1.15), Paint.purple.color, opacity: 0.8, soft: 0.07)
        },
        { p in
            let f = p.face
            p.without(f.eyeHoles(padX: 0.03, padY: 0.04)).fill(FacePainter.batPaths(f), Paint.black.color, soft: 0.006)
        },
        { p in
            let f = p.face
            let b = f.browY
            let veins = [
                curve(pt(0.2, b - 0.04), pt(0.6, b - 0.2), pt(0.98, b - 0.34)),
                curve(pt(0.2, b + 0.02), pt(0.55, b - 0.05), pt(0.8, 0.0)),
            ]
            p.without(f.eyeHoles(padX: 0.05, padY: 0.06))
                .stroke(veins + veins.map { mirrored($0) }, Paint.white.color, width: 0.014, opacity: 0.75)
            p.fill([circle(pt(-0.04, b + 0.07), 0.02), circle(pt(0.04, b + 0.07), 0.02)], Paint.white.color, soft: 0.002)
        },
    ]

    // MARK: - 🧛 Vampir

    static let vampire: [Layer] = [
        { p in
            let f = p.face
            p.without(f.eyeHoles()).without(f.mouthPath()).fill(f.faceOval(), Paint.white.color, opacity: 0.55, soft: 0.05)
        },
        { p in
            let f = p.face
            let shadows = f.eyes.flatMap { e in
                [ellipse(pt(e.center.x, e.center.y + 0.13), e.halfWidth + 0.12, 0.13),
                 ellipse(pt(e.center.x, e.center.y - 0.1), e.halfWidth + 0.08, 0.12)]
            }
            p.without(f.eyeHoles(padY: 0.02)).fill(shadows, Paint.purple.color, opacity: 0.6, soft: 0.06)
        },
        { p in
            let f = p.face
            let top = f.foreheadTop
            var peak = Path()
            peak.move(to: pt(-1.3, top - 0.4))
            peak.addLine(to: pt(1.3, top - 0.4))
            peak.addLine(to: pt(1.3, top + 0.12))
            peak.addQuadCurve(to: pt(0, top + 0.45), control: pt(0.35, top + 0.1))
            peak.addQuadCurve(to: pt(-1.3, top + 0.12), control: pt(-0.35, top + 0.1))
            peak.closeSubpath()
            p.within(f.faceOval(inset: -0.02)).fill(peak, Paint.black.color, soft: 0.01)
        },
        { p in
            p.fill(p.face.mouthPath(), Paint.red.color, opacity: 0.92, soft: 0.006)
        },
        { p in
            let f = p.face
            let top = f.mouthBottom - 0.05
            var fangs: [Path] = []
            for s in [-1.0, 1.0] as [CGFloat] {
                let x = f.mouthCenter.x + s * f.mouthHalfWidth * 0.55
                var fang = Path()
                fang.move(to: pt(x - 0.065, top))
                fang.addQuadCurve(to: pt(x, top + 0.25), control: pt(x - 0.05, top + 0.15))
                fang.addQuadCurve(to: pt(x + 0.065, top), control: pt(x + 0.05, top + 0.15))
                fang.closeSubpath()
                fangs.append(fang)
            }
            p.fill(fangs, Paint.white.color, opacity: 0.98, soft: 0.003)
            p.stroke(fangs, Paint.black.color, width: 0.014)
            let x = f.mouthCenter.x + f.mouthHalfWidth * 0.55
            let drip = CGFloat(p.time.truncatingRemainder(dividingBy: 2.5) / 2.5) * 0.08
            let c = pt(x, top + 0.34 + drip)
            var drop = circle(c, 0.04)
            drop.addPath(polygon([pt(c.x - 0.036, c.y - 0.015), pt(c.x + 0.036, c.y - 0.015), pt(c.x, c.y - 0.1)]))
            p.fill(drop, Paint.red.color, opacity: 0.95, soft: 0.003)
        },
    ]

    // MARK: - 💀 Skelett

    static let skeleton: [Layer] = [
        { p in
            let f = p.face
            p.without(f.eyeHoles()).fill(f.faceOval(), Paint.white.color, opacity: 0.94, soft: 0.04)
        },
        { p in
            let f = p.face
            let sockets = f.eyes.map { e in ellipse(pt(e.center.x, e.center.y - 0.05), 0.36, 0.37) }
            p.without(f.eyeHoles(padX: 0.02, padY: 0.03)).fill(sockets, Paint.black.color, soft: 0.012)
        },
        { p in
            let n = p.face.noseTip
            p.fill([circle(pt(n.x - 0.075, n.y - 0.02), 0.085),
                    circle(pt(n.x + 0.075, n.y - 0.02), 0.085),
                    polygon([pt(n.x - 0.155, n.y - 0.04), pt(n.x + 0.155, n.y - 0.04), pt(n.x, n.y - 0.28)])],
                   Paint.black.color, soft: 0.006)
        },
        { p in
            let f = p.face
            let m = f.mouthCenter
            let w = max(0.62, f.mouthHalfWidth + 0.28)
            func y(_ x: CGFloat) -> CGFloat { m.y - pow((x - m.x) / w, 2) * 0.12 }
            var main = Path()
            for i in 0...20 {
                let x = m.x - w + 2 * w * CGFloat(i) / 20
                if i == 0 { main.move(to: pt(x, y(x))) } else { main.addLine(to: pt(x, y(x))) }
            }
            var teeth: [Path] = []
            let count = 10
            for i in 1..<count {
                let x = m.x - w + 2 * w * CGFloat(i) / CGFloat(count)
                let h = 0.15 * (1 - pow((x - m.x) / w, 2) * 0.55)
                teeth.append(line(pt(x, y(x) - h), pt(x, y(x) + h)))
            }
            p.stroke([main], Paint.black.color, width: 0.035)
            p.stroke(teeth, Paint.black.color, width: 0.024)
        },
        { p in
            let f = p.face
            let cheeks = [-1.0, 1.0].map { (s: CGFloat) in ellipse(pt(s * f.faceHalfWidth * 0.74, 0.66), 0.2, 0.34) }
            p.within(f.faceOval()).without(f.mouthPath(grow: 1.3)).fill(cheeks, Paint.grey.color, opacity: 0.65, soft: 0.08)
        },
    ]

    // MARK: - 🧟 Frankenstein

    static let frankenstein: [Layer] = [
        { p in
            let f = p.face
            p.without(f.eyeHoles()).fill(f.faceOval(), Paint.green.color, opacity: 0.93, soft: 0.04)
        },
        { p in
            let f = p.face
            let top = f.foreheadTop
            var fringe = Path()
            fringe.move(to: pt(-1.4, top - 0.4))
            fringe.addLine(to: pt(1.4, top - 0.4))
            fringe.addLine(to: pt(1.4, top + 0.38))
            let zigs = 9
            for i in 0...zigs {
                let x = 1.2 - 2.4 * CGFloat(i) / CGFloat(zigs)
                fringe.addLine(to: pt(x, top + (i % 2 == 0 ? 0.46 : 0.3)))
            }
            fringe.addLine(to: pt(-1.4, top + 0.38))
            fringe.closeSubpath()
            p.within(f.faceOval(inset: -0.02)).fill(fringe, Paint.black.color, soft: 0.008)
        },
        { p in
            let f = p.face
            let a = pt(-0.6, f.browY - 0.3), b = pt(0.35, f.browY - 0.48)
            p.stroke(curve(a, pt(-0.1, f.browY - 0.32), b), Paint.red.color, width: 0.035, opacity: 0.85)
            let dx = b.x - a.x, dy = b.y - a.y
            let len = hypot(dx, dy)
            let d = pt(dx / len, dy / len)
            let n = pt(-d.y, d.x)
            var stitches: [Path] = []
            for i in 1...5 {
                let t = CGFloat(i) / 6
                let c = pt(a.x + dx * t, a.y + dy * t + sin(t * .pi) * 0.06)
                stitches.append(line(pt(c.x + n.x * 0.08 + d.x * 0.035, c.y + n.y * 0.08 + d.y * 0.035),
                                     pt(c.x - n.x * 0.08 - d.x * 0.035, c.y - n.y * 0.08 - d.y * 0.035)))
                stitches.append(line(pt(c.x + n.x * 0.08 - d.x * 0.035, c.y + n.y * 0.08 - d.y * 0.035),
                                     pt(c.x - n.x * 0.08 + d.x * 0.035, c.y - n.y * 0.08 + d.y * 0.035)))
            }
            p.stroke(stitches, Paint.black.color, width: 0.02)
        },
        { p in
            let f = p.face
            let under = f.eyes.map { e in ellipse(pt(e.center.x, e.center.y + 0.13), e.halfWidth + 0.1, 0.12) }
            let cheeks = [-1.0, 1.0].map { (s: CGFloat) in ellipse(pt(s * f.faceHalfWidth * 0.72, 0.7), 0.18, 0.32) }
            p.without(f.eyeHoles(padY: 0.02)).fill(under, Paint.darkGreen.color, opacity: 0.7, soft: 0.05)
            p.within(f.faceOval()).fill(cheeks, Paint.darkGreen.color, opacity: 0.5, soft: 0.09)
            p.fill(f.mouthPath(), Color(hex: 0x3A3A40), opacity: 0.88, soft: 0.006)
        },
        { p in
            let f = p.face
            let y = f.mouthCenter.y + 0.3
            var bolts: [Path] = []
            var nuts: [Path] = []
            for s in [-1.0, 1.0] as [CGFloat] {
                let x = s * (f.jawHalfWidth + 0.04)
                bolts.append(Path(roundedRect: CGRect(x: x - 0.13, y: y - 0.05, width: 0.26, height: 0.1), cornerRadius: 0.03))
                nuts.append(Path(roundedRect: CGRect(x: x - 0.06 + s * 0.08, y: y - 0.09, width: 0.12, height: 0.18), cornerRadius: 0.025))
            }
            p.fill(bolts + nuts, Paint.grey.color, opacity: 0.97, soft: 0.003)
            p.stroke(bolts + nuts, Paint.black.color, width: 0.016)
        },
    ]
}
