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
    static func face(in size: CGSize) -> FaceGeometry {
        var face = FaceGeometry.canonical
        // Etwas schmaler als der Kopf, damit die Schminke vorne auf den Wangen ausläuft
        // statt hart an der Kopfseite zu enden. Kleine Augenaussparung: dort sitzen die Augäpfel.
        face.faceHalfWidth = 0.98
        face.jawHalfWidth = 0.8
        for eye in [\FaceGeometry.leftEye, \FaceGeometry.rightEye] {
            face[keyPath: eye].halfWidth = 0.13
            face[keyPath: eye].halfHeight = 0.07
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

    static func draw(_ f: FaceGeometry, kid: Kid, in ctx: GraphicsContext, size: CGSize) {
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
        p.stroke([curve(pt(-0.74, f.browY + 0.03), pt(-0.5, f.browY - 0.07), pt(-0.27, f.browY + 0.02)),
                  curve(pt(0.27, f.browY + 0.02), pt(0.5, f.browY - 0.07), pt(0.74, f.browY + 0.03))],
                 browColor, width: kid == .girl ? 0.045 : 0.06, opacity: 0.9, soft: 0.01)
        // Lippen
        p.fill(f.mouthPath(), kid == .girl ? Color(hex: 0xE07A8A) : Color(hex: 0xC97A78), opacity: 0.95, soft: 0.01)
        p.stroke(line(pt(-0.3, f.mouthCenter.y - 0.02), pt(0.3, f.mouthCenter.y - 0.02)), Color(hex: 0x8E4A4E), width: 0.015, opacity: 0.6)
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

    static func image(design: DesignID?, visibleSteps: Int? = nil, kid: Kid?, size: CGSize = TextureSpace.pixelSize) -> UIImage? {
        let key = "\(design?.rawValue ?? "-")|\(visibleSteps ?? -1)|\(kid?.rawValue ?? "-")|\(Int(size.width))"
        if let cached = cache[key] { return cached }

        let content = Canvas { ctx, canvasSize in
            let face = TextureSpace.face(in: canvasSize)
            if let kid { SkinPainter.draw(face, kid: kid, in: ctx, size: canvasSize) }
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
