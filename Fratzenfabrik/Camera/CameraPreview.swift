import AVFoundation
import ImageIO
import SwiftUI

/// Die Live-Kameravorschau (füllt die ganze Fläche wie `resizeAspectFill`).
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    let configurationID: Int
    let bridge: PreviewBridge

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }

        func applyPortrait() {
            if let connection = previewLayer.connection, connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            applyPortrait()
        }
    }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.backgroundColor = .black
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        bridge.layer = view.previewLayer
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {
        view.applyPortrait()
    }
}

/// Fragt die Vorschau, wie sie das rohe Sensorbild auf den Bildschirm bringt (Drehung, Spiegelung,
/// Zuschnitt). Damit muss nichts geraten werden – Vorder- und Rückkamera passen automatisch.
@MainActor
final class PreviewBridge {
    weak var layer: AVCaptureVideoPreviewLayer?

    private var readyLayer: AVCaptureVideoPreviewLayer? {
        guard let layer, layer.bounds.width > 0, layer.connection != nil else { return nil }
        return layer
    }

    /// Die EXIF-Ausrichtung, die dem entspricht, was die Vorschau gerade zeigt.
    func displayedOrientation() -> CGImagePropertyOrientation? {
        guard let layer = readyLayer else { return nil }
        let o = layer.layerPointConverted(fromCaptureDevicePoint: CGPoint(x: 0, y: 0))
        let px = layer.layerPointConverted(fromCaptureDevicePoint: CGPoint(x: 1, y: 0))
        let py = layer.layerPointConverted(fromCaptureDevicePoint: CGPoint(x: 0, y: 1))
        let ex = CGPoint(x: px.x - o.x, y: px.y - o.y) // wohin zeigt die x-Achse des Sensors?
        let ey = CGPoint(x: py.x - o.x, y: py.y - o.y) // wohin zeigt die y-Achse des Sensors?
        if abs(ex.x) >= abs(ex.y) {
            switch (ex.x > 0, ey.y > 0) {
            case (true, true): return .up
            case (false, true): return .upMirrored
            case (false, false): return .down
            case (true, false): return .downMirrored
            }
        } else {
            switch (ex.y > 0, ey.x > 0) {
            case (true, false): return .right
            case (true, true): return .leftMirrored
            case (false, true): return .left
            case (false, false): return .rightMirrored
            }
        }
    }

    /// Bildet normierte Punkte des ausgerichteten Bildes auf Bildschirmpunkte der Vorschau ab.
    func mapper(for orientation: CGImagePropertyOrientation) -> ((CGPoint) -> CGPoint)? {
        guard let layer = readyLayer else { return nil }
        return { point in
            layer.layerPointConverted(fromCaptureDevicePoint: orientation.rawPoint(fromOriented: point))
        }
    }
}
