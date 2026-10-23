import SwiftUI
import UIKit

/// Der Ausschnitt des Gesichtsraums, der als Textur gerendert wird – für 3D-Köpfe und ARKit.
enum TextureSpace {
    static let minX: CGFloat = -1.7
    static let minY: CGFloat = -2.1
    static let width: CGFloat = 3.4
    static let height: CGFloat = 4.4
    static let pixelSize = CGSize(width: 1024, height: 1325)

    /// Gesichtsraum → Texturkoordinate (0…1, Ursprung oben links).
    static func uv(x: CGFloat, y: CGFloat) -> CGPoint {
        CGPoint(x: (x - minX) / width, y: (y - minY) / height)
    }

    /// Das Standardgesicht, abgebildet auf ein Bild dieser Größe.
    /// `live`: für das echte Gesicht (ARKit) – die Schminke reicht bis an den Rand des Gesichtsnetzes.
    static func face(in size: CGSize, mood: FaceMood = .neutral, live: Bool = false) -> FaceGeometry {
        var face = FaceGeometry.canonical
        // Mundwinkel nach oben (Lächeln) oder unten (Grummeln)
        let bend: CGFloat = mood == .smile ? -0.1 : (mood == .grumpy ? 0.08 : 0)
        face.mouthOuter = face.mouthOuter.map { q in
            let t = q.x / face.mouthHalfWidth
            return CGPoint(x: q.x * (mood == .smile ? 1.08 : 1), y: q.y + bend * t * t)
        }
        // Etwas schmaler als der Kopf, damit die Schminke vorne auf den Wangen ausläuft
        // statt hart an der Kopfseite zu enden. Kleine Augenaussparung: dort sitzen die Augäpfel.
        if live {
            // Großzügig über das ganze Gesicht: Was über den Rand des ARKit-Netzes hinausragt, wird ohnehin nicht gezeigt.
            face.faceHalfWidth = 1.38
            face.jawHalfWidth = 1.12
            face.foreheadTop = -1.8
            face.chin = 2.2
        } else {
            face.faceHalfWidth = 0.98
            face.jawHalfWidth = 0.8
            for eye in [\FaceGeometry.leftEye, \FaceGeometry.rightEye] {
                face[keyPath: eye].halfWidth = 0.13
                face[keyPath: eye].halfHeight = 0.07
            }
        }
        let s = size.width / width
        face.scale = s
        face.transform = CGAffineTransform(a: s, b: 0, c: 0, d: s, tx: -minX * s, ty: -minY * s)
        return face
    }
}

/// Malt Haut, Bäckchen, Brauen und Lippen des 3D-Kindes (die Augen sind echte 3D-Kugeln).
enum SkinPainter {
    static let skin = Color(hex: 0xF2C29E)
    static let skinUI = UIColor(hex: 0xF2C29E)

    static func draw(_ f: FaceGeometry, kid: Kid, mood: FaceMood, in ctx: GraphicsContext, size: CGSize) {
        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(skin))
        let p = Painter(ctx: ctx, face: f, alpha: 1, time: 0)
        // Leichte Rötung an Wangen, Nase und Kinn – wirkt lebendiger
        p.fill([circle(pt(-0.66, 0.6), 0.24), circle(pt(0.66, 0.6), 0.24)], Color(hex: 0xF29C8E), opacity: 0.45, soft: 0.12)
        p.fill(ellipse(f.noseTip, 0.12, 0.1), Color(hex: 0xEFA48E), opacity: 0.35, soft: 0.06)
        p.fill(ellipse(pt(0, 1.6), 0.25, 0.14), Color(hex: 0xEFA48E), opacity: 0.25, soft: 0.08)
        // Lidschatten-Hauch um die Augen
        p.fill(f.eyes.map { ellipse($0.center, 0.3, 0.2) }, Color(hex: 0xC98F7A), opacity: 0.3, soft: 0.06)
        // Augenbrauen
        let browColor = Color(hex: 0x5A3A22)
        // Brauen: beim Lächeln hochgezogen, beim Grummeln zur Nase hin abgesenkt
        let lift: CGFloat = mood == .smile ? -0.05 : 0
        let inner: CGFloat = mood == .grumpy ? 0.1 : 0
        p.stroke([curve(pt(-0.74, f.browY + 0.03 + lift), pt(-0.5, f.browY - 0.07 + lift), pt(-0.27, f.browY + 0.02 + inner)),
                  curve(pt(0.27, f.browY + 0.02 + inner), pt(0.5, f.browY - 0.07 + lift), pt(0.74, f.browY + 0.03 + lift))],
                 browColor, width: kid == .girl ? 0.045 : 0.06, opacity: 0.9, soft: 0.01)
        // Lippen
        p.fill(f.mouthPath(), kid == .girl ? Color(hex: 0xE07A8A) : Color(hex: 0xC97A78), opacity: 0.95, soft: 0.01)
        let bend: CGFloat = mood == .smile ? -0.12 : (mood == .grumpy ? 0.09 : 0)
        p.stroke(curve(pt(-0.32, f.mouthCenter.y - 0.02 + bend), pt(0, f.mouthCenter.y - 0.02 - bend), pt(0.32, f.mouthCenter.y - 0.02 + bend)),
                 Color(hex: 0x8E4A4E), width: 0.015, opacity: 0.6)
        if mood == .smile {
            p.fill([circle(pt(-0.62, 0.55), 0.17), circle(pt(0.62, 0.55), 0.17)], Color(hex: 0xF28C8C), opacity: 0.35, soft: 0.08)
        }
        // Sommersprossen für die Jungs
        if kid == .boy {
            let dots = [(-0.3, 0.42), (-0.4, 0.5), (-0.22, 0.52), (-0.5, 0.4), (0.3, 0.42), (0.4, 0.5), (0.22, 0.52), (0.5, 0.4)]
                .map { circle(pt(CGFloat($0.0), CGFloat($0.1)), 0.018) }
            p.fill(dots, Color(hex: 0xB0714F), opacity: 0.55, soft: 0.004)
        }
    }
}

/// Rendert Designs als Bild im Texturraum – mit Haut (3D-Kind) oder transparent (ARKit).
@MainActor
enum DesignTexture {
    private static var cache: [String: UIImage] = [:]

    static func image(design: DesignID?, visibleSteps: Int? = nil, kid: Kid?, mood: FaceMood = .neutral, live: Bool = false,
                      size: CGSize = TextureSpace.pixelSize) -> UIImage? {
        let key = "\(design?.rawValue ?? "-")|\(visibleSteps ?? -1)|\(kid?.rawValue ?? "-")|\(mood.rawValue)|\(live)|\(Int(size.width))"
        if let cached = cache[key] { return cached }

        let content = Canvas { ctx, canvasSize in
            let face = TextureSpace.face(in: canvasSize, mood: mood, live: live)
            if let kid { SkinPainter.draw(face, kid: kid, mood: mood, in: ctx, size: canvasSize) }
            if let design { FacePainter.draw(design, face: face, in: ctx, visibleSteps: visibleSteps) }
        }
        .frame(width: size.width, height: size.height)

        let renderer = ImageRenderer(content: content)
        renderer.scale = 1
        renderer.isOpaque = kid != nil
        guard let image = renderer.uiImage else { return nil }
        if cache.count > 60 { cache.removeAll() }
        cache[key] = image
        return image
    }
}
