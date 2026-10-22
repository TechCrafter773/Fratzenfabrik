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
