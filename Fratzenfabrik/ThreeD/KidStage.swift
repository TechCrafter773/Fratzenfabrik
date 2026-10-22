import SceneKit
import UIKit
import simd

/// Die 3D-Bühne: ein Kinderkopf mit Frisur, angemalt mit einem Schmink-Design.
@MainActor
final class KidStage {
    let scene = SCNScene()
    let root = SCNNode()
    let cameraNode = SCNNode()
    let thumbnailCameraNode = SCNNode()

    private let headNode = SCNNode()
    private let skinMaterial = SCNMaterial()
    private var hairNode = SCNNode()
    private var extrasNode = SCNNode()
    private var shirtMaterial = SCNMaterial()

    private static let mesh = HeadMesh()
    private static let headGeometry: SCNGeometry = {
        let m = mesh
        let uvs: [CGPoint] = zip(m.positions, m.azimuths).map { p, phi in
            let v = TextureSpace.uv(x: CGFloat(p.x), y: CGFloat(-p.y))
            if abs(phi) < .pi / 2 {
                return CGPoint(x: min(max(v.x, 0.01), 0.99), y: min(max(v.y, 0.01), 0.99))
            }
            // Hinterkopf: Haut aus dem Randbereich der Textur
            return CGPoint(x: p.x < 0 ? 0.02 : 0.98, y: min(max(v.y, 0.01), 0.99))
        }
        return SCNGeometry.make(positions: m.positions, normals: m.normals, uvs: uvs, indices: m.triangleIndices)
    }()

    private(set) var kid: Kid?
    private var hairKey = ""
    private var paintKey = ""

    init() {
        scene.rootNode.addChildNode(root)
        root.addChildNode(headNode)

        skinMaterial.lightingModel = .physicallyBased
        skinMaterial.roughness.contents = 0.62
        skinMaterial.metalness.contents = 0.0
        skinMaterial.isDoubleSided = true
        let head = KidStage.headGeometry.copy() as! SCNGeometry
        head.materials = [skinMaterial]
        headNode.geometry = head

        buildBody()
        buildLights()

        let camera = SCNCamera()
        camera.fieldOfView = 30
        camera.wantsHDR = false
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 0, 14)
        cameraNode.look(at: SCNVector3(0, -0.1, 0))
        scene.rootNode.addChildNode(cameraNode)

        let thumbCamera = SCNCamera()
        thumbCamera.fieldOfView = 30
        thumbnailCameraNode.camera = thumbCamera
        thumbnailCameraNode.position = SCNVector3(0.9, 0.3, 11.2)
        thumbnailCameraNode.look(at: SCNVector3(0, 0.15, 0))
        scene.rootNode.addChildNode(thumbnailCameraNode)
    }

    // MARK: Aufbau

    /// Zieht das Kind an: Frisur, Augen, Kleidung und Schminke.
    func configure(kid: Kid, hair: HairSuggestion, design: DesignID?, visibleSteps: Int?) {
        let newHairKey = "\(kid)|\(hair.style)|\(hair.color)|\(String(describing: hair.streak))|\(String(describing: hair.accessory))"
        if newHairKey != hairKey || self.kid != kid {
            hairKey = newHairKey
            self.kid = kid
            rebuildHair(kid: kid, hair: hair)
            shirtMaterial.diffuse.contents = kid == .girl ? UIColor(hex: 0x7A3FC2) : UIColor(hex: 0xE2741E)
        }
        let newPaintKey = "\(design?.rawValue ?? "-")|\(visibleSteps ?? -1)|\(kid)"
        if newPaintKey != paintKey {
            paintKey = newPaintKey
            skinMaterial.diffuse.contents = DesignTexture.image(design: design, visibleSteps: visibleSteps, kid: kid)
        }
    }

    private func buildBody() {
        let skin = SCNMaterial()
        skin.lightingModel = .physicallyBased
        skin.diffuse.contents = SkinPainter.skinUI
        skin.roughness.contents = 0.62

        // Ohren
        for s: Float in [-1, 1] {
            let ear = SCNNode(geometry: SCNSphere(radius: 1))
            ear.geometry?.materials = [skin]
            ear.scale = SCNVector3(0.13, 0.3, 0.2)
            ear.position = SCNVector3(s * 1.06, -0.2, -0.3)
            ear.eulerAngles.y = s * 0.35
            root.addChildNode(ear)
        }
        // Hals
        let neck = SCNNode(geometry: SCNCylinder(radius: 0.55, height: 1.7))
        neck.geometry?.materials = [skin]
        neck.position = SCNVector3(0, -2.35, -0.4)
        root.addChildNode(neck)
        // Oberkörper
        shirtMaterial.lightingModel = .physicallyBased
        shirtMaterial.roughness.contents = 0.85
        let torso = SCNNode(geometry: SCNSphere(radius: 1))
        torso.geometry?.materials = [shirtMaterial]
        torso.scale = SCNVector3(2.15, 1.05, 1.15)
        torso.position = SCNVector3(0, -3.75, -0.4)
        root.addChildNode(torso)

        // Augen
        let eyeZ = HeadMesh.frontZ(x: 0.5, y: 0) - 0.1
        for s: Float in [-1, 1] {
            let eye = SCNNode()
            eye.position = SCNVector3(s * 0.5, 0, eyeZ)
            let ball = SCNNode(geometry: SCNSphere(radius: 0.15))
            let white = SCNMaterial()
            white.lightingModel = .physicallyBased
            white.diffuse.contents = UIColor(hex: 0xF7F4F0)
            white.roughness.contents = 0.12
            ball.geometry?.materials = [white]
            eye.addChildNode(ball)

            let iris = SCNNode(geometry: SCNCylinder(radius: 0.078, height: 0.012))
            let irisMat = SCNMaterial()
            irisMat.lightingModel = .physicallyBased
            irisMat.diffuse.contents = UIColor(hex: 0x6B4A2B)
            irisMat.roughness.contents = 0.2
            iris.geometry?.materials = [irisMat]
            iris.eulerAngles.x = .pi / 2
            iris.position = SCNVector3(0, 0, 0.142)
            eye.addChildNode(iris)

            let pupil = SCNNode(geometry: SCNCylinder(radius: 0.038, height: 0.012))
            let pupilMat = SCNMaterial()
            pupilMat.diffuse.contents = UIColor.black
            pupil.geometry?.materials = [pupilMat]
            pupil.eulerAngles.x = .pi / 2
            pupil.position = SCNVector3(0, 0, 0.149)
            eye.addChildNode(pupil)

            let shine = SCNNode(geometry: SCNSphere(radius: 0.016))
            let shineMat = SCNMaterial()
            shineMat.lightingModel = .constant
            shineMat.diffuse.contents = UIColor.white
            shine.geometry?.materials = [shineMat]
            shine.position = SCNVector3(0.03, 0.035, 0.152)
            eye.addChildNode(shine)

            root.addChildNode(eye)
        }
    }

    private func buildLights() {
        func directional(_ intensity: CGFloat, _ color: UIColor, from position: SCNVector3) {
            let light = SCNLight()
            light.type = .directional
            light.intensity = intensity
            light.color = color
            let node = SCNNode()
            node.light = light
            node.position = position
            node.look(at: SCNVector3(0, 0, 0))
            scene.rootNode.addChildNode(node)
        }
        directional(1100, UIColor(hex: 0xFFF1E0), from: SCNVector3(-6, 6, 10))
        directional(450, UIColor(hex: 0xD8E4FF), from: SCNVector3(7, 1, 8))
        directional(900, UIColor(hex: 0xB48CFF), from: SCNVector3(0, 5, -10))
        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = 280
        ambient.color = UIColor(hex: 0x8A7AA8)
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)
    }

    // MARK: Frisuren

    private func rebuildHair(kid: Kid, hair: HairSuggestion) {
        hairNode.removeFromParentNode()
        extrasNode.removeFromParentNode()
        hairNode = HairBuilder.build(hair, kid: kid, mesh: KidStage.mesh)
        extrasNode = HairBuilder.extras(kid: kid)
        root.addChildNode(hairNode)
        root.addChildNode(extrasNode)
    }

    // MARK: Drehen

    func setYaw(_ yaw: Float, animated: Bool) {
        SCNTransaction.begin()
        SCNTransaction.animationDuration = animated ? 0.6 : 0
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        root.eulerAngles.y = yaw
        SCNTransaction.commit()
    }

    var yaw: Float { root.eulerAngles.y }
}
