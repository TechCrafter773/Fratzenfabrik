import AVFoundation
import SwiftUI

@MainActor
final class CameraModel: ObservableObject {
    enum Access { case unknown, granted, denied, noCamera }

    @Published private(set) var faces: [FaceLandmarks] = []
    @Published private(set) var imageSize = CGSize(width: 720, height: 1280)
    @Published private(set) var position: AVCaptureDevice.Position = .back
    @Published private(set) var access: Access = .unknown
    /// Wird nach jeder Kamera-Umstellung erhöht, damit die Vorschau ihre Ausrichtung neu setzt.
    @Published private(set) var configurationID = 0

    let tracker = FaceTracker()
    private var missedFrames = 0
    private var pendingSnapshot: (@MainActor (CGImage, [FaceLandmarks]) -> Void)?

    init() {
        tracker.onFrame = { [weak self] result in
            Task { @MainActor in self?.handle(result) }
        }
        tracker.onConfigured = { [weak self] position, ok in
            Task { @MainActor in
                guard let self else { return }
                self.position = position
                self.configurationID += 1
                if !ok { self.access = .noCamera }
            }
        }
    }

    func start() async {
        guard FaceTracker.hasCamera else {
            access = .noCamera
            return
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            access = .granted
        case .notDetermined:
            access = await AVCaptureDevice.requestAccess(for: .video) ? .granted : .denied
        default:
            access = .denied
        }
        guard access == .granted else { return }
        tracker.configure(position: position)
        tracker.start()
    }

    func stop() {
        tracker.stop()
    }

    func flipCamera() {
        faces = []
        tracker.configure(position: position == .back ? .front : .back)
    }

    func capture(_ completion: @escaping @MainActor (CGImage, [FaceLandmarks]) -> Void) {
        pendingSnapshot = completion
        tracker.requestSnapshot()
    }

    private func handle(_ result: FrameResult) {
        imageSize = result.imageSize

        if let snapshot = result.snapshot, let completion = pendingSnapshot {
            pendingSnapshot = nil
            completion(snapshot, result.faces)
        }

        if result.faces.isEmpty {
            // Ein paar Bilder lang festhalten, damit die Schminke nicht flackert.
            missedFrames += 1
            if missedFrames > 8 { faces = [] }
            return
        }
        missedFrames = 0

        // Jedes neue Gesicht mit dem nächstgelegenen alten verbinden und weich nachziehen.
        var previous = faces
        faces = result.faces.map { new in
            let center = CGPoint(x: new.boundingBox.midX, y: new.boundingBox.midY)
            guard let index = previous.indices.min(by: {
                distance(previous[$0].boundingBox, center) < distance(previous[$1].boundingBox, center)
            }), distance(previous[index].boundingBox, center) < new.boundingBox.width * 0.8 else {
                return new
            }
            let old = previous.remove(at: index)
            return old.blended(toward: new, amount: 0.55)
        }
    }

    private func distance(_ box: CGRect, _ point: CGPoint) -> CGFloat {
        hypot(box.midX - point.x, box.midY - point.y)
    }
}
