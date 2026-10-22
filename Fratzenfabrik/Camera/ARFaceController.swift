import ARKit
import SceneKit
import SwiftUI

/// Live-3D-Schminke mit der TrueDepth-Kamera: Das Gesichtsnetz von ARKit wird mit dem Design bemalt,
/// klebt also wirklich auf dem Gesicht – auch wenn das Kind den Kopf dreht.
@MainActor
final class ARFaceController: NSObject, ObservableObject, ARSessionDelegate {
    static var isSupported: Bool { ARFaceTrackingConfiguration.isSupported }

    let sceneView = ARSCNView(frame: .zero)
    @Published private(set) var faceVisible = false
    @Published private(set) var mouthPoint: CGPoint?
    @Published private(set) var mouthOpen = false
    @Published private(set) var failed = false

    private let paint = SCNMaterial()
    private let faceRenderer = ARFaceRenderer()

    override init() {
        super.init()
        sceneView.automaticallyUpdatesLighting = true
        sceneView.autoenablesDefaultLighting = false
        sceneView.antialiasingMode = .multisampling4X
        sceneView.delegate = faceRenderer
        sceneView.session.delegate = self

        paint.lightingModel = .physicallyBased
        paint.roughness.contents = 0.85
        paint.metalness.contents = 0.0
        paint.blendMode = .alpha
        paint.transparencyMode = .aOne
        paint.writesToDepthBuffer = true
        faceRenderer.material = paint
        faceRenderer.onUpdate = { [weak self] visible, mouth, open in
            Task { @MainActor in self?.apply(visible: visible, mouth: mouth, open: open) }
        }
    }

    func run() {
        guard Self.isSupported else { failed = true; return }
        let config = ARFaceTrackingConfiguration()
        config.maximumNumberOfTrackedFaces = ARFaceTrackingConfiguration.supportedNumberOfTrackedFaces
        config.isLightEstimationEnabled = true
        sceneView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
    }

    func pause() {
        sceneView.session.pause()
        faceVisible = false
        mouthPoint = nil
        mouthOpen = false
    }

    func setPaint(_ image: UIImage?, opacity: Double) {
        paint.diffuse.contents = image
        paint.transparency = CGFloat(opacity)
    }

    func snapshot() -> UIImage { sceneView.snapshot() }

    private func apply(visible: Bool, mouth: CGPoint?, open: Bool) {
        if faceVisible != visible { faceVisible = visible }
        if mouthOpen != open { mouthOpen = open }
        if let mouth, let old = mouthPoint, hypot(mouth.x - old.x, mouth.y - old.y) < 2 { return }
        mouthPoint = mouth
    }

    nonisolated func session(_ session: ARSession, didFailWithError error: Error) {
        Task { @MainActor in self.failed = true }
    }
}

/// Läuft auf dem SceneKit-Render-Thread: baut je Bild das bemalte Gesichtsnetz.
final class ARFaceRenderer: NSObject, ARSCNViewDelegate, @unchecked Sendable {
    var material: SCNMaterial?
    var onUpdate: ((Bool, CGPoint?, Bool) -> Void)?

    private var uvCache: [UUID: [CGPoint]] = [:]
    private var element: SCNGeometryElement?

    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        anchor is ARFaceAnchor ? SCNNode() : nil
    }

    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let face = anchor as? ARFaceAnchor else { return }
        let geometry = face.geometry
        let vertices = geometry.vertices

        let left = face.leftEyeTransform.columns.3
        let right = face.rightEyeTransform.columns.3
        let mid = SIMD3<Float>((left.x + right.x) / 2, (left.y + right.y) / 2, (left.z + right.z) / 2)
        let eyeDistance = max(simd_distance(SIMD3(left.x, left.y, left.z), SIMD3(right.x, right.y, right.z)), 0.03)

        // Texturkoordinaten: jedes Netz-Vertex bekommt seinen Platz im Gesichtsraum (einmal je Gesicht)
        let uvs: [CGPoint]
        if let cached = uvCache[face.identifier], cached.count == vertices.count {
            uvs = cached
        } else {
            uvs = vertices.map { v in
                TextureSpace.uv(x: CGFloat((v.x - mid.x) / eyeDistance), y: CGFloat(-(v.y - mid.y) / eyeDistance))
            }
            uvCache[face.identifier] = uvs
        }

        if element == nil {
            element = SCNGeometryElement(indices: geometry.triangleIndices, primitiveType: .triangles)
        }
        let normals = Self.normals(vertices: vertices, indices: geometry.triangleIndices)
        let sources = [
            SCNGeometrySource(vertices: vertices.map { SCNVector3($0.x, $0.y, $0.z) }),
            SCNGeometrySource(normals: normals.map { SCNVector3($0.x, $0.y, $0.z) }),
            SCNGeometrySource(textureCoordinates: uvs),
        ]
        let mesh = SCNGeometry(sources: sources, elements: [element!])
        if let material { mesh.materials = [material] }
        node.geometry = mesh

        // Mund: liegt ca. 1,05 Augenabstände unter der Augenmitte
        let mouthLocal = SCNVector3(mid.x, mid.y - 1.05 * eyeDistance, mid.z + 0.012)
        let projected = renderer.projectPoint(node.convertPosition(mouthLocal, to: nil))
        let jaw = face.blendShapes[.jawOpen]?.floatValue ?? 0
        onUpdate?(face.isTracked, CGPoint(x: CGFloat(projected.x), y: CGFloat(projected.y)), jaw > 0.32)
    }

    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
        uvCache[anchor.identifier] = nil
        onUpdate?(false, nil, false)
    }

    private static func normals(vertices: [SIMD3<Float>], indices: [Int16]) -> [SIMD3<Float>] {
        var normals = [SIMD3<Float>](repeating: .zero, count: vertices.count)
        var i = 0
        while i + 2 < indices.count {
            let a = Int(indices[i]), b = Int(indices[i + 1]), c = Int(indices[i + 2])
            let n = simd_cross(vertices[b] - vertices[a], vertices[c] - vertices[a])
            normals[a] += n
            normals[b] += n
            normals[c] += n
            i += 3
        }
        return normals.map { simd_length($0) > 0 ? simd_normalize($0) : SIMD3<Float>(0, 0, 1) }
    }
}

/// Die AR-Ansicht für SwiftUI.
struct ARFaceView: UIViewRepresentable {
    let controller: ARFaceController

    func makeUIView(context: Context) -> ARSCNView { controller.sceneView }
    func updateUIView(_ view: ARSCNView, context: Context) {}
}
