import AVFoundation
import SwiftUI

/// Die Live-Kameravorschau (füllt die ganze Fläche wie `resizeAspectFill`).
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    let configurationID: Int

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
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {
        view.applyPortrait()
    }
}
