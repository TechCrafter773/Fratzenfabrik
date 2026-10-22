import CoreGraphics
import SwiftUI

/// Rohe Gesichtspunkte aus Vision, normiert auf 0…1 im Kamerabild (Ursprung oben links).
struct FaceLandmarks {
    var boundingBox: CGRect
    var leftEye: [CGPoint]
    var rightEye: [CGPoint]
    var leftPupil: CGPoint?
    var rightPupil: CGPoint?
    var leftBrow: [CGPoint]
    var rightBrow: [CGPoint]
    var nose: [CGPoint]
    var outerLips: [CGPoint]
    var innerLips: [CGPoint]
    var contour: [CGPoint]

    /// Weiche Überblendung zum neuen Messwert – gegen Zittern.
    func blended(toward new: FaceLandmarks, amount t: CGFloat) -> FaceLandmarks {
        func mix(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
            CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
        }
        func mix(_ a: [CGPoint], _ b: [CGPoint]) -> [CGPoint] {
            a.count == b.count ? zip(a, b).map { mix($0, $1) } : b
        }
        func mix(_ a: CGPoint?, _ b: CGPoint?) -> CGPoint? {
            guard let a, let b else { return b }
            return mix(a, b)
        }
        return FaceLandmarks(
            boundingBox: CGRect(
                origin: mix(boundingBox.origin, new.boundingBox.origin),
                size: CGSize(
                    width: boundingBox.width + (new.boundingBox.width - boundingBox.width) * t,
                    height: boundingBox.height + (new.boundingBox.height - boundingBox.height) * t
                )
            ),
            leftEye: mix(leftEye, new.leftEye),
            rightEye: mix(rightEye, new.rightEye),
            leftPupil: mix(leftPupil, new.leftPupil),
            rightPupil: mix(rightPupil, new.rightPupil),
            leftBrow: mix(leftBrow, new.leftBrow),
            rightBrow: mix(rightBrow, new.rightBrow),
            nose: mix(nose, new.nose),
            outerLips: mix(outerLips, new.outerLips),
            innerLips: mix(innerLips, new.innerLips),
            contour: mix(contour, new.contour)
        )
    }
}

struct EyeShape {
    var center: CGPoint
    var halfWidth: CGFloat
    var halfHeight: CGFloat

    func ellipse(grow: CGFloat = 1, padX: CGFloat = 0.05, padY: CGFloat = 0.06) -> Path {
        let rx = halfWidth * grow + padX
        let ry = halfHeight * grow + padY
        return Path(ellipseIn: CGRect(x: center.x - rx, y: center.y - ry, width: rx * 2, height: ry * 2))
    }
}

/// Ein Gesicht im „Gesichtsraum“: Die Augenmitten liegen bei (-0,5|0) und (0,5|0),
/// y zeigt Richtung Kinn. `transform` bildet den Gesichtsraum auf den Bildschirm ab.
/// So können alle Schmink-Designs einmal gezeichnet und auf jedes Gesicht gelegt werden.
struct FaceGeometry {
    var transform: CGAffineTransform
    /// Bildschirmpunkte pro Gesichtseinheit (= Augenabstand).
    var scale: CGFloat
    var leftEye: EyeShape
    var rightEye: EyeShape
    var mouthOuter: [CGPoint]
    var mouthCenter: CGPoint
    var mouthHalfWidth: CGFloat
    var mouthTop: CGFloat
    var mouthBottom: CGFloat
    var noseTip: CGPoint
    var browY: CGFloat
    var foreheadTop: CGFloat
    var chin: CGFloat
    var faceHalfWidth: CGFloat
    var jawHalfWidth: CGFloat

    var eyes: [EyeShape] { [leftEye, rightEye] }

    // MARK: Pfade im Gesichtsraum

    /// Eiförmige Gesichtsfläche von Haaransatz bis Kinn.
    func faceOval(inset: CGFloat = 0) -> Path {
        let top = foreheadTop + inset
        let bottom = chin - inset
        let w = faceHalfWidth - inset
        let jw = jawHalfWidth - inset
        let side: CGFloat = 0.1
        var p = Path()
        p.move(to: CGPoint(x: w, y: side))
        p.addCurve(to: CGPoint(x: 0, y: top),
                   control1: CGPoint(x: w, y: top * 0.6),
                   control2: CGPoint(x: w * 0.6, y: top))
        p.addCurve(to: CGPoint(x: -w, y: side),
                   control1: CGPoint(x: -w * 0.6, y: top),
                   control2: CGPoint(x: -w, y: top * 0.6))
        p.addCurve(to: CGPoint(x: 0, y: bottom),
                   control1: CGPoint(x: -w, y: side + (bottom - side) * 0.55),
                   control2: CGPoint(x: -jw * 0.6, y: bottom))
        p.addCurve(to: CGPoint(x: w, y: side),
                   control1: CGPoint(x: jw * 0.6, y: bottom),
                   control2: CGPoint(x: w, y: side + (bottom - side) * 0.55))
        p.closeSubpath()
        return p
    }

    func eyeHoles(grow: CGFloat = 1, padX: CGFloat = 0.05, padY: CGFloat = 0.06) -> Path {
        var p = leftEye.ellipse(grow: grow, padX: padX, padY: padY)
        p.addPath(rightEye.ellipse(grow: grow, padX: padX, padY: padY))
        return p
    }

    func mouthPath(grow: CGFloat = 1) -> Path {
        var p = Path()
        guard mouthOuter.count > 2 else {
            return Path(ellipseIn: CGRect(x: mouthCenter.x - mouthHalfWidth, y: mouthTop,
                                          width: mouthHalfWidth * 2, height: mouthBottom - mouthTop))
        }
        let pts = mouthOuter.map {
            CGPoint(x: mouthCenter.x + ($0.x - mouthCenter.x) * grow,
                    y: mouthCenter.y + ($0.y - mouthCenter.y) * grow)
        }
        p.addLines(pts)
        p.closeSubpath()
        return p
    }

    // MARK: Aus echten Gesichtspunkten

    /// Baut die Geometrie aus Vision-Punkten. `map` rechnet normierte Bildpunkte in Zielpunkte um.
    static func from(_ lm: FaceLandmarks, map: (CGPoint) -> CGPoint) -> FaceGeometry? {
        let eyeA = lm.leftEye.map(map)
        let eyeB = lm.rightEye.map(map)
        guard eyeA.count >= 3, eyeB.count >= 3 else { return nil }

        let centerA = lm.leftPupil.map(map) ?? centroid(eyeA)
        let centerB = lm.rightPupil.map(map) ?? centroid(eyeB)
        // Das linke Auge auf dem Bildschirm ist immer das mit dem kleineren x.
        let (l, r, lPts, rPts) = centerA.x <= centerB.x
            ? (centerA, centerB, eyeA, eyeB)
            : (centerB, centerA, eyeB, eyeA)

        let dx = r.x - l.x, dy = r.y - l.y
        let s = hypot(dx, dy)
        guard s > 6 else { return nil }
        let vx = dx / s, vy = dy / s
        let mid = CGPoint(x: (l.x + r.x) / 2, y: (l.y + r.y) / 2)
        let t = CGAffineTransform(a: s * vx, b: s * vy, c: -s * vy, d: s * vx, tx: mid.x, ty: mid.y)
        let inv = t.inverted()
        func f(_ pts: [CGPoint]) -> [CGPoint] { pts.map(map).map { $0.applying(inv) } }

        var geo = FaceGeometry.canonical
        geo.transform = t
        geo.scale = s

        func eye(_ pts: [CGPoint]) -> EyeShape {
            let fp = pts.map { $0.applying(inv) }
            let b = bounds(fp)
            return EyeShape(
                center: CGPoint(x: b.midX, y: b.midY),
                halfWidth: clamp(b.width / 2, 0.12, 0.32),
                halfHeight: clamp(b.height / 2, 0.03, 0.18)
            )
        }
        geo.leftEye = eye(lPts)
        geo.rightEye = eye(rPts)

        let lips = f(lm.outerLips)
        if lips.count >= 4 {
            let b = bounds(lips)
            geo.mouthOuter = lips
            geo.mouthCenter = CGPoint(x: b.midX, y: clamp(b.midY, 0.7, 1.6))
            geo.mouthHalfWidth = clamp(b.width / 2, 0.2, 0.6)
            geo.mouthTop = b.minY
            geo.mouthBottom = b.maxY
        }

        let nose = f(lm.nose)
        if nose.count >= 3 {
            let b = bounds(nose)
            geo.noseTip = CGPoint(x: b.midX, y: clamp(b.maxY - 0.05, 0.4, 1.0))
        }

        let brows = f(lm.leftBrow + lm.rightBrow)
        if !brows.isEmpty {
            geo.browY = clamp(brows.map(\.y).reduce(0, +) / CGFloat(brows.count), -0.6, -0.15)
        }
        geo.foreheadTop = geo.browY - 1.0

        let contour = f(lm.contour)
        if contour.count >= 5 {
            let maxY = contour.map(\.y).max() ?? geo.chin
            geo.chin = clamp(maxY, geo.mouthBottom + 0.25, 2.4)
            let widest = contour.map { abs($0.x) }.max() ?? geo.faceHalfWidth
            geo.faceHalfWidth = clamp(widest, 0.85, 1.5)
            let jaw = contour.filter { $0.y > geo.mouthCenter.y - 0.1 }.map { abs($0.x) }.max()
            geo.jawHalfWidth = clamp(jaw ?? geo.faceHalfWidth * 0.8, 0.5, geo.faceHalfWidth)
        }
        return geo
    }

    // MARK: Zeichentrick-Kind für Vorschauen

    static let canonical: FaceGeometry = {
        var lips: [CGPoint] = []
        for i in 0...8 { // Oberlippe von links nach rechts
            let x = -0.36 + 0.72 * CGFloat(i) / 8
            lips.append(CGPoint(x: x, y: 1.0 - 0.06 * (1 - pow(x / 0.36, 2))))
        }
        for i in 1..<8 { // Unterlippe zurück
            let x = 0.36 - 0.72 * CGFloat(i) / 8
            lips.append(CGPoint(x: x, y: 1.0 + 0.17 * (1 - pow(x / 0.36, 2))))
        }
        return FaceGeometry(
            transform: .identity,
            scale: 1,
            leftEye: EyeShape(center: CGPoint(x: -0.5, y: 0), halfWidth: 0.2, halfHeight: 0.1),
            rightEye: EyeShape(center: CGPoint(x: 0.5, y: 0), halfWidth: 0.2, halfHeight: 0.1),
            mouthOuter: lips,
            mouthCenter: CGPoint(x: 0, y: 1.05),
            mouthHalfWidth: 0.36,
            mouthTop: 0.94,
            mouthBottom: 1.17,
            noseTip: CGPoint(x: 0, y: 0.62),
            browY: -0.36,
            foreheadTop: -1.36,
            chin: 1.78,
            faceHalfWidth: 1.12,
            jawHalfWidth: 0.92
        )
    }()

    /// Das Zeichentrick-Gesicht, eingepasst in ein Rechteck.
    static func cartoon(in rect: CGRect) -> FaceGeometry {
        var geo = canonical
        let s = min(rect.width / 3.0, rect.height / 4.1)
        geo.scale = s
        geo.transform = CGAffineTransform(a: s, b: 0, c: 0, d: s, tx: rect.midX, ty: rect.midY + 0.12 * s)
        return geo
    }
}

// MARK: - Helfer

func centroid(_ pts: [CGPoint]) -> CGPoint {
    guard !pts.isEmpty else { return .zero }
    let sum = pts.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
    return CGPoint(x: sum.x / CGFloat(pts.count), y: sum.y / CGFloat(pts.count))
}

func bounds(_ pts: [CGPoint]) -> CGRect {
    guard let first = pts.first else { return .zero }
    var minX = first.x, maxX = first.x, minY = first.y, maxY = first.y
    for p in pts {
        minX = min(minX, p.x); maxX = max(maxX, p.x)
        minY = min(minY, p.y); maxY = max(maxY, p.y)
    }
    return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
}

func clamp(_ v: CGFloat, _ lo: CGFloat, _ hi: CGFloat) -> CGFloat { min(max(v, lo), max(lo, hi)) }

/// Rechnet normierte Bildpunkte in Ansichtspunkte um – wie `resizeAspectFill` der Kameravorschau.
func aspectFillMapper(imageSize: CGSize, viewSize: CGSize) -> (CGPoint) -> CGPoint {
    guard imageSize.width > 0, imageSize.height > 0 else { return { $0 } }
    let scale = max(viewSize.width / imageSize.width, viewSize.height / imageSize.height)
    let w = imageSize.width * scale, h = imageSize.height * scale
    let ox = (viewSize.width - w) / 2, oy = (viewSize.height - h) / 2
    return { CGPoint(x: $0.x * w + ox, y: $0.y * h + oy) }
}
