import SwiftUI

/// Kleiner Pinsel-Helfer: Nimmt Pfade im Gesichtsraum entgegen und malt sie auf den Bildschirm.
struct Painter {
    var ctx: GraphicsContext
    let face: FaceGeometry
    var alpha: Double
    let time: Double

    /// Malt nicht in diesen Bereich (z. B. die Augen bleiben frei).
    func without(_ path: Path) -> Painter {
        var copy = self
        copy.ctx.clip(to: path.applying(face.transform), options: .inverse)
        return copy
    }

    /// Malt nur innerhalb dieses Bereichs (z. B. nur auf dem Gesicht).
    func within(_ path: Path) -> Painter {
        var copy = self
        copy.ctx.clip(to: path.applying(face.transform))
        return copy
    }

    /// Füllt mehrere Formen als eine Farbfläche – mit weichem Schminkrand.
    func fill(_ paths: [Path], _ color: Color, opacity: Double = 0.93, soft: CGFloat = 0.012) {
        guard alpha > 0 else { return }
        var c = ctx
        c.opacity = alpha * opacity
        if soft > 0 { c.addFilter(.blur(radius: soft * face.scale)) }
        let t = face.transform
        c.drawLayer { layer in
            for p in paths { layer.fill(p.applying(t), with: .color(color)) }
        }
    }

    func fill(_ path: Path, _ color: Color, opacity: Double = 0.93, soft: CGFloat = 0.012) {
        fill([path], color, opacity: opacity, soft: soft)
    }

    /// Pinselstriche mit runden Enden. `width` ist in Gesichtseinheiten.
    func stroke(_ paths: [Path], _ color: Color, width: CGFloat, opacity: Double = 0.95, soft: CGFloat = 0.006) {
        guard alpha > 0 else { return }
        var c = ctx
        c.opacity = alpha * opacity
        if soft > 0 { c.addFilter(.blur(radius: soft * face.scale)) }
        let t = face.transform
        let style = StrokeStyle(lineWidth: width * face.scale, lineCap: .round, lineJoin: .round)
        c.drawLayer { layer in
            for p in paths { layer.stroke(p.applying(t), with: .color(color), style: style) }
        }
    }

    func stroke(_ path: Path, _ color: Color, width: CGFloat, opacity: Double = 0.95, soft: CGFloat = 0.006) {
        stroke([path], color, width: width, opacity: opacity, soft: soft)
    }
}

// MARK: - Form-Helfer im Gesichtsraum

func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

func ellipse(_ c: CGPoint, _ rx: CGFloat, _ ry: CGFloat) -> Path {
    Path(ellipseIn: CGRect(x: c.x - rx, y: c.y - ry, width: rx * 2, height: ry * 2))
}

func circle(_ c: CGPoint, _ r: CGFloat) -> Path { ellipse(c, r, r) }

func polygon(_ pts: [CGPoint]) -> Path {
    var p = Path()
    p.addLines(pts)
    p.closeSubpath()
    return p
}

func line(_ a: CGPoint, _ b: CGPoint) -> Path {
    var p = Path()
    p.move(to: a)
    p.addLine(to: b)
    return p
}

func curve(_ a: CGPoint, _ control: CGPoint, _ b: CGPoint) -> Path {
    var p = Path()
    p.move(to: a)
    p.addQuadCurve(to: b, control: control)
    return p
}

func star(_ c: CGPoint, _ r: CGFloat, points: Int = 5, rotation: CGFloat = 0) -> Path {
    var pts: [CGPoint] = []
    for i in 0..<(points * 2) {
        let rr = i % 2 == 0 ? r : r * 0.45
        let a = rotation - .pi / 2 + CGFloat(i) * .pi / CGFloat(points)
        pts.append(pt(c.x + cos(a) * rr, c.y + sin(a) * rr))
    }
    return polygon(pts)
}

/// Spiegelt einen Pfad an der Gesichtsmitte.
func mirrored(_ p: Path, aroundX x: CGFloat = 0) -> Path {
    p.applying(CGAffineTransform(translationX: x, y: 0).scaledBy(x: -1, y: 1).translatedBy(x: -x, y: 0))
}

/// Kleines Gespenst: runder Kopf, wellige Unterkante.
func miniGhost(_ c: CGPoint, _ r: CGFloat) -> Path {
    var p = Path()
    p.move(to: pt(c.x - r, c.y))
    p.addQuadCurve(to: pt(c.x, c.y - r), control: pt(c.x - r, c.y - r))
    p.addQuadCurve(to: pt(c.x + r, c.y), control: pt(c.x + r, c.y - r))
    p.addLine(to: pt(c.x + r, c.y + 1.1 * r))
    p.addQuadCurve(to: pt(c.x + r / 3, c.y + 1.1 * r), control: pt(c.x + 2 * r / 3, c.y + 1.5 * r))
    p.addQuadCurve(to: pt(c.x - r / 3, c.y + 1.1 * r), control: pt(c.x, c.y + 0.8 * r))
    p.addQuadCurve(to: pt(c.x - r, c.y + 1.1 * r), control: pt(c.x - 2 * r / 3, c.y + 1.5 * r))
    p.closeSubpath()
    return p
}

/// Kleine Fledermaus mit Flügeln und Öhrchen. `flap` lässt die Flügel schlagen.
func batGlyph(_ c: CGPoint, _ size: CGFloat, _ angle: CGFloat, flap: CGFloat = 0) -> [Path] {
    var wing = Path()
    wing.move(to: pt(0, -0.2))
    wing.addQuadCurve(to: pt(1.0, -0.45 - flap), control: pt(0.5, -0.68 - flap))
    wing.addQuadCurve(to: pt(0.7, -0.04), control: pt(0.96, -0.15))
    wing.addQuadCurve(to: pt(0.42, 0.05), control: pt(0.56, -0.12))
    wing.addQuadCurve(to: pt(0.12, 0.2), control: pt(0.24, -0.02))
    wing.addLine(to: pt(0, 0.25))
    wing.closeSubpath()
    let ear = polygon([pt(0.02, -0.2), pt(0.12, -0.42), pt(0.14, -0.16)])
    let shapes = [wing, mirrored(wing), ear, mirrored(ear), ellipse(pt(0, 0), 0.14, 0.26)]
    let t = CGAffineTransform(translationX: c.x, y: c.y).rotated(by: angle).scaledBy(x: size, y: size)
    return shapes.map { $0.applying(t) }
}

/// Eine züngelnde Flamme, die von `base` nach oben brennt.
func flame(_ base: CGPoint, _ h: CGFloat, _ w: CGFloat) -> Path {
    var p = Path()
    p.move(to: pt(base.x - w, base.y))
    p.addQuadCurve(to: pt(base.x - w * 0.2, base.y - h * 0.55), control: pt(base.x - w * 1.1, base.y - h * 0.35))
    p.addQuadCurve(to: pt(base.x + w * 0.15, base.y - h), control: pt(base.x - w * 0.35, base.y - h * 0.8))
    p.addQuadCurve(to: pt(base.x + w * 0.35, base.y - h * 0.45), control: pt(base.x + w * 0.55, base.y - h * 0.7))
    p.addQuadCurve(to: pt(base.x + w, base.y), control: pt(base.x + w * 1.1, base.y - h * 0.25))
    p.addQuadCurve(to: pt(base.x - w, base.y), control: pt(base.x, base.y + w * 0.6))
    p.closeSubpath()
    return p
}

/// Blut- oder Farbspur: oben schmal, unten breiter, am Ende ein Tropfen.
func bloodStreak(_ a: CGPoint, _ b: CGPoint, width w: CGFloat, drop: Bool = true) -> Path {
    let dx = b.x - a.x, dy = b.y - a.y
    let len = max(hypot(dx, dy), 0.001)
    let ux = dx / len, uy = dy / len
    let nx = -uy, ny = ux
    let mid = pt((a.x + b.x) / 2, (a.y + b.y) / 2)
    var p = Path()
    p.move(to: pt(a.x + nx * w * 0.2, a.y + ny * w * 0.2))
    p.addQuadCurve(to: pt(b.x + nx * w * 0.5, b.y + ny * w * 0.5), control: pt(mid.x + nx * w * 0.55, mid.y + ny * w * 0.55))
    p.addQuadCurve(to: pt(b.x - nx * w * 0.5, b.y - ny * w * 0.5), control: pt(b.x + ux * w * 0.9, b.y + uy * w * 0.9))
    p.addQuadCurve(to: pt(a.x - nx * w * 0.2, a.y - ny * w * 0.2), control: pt(mid.x - nx * w * 0.45, mid.y - ny * w * 0.45))
    p.closeSubpath()
    if drop { p.addPath(circle(pt(b.x + ux * w * 0.55, b.y + uy * w * 0.55), w * 0.62)) }
    return p
}

/// Kleine Farbspritzer rund um einen Punkt (reproduzierbar).
func spatter(around c: CGPoint, radius: CGFloat, count: Int, seed: Int) -> [Path] {
    (0..<count).map { i in
        let a = CGFloat(i * 137 + seed * 31).truncatingRemainder(dividingBy: 360) * .pi / 180
        let d = radius * (0.4 + 0.6 * CGFloat((i * 53 + seed * 17) % 100) / 100)
        let r = 0.008 + 0.012 * CGFloat((i * 29 + seed) % 10) / 10
        return circle(pt(c.x + cos(a) * d, c.y + sin(a) * d), r)
    }
}
