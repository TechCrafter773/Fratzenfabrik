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
        case .ghostCute: ghostCute
        case .ghostFunny: ghostFunny
        case .ghostScary: ghostScary
        case .batSwarm: batSwarm
        case .cat: cat
        case .pumpkin: pumpkin
        case .witch: witch
        case .spiderweb: spiderweb
        case .bat: bat
        case .vampire: vampire
        case .skeleton: skeleton
        case .frankenstein: frankenstein
        case .cyclops: cyclops
        case .devil: devil
        case .mummy: mummy
        case .werewolf: werewolf
        case .sugarSkull: sugarSkull
        }
    }

    // MARK: - 👻 Süßes Gespensterchen

    static let ghostCute: [Layer] = [
        { p in
            let f = p.face
            p.without(f.eyeHoles()).fill(f.faceOval(), Paint.white.color, opacity: 0.78, soft: 0.05)
        },
        { p in
            let f = p.face
            var rings: [Path] = []
            var lashes: [Path] = []
            for e in f.eyes {
                let rx = e.halfWidth + 0.14
                let ry = max(e.halfHeight + 0.14, 0.25)
                rings.append(ellipse(e.center, rx, ry))
                let outer: CGFloat = e.center.x < 0 ? -1 : 1
                for deg in [-62.0, -38.0, -14.0] {
                    let a = CGFloat(deg) * .pi / 180
                    let base = pt(e.center.x + outer * cos(a) * rx, e.center.y + sin(a) * ry)
                    let tip = pt(base.x + outer * cos(a) * 0.11, base.y + sin(a) * 0.11)
                    lashes.append(line(base, tip))
                }
            }
            let around = p.without(f.eyeHoles(padX: 0.02, padY: 0.03))
            around.stroke(rings, Paint.black.color, width: 0.045)
            around.stroke(lashes, Paint.black.color, width: 0.03)
        },
        { p in
            let f = p.face
            let cheeks = [-1.0, 1.0].map { (s: CGFloat) in circle(pt(s * f.faceHalfWidth * 0.6, 0.6), 0.17) }
            p.fill(cheeks, Paint.pink.color, opacity: 0.75, soft: 0.07)
            let m = f.mouthCenter
            let w = f.mouthHalfWidth + 0.04
            let smile = curve(pt(m.x - w, m.y - 0.03), pt(m.x, m.y + 0.3), pt(m.x + w, m.y - 0.03))
            let dimples = [-1.0, 1.0].map { (s: CGFloat) in
                line(pt(m.x + s * (w - 0.03), m.y - 0.08), pt(m.x + s * (w + 0.04), m.y + 0.01))
            }
            p.stroke([smile] + dimples, Paint.black.color, width: 0.032)
        },
        { p in
            let f = p.face
            let ghosts = [(pt(0.55, f.browY - 0.5), CGFloat(0.15)), (pt(-0.8, 1.0), CGFloat(0.12))]
            let bodies = ghosts.map { miniGhost($0.0, $0.1) }
            p.fill(bodies, Paint.white.color, opacity: 0.98, soft: 0.004)
            p.stroke(bodies, Color(hex: 0xA9B4C8), width: 0.012)
            let faces = ghosts.flatMap { g, r in
                [ellipse(pt(g.x - 0.35 * r, g.y - 0.05 * r), 0.12 * r, 0.18 * r),
                 ellipse(pt(g.x + 0.35 * r, g.y - 0.05 * r), 0.12 * r, 0.18 * r),
                 ellipse(pt(g.x, g.y + 0.4 * r), 0.12 * r, 0.14 * r)]
            }
            p.fill(faces, Paint.black.color, soft: 0.002)
            let twinkle = CGFloat((sin(p.time * 3) + 1) / 2)
            let stars = [star(pt(-0.45, f.browY - 0.5), 0.05 + 0.015 * twinkle, points: 4),
                         star(pt(0.88, 0.45), 0.04 + 0.01 * twinkle, points: 4),
                         star(pt(0.15, f.browY - 0.7), 0.035, points: 4)]
            p.fill(stars, Paint.lightBlue.color, soft: 0.003)
        },
    ]

    // MARK: - 🤪 Glubsch-Gespenst

    static let ghostFunny: [Layer] = [
        { p in
            let f = p.face
            p.without(f.eyeHoles()).fill(f.faceOval(), Paint.white.color, opacity: 0.93, soft: 0.04)
        },
        { p in
            let f = p.face
            let big = ellipse(f.leftEye.center, 0.37, 0.37)
            let small = ellipse(pt(f.rightEye.center.x, f.rightEye.center.y + 0.02), 0.25, 0.25)
            p.without(f.eyeHoles(padX: 0.02, padY: 0.03)).fill([big, small], Paint.black.color, soft: 0.008)
            let brows = [curve(pt(-0.9, -0.55), pt(-0.55, -0.92), pt(-0.18, -0.52)),
                         line(pt(0.24, -0.36), pt(0.82, -0.24))]
            p.stroke(brows, Paint.black.color, width: 0.06)
        },
        { p in
            let f = p.face
            let m = f.mouthCenter
            let ry = max(0.18, (f.mouthBottom - f.mouthTop) / 2 + 0.07)
            p.fill(ellipse(m, f.mouthHalfWidth + 0.05, ry), Paint.black.color, soft: 0.006)
            let x = m.x + 0.06, y = m.y + 0.02
            var tongue = Path()
            tongue.move(to: pt(x - 0.14, y))
            tongue.addLine(to: pt(x - 0.14, y + 0.22))
            tongue.addQuadCurve(to: pt(x + 0.14, y + 0.22), control: pt(x, y + 0.52))
            tongue.addLine(to: pt(x + 0.14, y))
            tongue.closeSubpath()
            p.fill(tongue, Paint.red.color, opacity: 0.97, soft: 0.004)
            p.stroke(line(pt(x, y + 0.06), pt(x, y + 0.27)), Paint.darkRed.color, width: 0.018)
        },
        { p in
            let f = p.face
            let cy: CGFloat = 0.2
            let w = f.faceHalfWidth * 0.97
            var outline = Path()
            for i in 0...120 {
                let a = CGFloat(i) / 120 * 2 * .pi
                let h = sin(a) < 0 ? cy - f.foreheadTop - 0.05 : f.chin - cy - 0.05
                let wobble = 1 + 0.035 * sin(9 * a + CGFloat(p.time) * 2)
                let q = pt(cos(a) * w * wobble, cy + sin(a) * h * wobble)
                if i == 0 { outline.move(to: q) } else { outline.addLine(to: q) }
            }
            p.stroke(outline, Paint.lightBlue.color, width: 0.05)
        },
    ]

    // MARK: - 😱 Schreckgespenst

    static let ghostScary: [Layer] = [
        { p in
            let f = p.face
            let face = p.without(f.eyeHoles())
            face.fill(f.faceOval(), Paint.white.color, opacity: 0.95, soft: 0.04)
            face.within(f.faceOval()).stroke(f.faceOval(inset: 0.12), Paint.grey.color, width: 0.38, opacity: 0.65, soft: 0.14)
        },
        { p in
            let f = p.face
            let halo = f.eyes.map { e in ellipse(pt(e.center.x, e.center.y + 0.05), 0.47, 0.54) }
            let core = f.eyes.map { e in ellipse(pt(e.center.x, e.center.y + 0.05), 0.33, 0.42) }
            let around = p.without(f.eyeHoles(padX: 0.02, padY: 0.03))
            around.fill(halo, Color(hex: 0x3A3542), opacity: 0.6, soft: 0.12)
            around.fill(core, Paint.black.color, opacity: 0.97, soft: 0.03)
        },
        { p in
            let f = p.face
            var drips: [Path] = []
            var blobs: [Path] = []
            for e in f.eyes {
                for (dx, len) in [(CGFloat(-0.13), CGFloat(0.55)), (0.0, 0.88), (0.13, 0.4)] {
                    let start = pt(e.center.x + dx, e.center.y + 0.38)
                    let end = pt(start.x + dx * 0.15, start.y + len)
                    drips.append(line(start, end))
                    blobs.append(circle(end, 0.033))
                }
            }
            p.stroke(drips, Paint.black.color, width: 0.042)
            p.fill(blobs, Paint.black.color, soft: 0.004)
        },
        { p in
            let f = p.face
            let m = f.mouthCenter
            let mouth = ellipse(pt(m.x, m.y + 0.18), max(0.2, f.mouthHalfWidth * 0.7), 0.5)
            p.fill(mouth, Paint.black.color, soft: 0.01)
            let drips = [line(pt(m.x - 0.08, m.y + 0.6), pt(m.x - 0.09, m.y + 0.82)),
                         line(pt(m.x + 0.1, m.y + 0.62), pt(m.x + 0.11, m.y + 0.74))]
            p.stroke(drips, Paint.black.color, width: 0.04)
        },
        { p in
            var cracks: [Path] = []
            for s in [-1.0, 1.0] as [CGFloat] {
                var a = Path()
                a.move(to: pt(s * 0.98, -0.98))
                a.addLine(to: pt(s * 0.76, -0.82))
                a.addLine(to: pt(s * 0.62, -0.9))
                a.addLine(to: pt(s * 0.44, -0.72))
                a.addLine(to: pt(s * 0.3, -0.78))
                cracks.append(a)
                cracks.append(line(pt(s * 0.76, -0.82), pt(s * 0.7, -0.6)))
                var b = Path()
                b.move(to: pt(s * 1.02, -0.25))
                b.addLine(to: pt(s * 0.88, -0.18))
                b.addLine(to: pt(s * 0.86, 0.05))
                b.addLine(to: pt(s * 0.92, 0.2))
                cracks.append(b)
            }
            p.within(p.face.faceOval()).stroke(cracks, Color(hex: 0x5B4A72), width: 0.014, opacity: 0.85)
        },
    ]

    // MARK: - 🐱 Katze

    private static func muzzleY(_ f: FaceGeometry) -> CGFloat { (f.noseTip.y + f.mouthTop) / 2 + 0.02 }

    static let cat: [Layer] = [
        { p in
            let f = p.face
            p.within(f.faceOval()).stroke(f.faceOval(inset: 0.12), Paint.grey.color, width: 0.4, opacity: 0.8, soft: 0.12)
            let top = f.foreheadTop
            let stripes = [line(pt(-0.2, top + 0.1), pt(-0.15, top + 0.42)),
                           line(pt(0, top + 0.06), pt(0, top + 0.52)),
                           line(pt(0.2, top + 0.1), pt(0.15, top + 0.42))]
            p.stroke(stripes, Paint.black.color, width: 0.06, opacity: 0.85, soft: 0.01)
            var tufts: [Path] = []
            for s in [-1.0, 1.0] as [CGFloat] {
                for k in 0..<5 {
                    let y = 0.2 + CGFloat(k) * 0.2
                    tufts.append(line(pt(s * (f.faceHalfWidth - 0.2), y), pt(s * (f.faceHalfWidth + 0.02), y + 0.05)))
                }
            }
            p.within(f.faceOval(inset: -0.05)).stroke(tufts, Color(hex: 0x4A4652), width: 0.022)
        },
        { p in
            let f = p.face
            let y = FacePainter.muzzleY(f)
            let puffs = [circle(pt(f.noseTip.x - 0.21, y), 0.24),
                         circle(pt(f.noseTip.x + 0.21, y), 0.24),
                         ellipse(pt(f.mouthCenter.x, f.mouthBottom + 0.2), 0.22, 0.14)]
            p.without(f.mouthPath()).fill(puffs, Paint.white.color, opacity: 0.95, soft: 0.03)
        },
        { p in
            let f = p.face
            let n = f.noseTip
            let nose = polygon([pt(n.x - 0.16, n.y - 0.13), pt(n.x + 0.16, n.y - 0.13), pt(n.x, n.y + 0.07)])
            p.fill(nose, Paint.pink.color, opacity: 0.98, soft: 0.004)
            p.stroke(nose, Paint.black.color, width: 0.028)
            let lipTop = f.mouthTop + 0.01
            let mouthLines = [
                line(pt(n.x, n.y + 0.07), pt(n.x, lipTop)),
                curve(pt(n.x, lipTop), pt(n.x - 0.06, lipTop + 0.12), pt(n.x - 0.18, lipTop + 0.02)),
                curve(pt(n.x, lipTop), pt(n.x + 0.06, lipTop + 0.12), pt(n.x + 0.18, lipTop + 0.02)),
            ]
            p.stroke(mouthLines, Paint.black.color, width: 0.03)
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
                    let start = pt(n.x + s * 0.36, y - 0.06 + k * 0.08)
                    let end = pt(n.x + s * 1.12, y - 0.3 + k * 0.2)
                    let wiggle = CGFloat(sin(p.time * 3 + Double(ki))) * 0.015
                    let ctrl = pt((start.x + end.x) / 2, (start.y + end.y) / 2 - 0.08 + wiggle)
                    whiskers.append(curve(start, ctrl, end))
                }
                for ji in 0..<3 {
                    let j = CGFloat(ji)
                    dots.append(circle(pt(n.x + s * (0.13 + j * 0.08), y + (ji == 1 ? -0.05 : 0.03)), 0.022))
                }
            }
            p.stroke(whiskers, Paint.black.color, width: 0.026)
            p.fill(dots, Paint.black.color, soft: 0.003)
        },
        { p in
            let f = p.face
            var liner: [Path] = []
            for e in f.eyes {
                let s: CGFloat = e.center.x < 0 ? -1 : 1
                let cx = e.center.x, cy = e.center.y
                let hw = e.halfWidth, hh = e.halfHeight
                var lid = Path()
                lid.move(to: pt(cx - s * hw, cy))
                lid.addQuadCurve(to: pt(cx + s * (hw + 0.04), cy - 0.03), control: pt(cx, cy - hh - 0.14))
                lid.addLine(to: pt(cx + s * (hw + 0.3), cy - 0.24))
                liner.append(lid)
                liner.append(curve(pt(cx + s * hw * 0.2, cy + hh + 0.05), pt(cx + s * hw, cy + hh + 0.03), pt(cx + s * (hw + 0.04), cy - 0.03)))
                liner.append(line(pt(cx - s * hw, cy), pt(cx - s * (hw + 0.09), cy + 0.07)))
            }
            p.without(f.eyeHoles(padX: 0.0, padY: 0.01)).stroke(liner, Paint.black.color, width: 0.045)
            let top = f.foreheadTop
            let outer = [-1.0, 1.0].map { (s: CGFloat) in
                polygon([pt(s * 0.28, top + 0.55), pt(s * 0.92, top + 0.68), pt(s * 0.72, top + 0.02)])
            }
            let inner = [-1.0, 1.0].map { (s: CGFloat) in
                polygon([pt(s * 0.43, top + 0.5), pt(s * 0.79, top + 0.58), pt(s * 0.69, top + 0.2)])
            }
            p.fill(outer, Paint.black.color, soft: 0.006)
            p.fill(inner, Paint.pink.color, soft: 0.006)
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
            let m = f.mouthCenter
            let top = m.y - 0.01
            let len = max(0.3, f.mouthBottom - m.y + 0.2)
            let w: CGFloat = 0.075
            var fangs: [Path] = []
            var shades: [Path] = []
            var shines: [Path] = []
            for s in [-1.0, 1.0] as [CGFloat] {
                let x = m.x + s * f.mouthHalfWidth * 0.42
                let tip = pt(x + s * 0.025, top + len)
                var fang = Path()
                fang.move(to: pt(x - w, top))
                fang.addCurve(to: tip, control1: pt(x - w, top + len * 0.45), control2: pt(x - w * 0.2 + s * 0.02, top + len * 0.85))
                fang.addCurve(to: pt(x + w, top), control1: pt(x + w * 0.4 + s * 0.02, top + len * 0.8), control2: pt(x + w, top + len * 0.4))
                fang.closeSubpath()
                fangs.append(fang)
                // Schatten auf der Seite zur Mundmitte – dadurch wirkt der Zahn rund
                shades.append(curve(pt(x - s * w * 0.6, top + 0.02), pt(x - s * w * 0.55, top + len * 0.55), pt(tip.x - s * 0.01, tip.y - 0.03)))
                shines.append(ellipse(pt(x + s * 0.022, top + len * 0.28), 0.013, 0.045))
            }
            p.fill(fangs, Paint.white.color, opacity: 0.99, soft: 0.002)
            for (fang, shade) in zip(fangs, shades) {
                p.within(fang).stroke(shade, Color(hex: 0xB4B0C2), width: 0.055, opacity: 0.9, soft: 0.02)
            }
            p.fill(shines, .white, opacity: 0.95, soft: 0.003)
            p.stroke(fangs, Color(hex: 0x2A1E2E), width: 0.013)
            // Bluttropfen, der langsam von der rechten Zahnspitze rinnt
            let tipX = m.x + f.mouthHalfWidth * 0.42 + 0.025
            let drip = CGFloat(p.time.truncatingRemainder(dividingBy: 3) / 3) * 0.1
            var blood = Path(roundedRect: CGRect(x: tipX - 0.011, y: top + len - 0.03, width: 0.022, height: 0.09 + drip), cornerRadius: 0.011)
            let dropCenter = pt(tipX, top + len + 0.1 + drip)
            blood.addPath(circle(dropCenter, 0.034))
            blood.addPath(polygon([pt(dropCenter.x - 0.031, dropCenter.y - 0.012), pt(dropCenter.x + 0.031, dropCenter.y - 0.012),
                                   pt(dropCenter.x, dropCenter.y - 0.085)]))
            p.fill(blood, Paint.red.color, opacity: 0.96, soft: 0.003)
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

    // MARK: - 👁️ Zyklop

    private static func cyclopsEye(_ f: FaceGeometry) -> (center: CGPoint, rx: CGFloat, ry: CGFloat) {
        (pt(0, f.browY - 0.52), 0.36, 0.26)
    }

    static let cyclops: [Layer] = [
        { p in
            let e = FacePainter.cyclopsEye(p.face)
            let eye = ellipse(e.center, e.rx, e.ry)
            p.fill(eye, Paint.white.color, opacity: 0.97, soft: 0.006)
            p.stroke(eye, Paint.black.color, width: 0.03)
        },
        { p in
            let e = FacePainter.cyclopsEye(p.face)
            let look = pt(CGFloat(sin(p.time * 0.9)) * 0.12, CGFloat(sin(p.time * 1.3)) * 0.04)
            let c = pt(e.center.x + look.x, e.center.y + look.y)
            let inside = p.within(ellipse(e.center, e.rx, e.ry))
            inside.fill(circle(c, 0.17), Paint.green.color, opacity: 0.97, soft: 0.004)
            inside.fill(circle(c, 0.08), Paint.black.color, opacity: 0.97, soft: 0.003)
            inside.fill(circle(pt(c.x + 0.05, c.y - 0.05), 0.03), Paint.white.color, soft: 0.002)
        },
        { p in
            let e = FacePainter.cyclopsEye(p.face)
            var lashes: [Path] = []
            for i in 0..<7 {
                let a = CGFloat.pi + CGFloat(i + 1) * CGFloat.pi / 8
                let base = pt(e.center.x + cos(a) * e.rx, e.center.y + sin(a) * e.ry)
                let tip = pt(e.center.x + cos(a) * (e.rx + 0.13), e.center.y + sin(a) * (e.ry + 0.13))
                lashes.append(line(base, tip))
            }
            var brow = Path()
            for i in 0...20 {
                let x = -0.5 + CGFloat(i) / 20
                let q = pt(x, e.center.y - e.ry - 0.2 + sin(CGFloat(i) * 0.9) * 0.025 + x * x * 0.2)
                if i == 0 { brow.move(to: q) } else { brow.addLine(to: q) }
            }
            p.stroke(lashes, Paint.black.color, width: 0.025)
            p.stroke(brow, Paint.black.color, width: 0.05)
        },
        { p in
            let f = p.face
            var purple: [Path] = []
            var green: [Path] = []
            let spots: [(CGFloat, CGFloat, CGFloat)] = [(0.72, 0.55, 0.07), (0.88, 0.8, 0.045), (0.6, 0.85, 0.04), (0.95, 0.4, 0.035)]
            for s in [-1.0, 1.0] as [CGFloat] {
                for (i, spot) in spots.enumerated() {
                    let c = circle(pt(s * spot.0 * f.faceHalfWidth / 1.12, spot.1), spot.2)
                    if (i + (s > 0 ? 1 : 0)) % 2 == 0 { purple.append(c) } else { green.append(c) }
                }
            }
            green.append(circle(pt(f.noseTip.x - 0.06, f.noseTip.y - 0.18), 0.03))
            purple.append(circle(pt(f.noseTip.x + 0.07, f.noseTip.y - 0.1), 0.025))
            p.fill(purple, Paint.purple.color, soft: 0.004)
            p.fill(green, Paint.green.color, soft: 0.004)
        },
    ]

    // MARK: - 😈 Feuerteufel

    private static func hornPaths(_ f: FaceGeometry) -> [Path] {
        let top = f.foreheadTop
        return [-1.0, 1.0].map { (s: CGFloat) -> Path in
            var horn = Path()
            horn.move(to: pt(s * 0.22, top + 0.62))
            horn.addQuadCurve(to: pt(s * 0.82, top - 0.32), control: pt(s * 0.18, top - 0.1))
            horn.addQuadCurve(to: pt(s * 0.6, top + 0.62), control: pt(s * 0.64, top + 0.1))
            horn.closeSubpath()
            return horn
        }
    }

    static let devil: [Layer] = [
        { p in
            let f = p.face
            p.without(f.eyeHoles()).without(f.mouthPath()).fill(f.faceOval(), Paint.red.color, opacity: 0.86, soft: 0.05)
        },
        { p in
            let f = p.face
            p.within(f.faceOval()).without(f.eyeHoles())
                .stroke(f.faceOval(inset: 0.1), Paint.darkRed.color, width: 0.42, opacity: 0.9, soft: 0.14)
        },
        { p in
            let f = p.face
            let horns = FacePainter.hornPaths(f)
            p.fill(horns, Paint.darkRed.color, opacity: 0.98, soft: 0.004)
            let top = f.foreheadTop
            for (i, s) in ([-1.0, 1.0] as [CGFloat]).enumerated() {
                let shine = curve(pt(s * 0.32, top + 0.5), pt(s * 0.3, top + 0.02), pt(s * 0.7, top - 0.2))
                p.within(horns[i]).stroke(shine, Color(hex: 0xFF6A7A), width: 0.035, opacity: 0.85, soft: 0.01)
            }
            p.stroke(horns, Paint.black.color, width: 0.026)
        },
        { p in
            let f = p.face
            let b = f.browY
            let brows = [-1.0, 1.0].map { (s: CGFloat) in
                polygon([pt(s * 0.15, b + 0.06), pt(s * 0.52, b - 0.07), pt(s * 0.92, b - 0.38),
                         pt(s * 0.56, b - 0.17), pt(s * 0.2, b - 0.04)])
            }
            p.fill(brows, Paint.black.color, soft: 0.005)
            let bases = [(pt(0, b - 0.3), CGFloat(0.6), CGFloat(0.13)),
                         (pt(-0.24, b - 0.27), 0.4, 0.1),
                         (pt(0.24, b - 0.27), 0.4, 0.1)]
            let flicker = CGFloat(sin(p.time * 7)) * 0.03
            let outerFlames = bases.map { flame($0.0, $0.1 + flicker, $0.2) }
            let innerFlames = bases.map { flame($0.0, ($0.1 + flicker) * 0.55, $0.2 * 0.55) }
            p.fill(outerFlames, Paint.orange.color, opacity: 0.97, soft: 0.006)
            p.fill(innerFlames, Paint.yellow.color, opacity: 0.97, soft: 0.006)
        },
        { p in
            let f = p.face
            let m = f.mouthCenter
            let goatee = polygon([pt(m.x - 0.14, f.mouthBottom + 0.06), pt(m.x + 0.14, f.mouthBottom + 0.06),
                                  pt(m.x + 0.02, min(f.chin - 0.02, f.mouthBottom + 0.52))])
            p.fill(goatee, Paint.black.color, soft: 0.006)
            let tip = pt(m.x + 0.02, min(f.chin - 0.02, f.mouthBottom + 0.52))
            var lines = [curve(tip, pt(tip.x + 0.16, tip.y + 0.04), pt(tip.x + 0.11, tip.y - 0.09))]
            lines += [-1.0, 1.0].map { (s: CGFloat) -> Path in
                let corner = pt(m.x + s * f.mouthHalfWidth, m.y)
                return curve(corner, pt(corner.x + s * 0.1, corner.y + 0.02), pt(corner.x + s * 0.14, corner.y - 0.1))
            }
            p.stroke(lines, Paint.black.color, width: 0.03)
            let diamonds = f.eyes.map { e in
                polygon([pt(e.center.x, e.center.y + 0.24), pt(e.center.x + 0.06, e.center.y + 0.33),
                         pt(e.center.x, e.center.y + 0.42), pt(e.center.x - 0.06, e.center.y + 0.33)])
            }
            p.fill(diamonds, Paint.black.color, soft: 0.004)
        },
    ]

    // MARK: - 🌙 Fledermaus-Schwarm

    private static let swarm: [(CGPoint, CGFloat, CGFloat)] = [
        (pt(0.72, 1.0), 0.1, 0.35), (pt(0.98, 0.55), 0.12, 0.2), (pt(0.92, -0.4), 0.14, 0.0),
        (pt(0.5, -0.9), 0.16, -0.15), (pt(0.0, -1.05), 0.18, -0.25), (pt(-0.45, -0.95), 0.2, -0.35),
    ]

    static let batSwarm: [Layer] = [
        { p in
            let c = pt(-0.82, -0.62)
            p.fill(circle(c, 0.44), Paint.purple.color, opacity: 0.55, soft: 0.1)
            p.fill(circle(c, 0.3), Color(hex: 0xFFF1A8), opacity: 0.97, soft: 0.012)
            p.fill([circle(pt(c.x - 0.1, c.y - 0.05), 0.05), circle(pt(c.x + 0.08, c.y + 0.1), 0.035),
                    circle(pt(c.x + 0.1, c.y - 0.12), 0.025)], Color(hex: 0xE8CF6A), opacity: 0.8, soft: 0.006)
        },
        { p in
            let flap = CGFloat(sin(p.time * 10)) * 0.08
            let bats = FacePainter.swarm.flatMap { batGlyph($0.0, $0.1, $0.2, flap: flap) }
            p.fill(bats, Paint.black.color, soft: 0.004)
        },
        { p in
            let flap = CGFloat(sin(p.time * 10)) * 0.08
            let bats = FacePainter.swarm.flatMap { batGlyph($0.0, $0.1, $0.2, flap: flap) }
            p.stroke(bats, Paint.purple.color, width: 0.025, opacity: 0.6, soft: 0.025)
            let eyes = FacePainter.swarm.suffix(3).flatMap { c, s, _ in
                [circle(pt(c.x - 0.045 * s / 0.16, c.y - 0.02), 0.012 * s / 0.16),
                 circle(pt(c.x + 0.045 * s / 0.16, c.y - 0.02), 0.012 * s / 0.16)]
            }
            p.fill(eyes, Paint.white.color, soft: 0.002)
        },
    ]

    // MARK: - 🩹 Mumie

    private static func mummyEyes(_ f: FaceGeometry) -> Path {
        f.eyeHoles(grow: 1.1, padX: 0.14, padY: 0.12)
    }

    private static func bandages(_ f: FaceGeometry) -> [(path: Path, top: Path)] {
        var result: [(path: Path, top: Path)] = []
        var y = f.foreheadTop + 0.05
        var i = 0
        while y < f.chin + 0.1 {
            let tilt: CGFloat = i % 2 == 0 ? 0.07 : -0.09
            let h: CGFloat = 0.2
            let band = polygon([pt(-1.5, y - tilt), pt(1.5, y + tilt), pt(1.5, y + tilt + h), pt(-1.5, y - tilt + h)])
            result.append((path: band, top: line(pt(-1.5, y - tilt), pt(1.5, y + tilt))))
            y += 0.29
            i += 1
        }
        return result
    }

    static let mummy: [Layer] = [
        { p in
            let f = p.face
            p.without(f.eyeHoles()).fill(f.faceOval(), Paint.beige.color, opacity: 0.8, soft: 0.05)
        },
        { p in
            let f = p.face
            let shadows = f.eyes.map { e in ellipse(e.center, e.halfWidth + 0.2, e.halfHeight + 0.17) }
            p.without(f.eyeHoles()).fill(shadows, Color(hex: 0x2A2422), opacity: 0.85, soft: 0.04)
        },
        { p in
            let f = p.face
            p.within(f.faceOval()).without(FacePainter.mummyEyes(f))
                .fill(FacePainter.bandages(f).map { $0.path }, Paint.white.color, opacity: 0.93, soft: 0.01)
        },
        { p in
            let f = p.face
            p.within(f.faceOval()).without(FacePainter.mummyEyes(f))
                .stroke(FacePainter.bandages(f).map { $0.top }, Paint.grey.color, width: 0.02, opacity: 0.9)
        },
    ]

    // MARK: - 🐺 Werwolf

    private static func muzzle(_ f: FaceGeometry) -> Path {
        ellipse(pt(f.noseTip.x, (f.noseTip.y + f.mouthCenter.y) / 2 + 0.02), max(0.5, f.mouthHalfWidth + 0.15), 0.48)
    }

    static let werewolf: [Layer] = [
        { p in
            let f = p.face
            p.without(f.eyeHoles()).without(FacePainter.muzzle(f)).fill(f.faceOval(), Paint.brown.color, opacity: 0.85, soft: 0.06)
        },
        { p in
            p.within(p.face.faceOval()).fill(FacePainter.muzzle(p.face), Paint.beige.color, opacity: 0.88, soft: 0.05)
        },
        { p in
            let f = p.face
            var fur: [Path] = []
            for i in 0..<34 {
                let a = CGFloat(i) / 34 * 2 * .pi
                let wobble = CGFloat(sin(Double(i) * 2.7)) * 0.04
                let rx = f.faceHalfWidth - 0.05, ryTop = -f.foreheadTop, ryBottom = f.chin
                let ry = sin(a) < 0 ? ryTop : ryBottom
                let start = pt(cos(a) * (rx - 0.18 + wobble), sin(a) * (ry - 0.2) + 0.1)
                let end = pt(cos(a) * (rx + 0.02), sin(a) * ry + 0.1)
                fur.append(line(start, end))
            }
            for s in [-1.0, 1.0] as [CGFloat] {
                for k in 0..<4 {
                    let x = s * (0.3 + CGFloat(k) * 0.13)
                    fur.append(line(pt(x, f.browY + 0.02), pt(x + s * 0.06, f.browY - 0.16)))
                }
            }
            p.within(f.faceOval(inset: -0.04)).without(f.eyeHoles()).stroke(fur, Paint.darkBrown.color, width: 0.025)
        },
        { p in
            let f = p.face
            let n = f.noseTip
            var nose = Path()
            nose.move(to: pt(n.x - 0.21, n.y - 0.1))
            nose.addQuadCurve(to: pt(n.x + 0.21, n.y - 0.1), control: pt(n.x, n.y - 0.24))
            nose.addQuadCurve(to: pt(n.x, n.y + 0.08), control: pt(n.x + 0.17, n.y + 0.06))
            nose.addQuadCurve(to: pt(n.x - 0.21, n.y - 0.1), control: pt(n.x - 0.17, n.y + 0.06))
            nose.closeSubpath()
            p.fill(nose, Paint.black.color, soft: 0.006)
            p.fill(ellipse(pt(n.x - 0.07, n.y - 0.12), 0.05, 0.02), .white, opacity: 0.55, soft: 0.006)
            p.stroke(line(pt(n.x, n.y + 0.06), pt(n.x, f.mouthTop)), Paint.black.color, width: 0.03)

            let m = f.mouthCenter
            let w = f.mouthHalfWidth + 0.13
            // Breite schwarze Lefzen, zum Knurren hochgezogen
            var lips = Path()
            lips.move(to: pt(m.x - w - 0.07, m.y - 0.07))
            lips.addQuadCurve(to: pt(m.x + w + 0.07, m.y - 0.07), control: pt(m.x, m.y - 0.22))
            lips.addQuadCurve(to: pt(m.x - w - 0.07, m.y - 0.07), control: pt(m.x, m.y + 0.42))
            lips.closeSubpath()
            p.fill(lips, Paint.black.color, opacity: 0.96, soft: 0.006)

            func tooth(_ x: CGFloat, _ base: CGFloat, half: CGFloat, length: CGFloat, down: Bool) -> Path {
                let d: CGFloat = down ? 1 : -1
                var t = Path()
                t.move(to: pt(x - half, base))
                t.addQuadCurve(to: pt(x, base + d * length), control: pt(x - half * 0.55, base + d * length * 0.6))
                t.addQuadCurve(to: pt(x + half, base), control: pt(x + half * 0.55, base + d * length * 0.6))
                t.closeSubpath()
                return t
            }
            var teeth: [Path] = []
            let upperCount = 9
            for i in 0..<upperCount {
                let t = (CGFloat(i) + 0.5) / CGFloat(upperCount)
                let edge = abs(t - 0.5) * 2
                let isFang = i == 1 || i == upperCount - 2
                let x = m.x - w + 2 * w * t
                let base = m.y - 0.09 + edge * edge * 0.05
                teeth.append(tooth(x, base, half: w / CGFloat(upperCount) * 0.95,
                                   length: isFang ? 0.32 : 0.09 + 0.03 * (1 - edge), down: true))
            }
            let lowerCount = 7
            for i in 0..<lowerCount {
                let t = (CGFloat(i) + 0.5) / CGFloat(lowerCount)
                let isFang = i == 0 || i == lowerCount - 1
                let x = m.x - w * 0.78 + 1.56 * w * t
                teeth.append(tooth(x, m.y + 0.17, half: w * 0.78 / CGFloat(lowerCount) * 0.95,
                                   length: isFang ? 0.2 : 0.08, down: false))
            }
            p.fill(teeth, Color(hex: 0xF4F0E2), opacity: 0.99, soft: 0.002)
            for t in teeth {
                p.within(t).stroke(t, Color(hex: 0xA8A08C), width: 0.035, opacity: 0.7, soft: 0.012)
            }
            p.stroke(teeth, Color(hex: 0x1A1410), width: 0.01)
        },
    ]

    // MARK: - 🌸 Zuckerschädel

    static let sugarSkull: [Layer] = [
        { p in
            let f = p.face
            p.without(f.eyeHoles()).fill(f.faceOval(), Paint.white.color, opacity: 0.94, soft: 0.04)
        },
        { p in
            let f = p.face
            var petals: [Path] = []
            var rings: [Path] = []
            for e in f.eyes {
                let c = pt(e.center.x, e.center.y - 0.02)
                rings.append(circle(c, 0.33))
                for i in 0..<9 {
                    let a = CGFloat(i) / 9 * 2 * .pi
                    petals.append(circle(pt(c.x + cos(a) * 0.38, c.y + sin(a) * 0.38), 0.09))
                }
            }
            let around = p.without(f.eyeHoles(padX: 0.02, padY: 0.03))
            around.fill(petals, Paint.pink.color, opacity: 0.95, soft: 0.004)
            around.fill(rings, Paint.turquoise.color, opacity: 0.95, soft: 0.004)
            around.stroke(rings, Paint.black.color, width: 0.02)
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
            let w = max(0.6, f.mouthHalfWidth + 0.25)
            func y(_ x: CGFloat) -> CGFloat { m.y - pow((x - m.x) / w, 2) * 0.1 }
            var main = Path()
            for i in 0...20 {
                let x = m.x - w + 2 * w * CGFloat(i) / 20
                if i == 0 { main.move(to: pt(x, y(x))) } else { main.addLine(to: pt(x, y(x))) }
            }
            var crosses: [Path] = []
            for i in 1..<8 {
                let x = m.x - w + 2 * w * CGFloat(i) / 8
                crosses.append(line(pt(x - 0.04, y(x) - 0.07), pt(x + 0.04, y(x) + 0.07)))
                crosses.append(line(pt(x + 0.04, y(x) - 0.07), pt(x - 0.04, y(x) + 0.07)))
            }
            p.stroke([main], Paint.black.color, width: 0.03)
            p.stroke(crosses, Paint.black.color, width: 0.022)
        },
        { p in
            let f = p.face
            let c = pt(0, f.browY - 0.5)
            let petals = (0..<5).map { i -> Path in
                let a = CGFloat(i) / 5 * 2 * .pi - .pi / 2
                return circle(pt(c.x + cos(a) * 0.12, c.y + sin(a) * 0.12), 0.08)
            }
            p.fill(petals, Paint.pink.color, opacity: 0.95, soft: 0.004)
            p.fill(circle(c, 0.07), Paint.yellow.color, opacity: 0.97, soft: 0.004)
            var swirls: [Path] = []
            for s in [-1.0, 1.0] as [CGFloat] {
                var swirl = Path()
                let sc = pt(s * f.faceHalfWidth * 0.68, 0.7)
                for i in 0...40 {
                    let a = s * CGFloat(i) / 40 * .pi * 3.5
                    let r = CGFloat(i) / 40 * 0.16
                    let q = pt(sc.x + cos(a) * r, sc.y + sin(a) * r)
                    if i == 0 { swirl.move(to: q) } else { swirl.addLine(to: q) }
                }
                swirls.append(swirl)
            }
            p.stroke(swirls, Paint.turquoise.color, width: 0.03)
            let dots = (0..<7).map { i -> Path in
                let a = CGFloat.pi * (0.2 + 0.6 * CGFloat(i) / 6)
                return circle(pt(cos(a) * 0.42, f.chin - 0.45 + sin(a) * 0.25), 0.03)
            }
            p.fill(dots, Paint.black.color, soft: 0.003)
        },
    ]
}
