import AVFoundation
import CoreImage
import Vision

struct FrameResult {
    var faces: [FaceLandmarks]
    var imageSize: CGSize
    var snapshot: CGImage?
}

/// Kümmert sich um Kamera-Session und Gesichtserkennung – alles abseits des Main Threads.
final class FaceTracker: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    let session = AVCaptureSession()
    var onFrame: ((FrameResult) -> Void)?
    var onConfigured: ((AVCaptureDevice.Position, Bool) -> Void)?

    private let sessionQueue = DispatchQueue(label: "fratzenfabrik.session")
    private let videoQueue = DispatchQueue(label: "fratzenfabrik.video", qos: .userInteractive)
    private let output = AVCaptureVideoDataOutput()
    private var input: AVCaptureDeviceInput?
    private let request = VNDetectFaceLandmarksRequest()
    private let ciContext = CIContext()
    private let lock = NSLock()
    private var snapshotRequested = false
    private var isFront = false

    static var hasCamera: Bool {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil
            || AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) != nil
    }

    func configure(position: AVCaptureDevice.Position) {
        sessionQueue.async { [self] in
            session.beginConfiguration()
            if session.canSetSessionPreset(.hd1280x720) {
                session.sessionPreset = .hd1280x720
            } else {
                session.sessionPreset = .high
            }

            if let input { session.removeInput(input) }
            var ok = false
            if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)
                ?? AVCaptureDevice.default(for: .video),
               let newInput = try? AVCaptureDeviceInput(device: device),
               session.canAddInput(newInput) {
                session.addInput(newInput)
                input = newInput
                ok = true
            }

            if !session.outputs.contains(output), session.canAddOutput(output) {
                output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
                output.alwaysDiscardsLateVideoFrames = true
                output.setSampleBufferDelegate(self, queue: videoQueue)
                session.addOutput(output)
            }

            let actualPosition = input?.device.position ?? position
            if let connection = output.connection(with: .video) {
                // Bilder bleiben im Sensor-Querformat; die Ausrichtung bekommt Vision mitgeteilt.
                if connection.isVideoRotationAngleSupported(0) {
                    connection.videoRotationAngle = 0
                }
                if connection.isVideoMirroringSupported {
                    connection.automaticallyAdjustsVideoMirroring = false
                    connection.isVideoMirrored = false
                }
            }
            lock.lock()
            isFront = actualPosition == .front
            lock.unlock()
            session.commitConfiguration()
            onConfigured?(actualPosition, ok)
        }
    }

    func start() {
        sessionQueue.async { [self] in
            if !session.isRunning { session.startRunning() }
        }
    }

    func stop() {
        sessionQueue.async { [self] in
            if session.isRunning { session.stopRunning() }
        }
    }

    func requestSnapshot() {
        lock.lock()
        snapshotRequested = true
        lock.unlock()
    }

    // MARK: AVCaptureVideoDataOutputSampleBufferDelegate

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        lock.lock()
        let front = isFront
        let wantsSnapshot = snapshotRequested
        snapshotRequested = false
        lock.unlock()

        // Querformat-Puffer für das Hochkant-Display drehen; die Selfie-Kamera zusätzlich spiegeln,
        // damit die Punkte genau zur (gespiegelten) Vorschau passen.
        let landscape = width > height
        let orientation: CGImagePropertyOrientation = landscape ? (front ? .leftMirrored : .right) : .up
        let size = landscape ? CGSize(width: height, height: width) : CGSize(width: width, height: height)

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
        try? handler.perform([request])
        let observations = (request.results ?? [])
            .sorted { $0.boundingBox.width * $0.boundingBox.height > $1.boundingBox.width * $1.boundingBox.height }
            .prefix(4)
        let faces = observations.compactMap(FaceLandmarks.init(observation:))

        var snapshot: CGImage?
        if wantsSnapshot {
            let image = CIImage(cvPixelBuffer: pixelBuffer).oriented(orientation)
            snapshot = ciContext.createCGImage(image, from: image.extent)
        }
        onFrame?(FrameResult(faces: faces, imageSize: size, snapshot: snapshot))
    }
}

extension FaceLandmarks {
    /// Vision liefert Punkte mit Ursprung unten links – hier wird auf oben links gedreht.
    init?(observation: VNFaceObservation) {
        guard let lm = observation.landmarks else { return nil }
        func pts(_ region: VNFaceLandmarkRegion2D?) -> [CGPoint] {
            guard let region else { return [] }
            return region.pointsInImage(imageSize: CGSize(width: 1, height: 1)).map { CGPoint(x: $0.x, y: 1 - $0.y) }
        }
        let leftEye = pts(lm.leftEye)
        let rightEye = pts(lm.rightEye)
        guard leftEye.count >= 3, rightEye.count >= 3 else { return nil }
        let box = observation.boundingBox
        self.init(
            boundingBox: CGRect(x: box.minX, y: 1 - box.maxY, width: box.width, height: box.height),
            leftEye: leftEye,
            rightEye: rightEye,
            leftPupil: pts(lm.leftPupil).first,
            rightPupil: pts(lm.rightPupil).first,
            leftBrow: pts(lm.leftEyebrow),
            rightBrow: pts(lm.rightEyebrow),
            nose: pts(lm.nose),
            outerLips: pts(lm.outerLips),
            innerLips: pts(lm.innerLips),
            contour: pts(lm.faceContour)
        )
    }
}
