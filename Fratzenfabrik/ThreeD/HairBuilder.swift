import SceneKit
import UIKit
import simd

/// Baut Frisuren und Accessoires aus einer Haar-Schale über dem Kopf plus Zöpfen, Dutts und Stacheln.
@MainActor
enum HairBuilder {
    private struct Shell {
        var thickness: Float
        var volume: Float
        var widowsPeak: Bool = false
        /// Oben platt abschneiden (Flat-Top).
        var flatTop: Float? = nil
    }

    static func build(_ hair: HairSuggestion, kid: Kid, mesh: HeadMesh) -> SCNNode {
        let node = SCNNode()
        let material = hairMaterial(hair)
        let accent = SCNMaterial()
        accent.lightingModel = .physicallyBased
        accent.diffuse.contents = kid == .girl ? UIColor(hex: 0xFF5FD2) : UIColor(hex: 0x8CFF3F)
        accent.roughness.contents = 0.4

        func add(_ geometry: SCNGeometry, _ position: SIMD3<Float>, mat: SCNMaterial? = nil, scale: SIMD3<Float> = .one, euler: SIMD3<Float> = .zero) {
            geometry.materials = [mat ?? material]
            let n = SCNNode(geometry: geometry)
            n.simdPosition = position
            n.simdScale = scale
            n.simdEulerAngles = euler
            node.addChildNode(n)
        }
        func sphere(_ r: CGFloat, _ p: SIMD3<Float>, mat: SCNMaterial? = nil, scale: SIMD3<Float> = .one) {
            add(SCNSphere(radius: r), p, mat: mat, scale: scale)
        }
        /// Strähne, die aus der Kopfhaut nach außen wächst (Spitze außen).
        func spike(at p: SIMD3<Float>, toward dir: SIMD3<Float>, length: Float, radius: Float) {
            let cone = SCNCone(topRadius: 0, bottomRadius: CGFloat(radius), height: CGFloat(length))
            cone.materials = [material]
            let n = SCNNode(geometry: cone)
            let d = simd_normalize(dir)
            n.simdPosition = p + d * (length * 0.42)
            n.simdOrientation = simd_quatf(from: SIMD3<Float>(0, 1, 0), to: d)
            node.addChildNode(n)
        }
        /// Weiches, länglich-rundes Haarbüschel, das in Richtung `dir` herabhängt.
        func clump(at p: SIMD3<Float>, toward dir: SIMD3<Float>, length: Float, radius: Float) {
            let blob = SCNSphere(radius: 1)
            blob.segmentCount = 16
            blob.materials = [material]
            let n = SCNNode(geometry: blob)
            let d = simd_normalize(dir)
            n.simdScale = SIMD3(radius, length / 2, radius * 0.8)
            n.simdPosition = p + d * (length * 0.35)
            n.simdOrientation = simd_quatf(from: SIMD3<Float>(0, 1, 0), to: d)
            node.addChildNode(n)
        }
        func scalpPoint(_ rng: inout SeededRandom, thetaMax: Float) -> (SIMD3<Float>, SIMD3<Float>)? {
            let theta = Float(rng.next(0.05, Double(thetaMax)))
            let phi = Float(rng.next(-3.14, 3.14))
            let dir = SIMD3<Float>(sin(theta) * sin(phi), cos(theta), sin(theta) * cos(phi))
            let p = HeadMesh.surface(dir)
            guard p.y > HairBuilder.hairline(phi: phi, widowsPeak: false) + 0.12 else { return nil }
            return (p, simd_normalize(p - HeadMesh.center))
        }
        var rng = SeededRandom(seed: 7)

        switch hair.style {
        case .short:
            node.addChildNode(shell(mesh, Shell(thickness: 0.08, volume: 0.14), material))
        case .slicked:
            material.roughness.contents = 0.22
            node.addChildNode(shell(mesh, Shell(thickness: 0.045, volume: 0.05, widowsPeak: true), material))
        case .spiky:
            node.addChildNode(shell(mesh, Shell(thickness: 0.09, volume: 0.12), material))
            var placed = 0
            while placed < 30 {
                guard let hit = scalpPoint(&rng, thetaMax: 1.0) else { continue }
                let (p, normal) = hit
                let lean = SIMD3<Float>(Float(rng.next(-0.2, 0.2)), 0.25, Float(rng.next(-0.35, 0.05)))
                spike(at: p + normal * 0.1, toward: normal + lean, length: Float(rng.next(0.45, 0.7)), radius: Float(rng.next(0.11, 0.16)))
                placed += 1
            }
        case .wild:
            node.addChildNode(shell(mesh, Shell(thickness: 0.12, volume: 0.24), material))
            var placed = 0
            while placed < 95 {
                guard let hit = scalpPoint(&rng, thetaMax: 1.6) else { continue }
                let (p, normal) = hit
                // Büschel hängen schwer nach unten und leicht nach außen – zottelig statt stachelig
                let droop = SIMD3<Float>(Float(rng.next(-0.3, 0.3)), -1.1, Float(rng.next(-0.3, 0.3)))
                clump(at: p + normal * 0.08, toward: normal * 0.7 + droop,
                      length: Float(rng.next(0.5, 0.95)), radius: Float(rng.next(0.13, 0.2)))
                placed += 1
            }
        case .pigtails:
            node.addChildNode(shell(mesh, Shell(thickness: 0.08, volume: 0.1), material))
            for side: Float in [-1, 1] {
                let tie = SIMD3<Float>(side * 1.12, 0.95, -0.45)
                sphere(0.24, tie + SIMD3(side * 0.04, 0.03, 0))
                clump(at: tie, toward: SIMD3(side * 0.18, -1, -0.08), length: 1.7, radius: 0.24)
                clump(at: tie + SIMD3(0, -0.05, -0.08), toward: SIMD3(side * 0.08, -1, -0.15), length: 1.45, radius: 0.19)
                add(SCNTorus(ringRadius: 0.13, pipeRadius: 0.045), tie + SIMD3(side * 0.03, -0.12, 0), mat: accent)
            }
        case .long:
            node.addChildNode(shell(mesh, Shell(thickness: 0.09, volume: 0.12), material))
            node.addChildNode(curtain(material))
        case .buns:
            node.addChildNode(shell(mesh, Shell(thickness: 0.08, volume: 0.1), material))
            for s: Float in [-1, 1] {
                sphere(0.4, SIMD3(s * 0.62, 1.62, -0.2))
                add(SCNTorus(ringRadius: 0.3, pipeRadius: 0.05), SIMD3(s * 0.55, 1.4, -0.18), mat: accent, euler: SIMD3(0, 0, s * 0.5))
            }
        case .ponytail:
            node.addChildNode(shell(mesh, Shell(thickness: 0.08, volume: 0.1), material))
            let tie = SIMD3<Float>(0, 1.05, -1.38)
            sphere(0.27, tie + SIMD3(0, 0.02, -0.06))
            clump(at: tie, toward: SIMD3(0, -1, -0.3), length: 2.0, radius: 0.3)
            clump(at: tie, toward: SIMD3(0.15, -1, -0.45), length: 1.7, radius: 0.22)
            clump(at: tie, toward: SIMD3(-0.15, -1, -0.45), length: 1.7, radius: 0.22)
            add(SCNTorus(ringRadius: 0.17, pipeRadius: 0.05), tie + SIMD3(0, -0.05, -0.15), mat: accent, euler: SIMD3(1.2, 0, 0))
        case .flatTop:
            node.addChildNode(shell(mesh, Shell(thickness: 0.1, volume: 0.6, flatTop: 2.0), material))
        case .bandaged:
            for (y, tilt) in [(Float(1.62), Float(0.1)), (1.32, -0.12), (1.02, 0.14), (1.84, 0.0), (0.72, -0.08)] {
                let rel = (y - HeadMesh.center.y) / HeadMesh.ryTop
                let ring = HeadMesh.rx * sqrt(max(0.05, 1 - rel * rel)) + 0.03
                let torus = SCNTorus(ringRadius: CGFloat(ring), pipeRadius: 0.1)
                add(torus, SIMD3(0, y, HeadMesh.center.z), scale: SIMD3(1, 1, HeadMesh.rz / HeadMesh.rx), euler: SIMD3(tilt, 0, tilt * 0.5))
            }
            add(SCNBox(width: 0.2, height: 0.9, length: 0.04, chamferRadius: 0.01), SIMD3(0.95, 0.9, -0.9), euler: SIMD3(0.2, 0.6, 0.25))
        case .braids:
            node.addChildNode(shell(mesh, Shell(thickness: 0.08, volume: 0.1), material))
            for s: Float in [-1, 1] {
                for i in 0..<9 {
                    let fi = Float(i)
                    let zig: Float = i % 2 == 0 ? 0.045 : -0.045
                    sphere(CGFloat(0.16 - 0.006 * fi), SIMD3(s * 1.1 + zig, 0.4 - 0.27 * fi, -0.45))
                }
                sphere(0.07, SIMD3(s * 1.1, 0.4 - 0.27 * 9, -0.45), mat: accent)
            }
        }

        if let accessory = hair.accessory {
            node.addChildNode(build(accessory))
        }
        return node
    }

    /// Wimpern für die Mädchen.
    static func extras(kid: Kid) -> SCNNode {
        let node = SCNNode()
        guard kid == .girl else { return node }
        let mat = SCNMaterial()
        mat.diffuse.contents = UIColor(hex: 0x1B1210)
        let eyeZ = HeadMesh.frontZ(x: 0.5, y: 0) - 0.1
        for s: Float in [-1, 1] {
            for i in 0..<3 {
                let fi = Float(i)
                let lash = SCNNode(geometry: SCNBox(width: 0.014, height: 0.1, length: 0.014, chamferRadius: 0.007))
                lash.geometry?.materials = [mat]
                let angle = 0.25 + 0.3 * fi
                lash.position = SCNVector3(s * (0.5 + sin(angle) * 0.15), cos(angle) * 0.14 + 0.02, eyeZ + 0.06)
                lash.eulerAngles.z = -s * (angle + 0.2)
                node.addChildNode(lash)
            }
        }
        return node
    }

    // MARK: Haarschale

    /// Haaransatz-Höhe (y) je nach Richtung: vorne hoch an der Stirn, hinten tief im Nacken.
    static func hairline(phi: Float, widowsPeak: Bool) -> Float {
        let a = abs(phi)
        var h: Float
        if a < 0.75 {
            h = 1.3 - 0.2 * (a / 0.75)
        } else if a < 1.45 {
            h = 1.1 + (0.25 - 1.1) * ((a - 0.75) / 0.7)
        } else if a < 2.2 {
            h = 0.25 + (-0.75 - 0.25) * ((a - 1.45) / 0.75)
        } else {
            h = -0.75 + (-1.25 + 0.75) * ((a - 2.2) / (.pi - 2.2))
        }
        if widowsPeak { h -= 0.28 * exp(-pow(phi / 0.12, 2)) }
        return h
    }

    private static func shell(_ mesh: HeadMesh, _ style: Shell, _ material: SCNMaterial) -> SCNNode {
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var uvs: [CGPoint] = []
        var inside: [Bool] = []
        for i in mesh.positions.indices {
            let p = mesh.positions[i]
            let phi = mesh.azimuths[i]
            let h = hairline(phi: phi, widowsPeak: style.widowsPeak)
            let taper = smoothstep(h, h + 0.3, p.y)
            let thickness = (style.thickness + style.volume * smoothstep(0.5, 1.8, p.y)) * taper
            let n = mesh.normals[i]
            var q = p + n * (thickness + 0.015)
            if let flat = style.flatTop { q.y = min(q.y, flat) }
            positions.append(q)
            normals.append(n)
            uvs.append(CGPoint(x: CGFloat(phi / (2 * .pi) + 0.5), y: CGFloat(1 - (p.y + 2) / 4)))
            inside.append(p.y > h - 0.02)
        }
        var indices: [UInt32] = []
        let all = mesh.triangleIndices
        var t = 0
        while t < all.count {
            let a = Int(all[t]), b = Int(all[t + 1]), c = Int(all[t + 2])
            if inside[a] && inside[b] && inside[c] {
                indices += [all[t], all[t + 1], all[t + 2]]
            }
            t += 3
        }
        let geometry = SCNGeometry.make(positions: positions, normals: normals, uvs: uvs, indices: indices)
        geometry.materials = [material]
        return SCNNode(geometry: geometry)
    }

    /// Lange Haare als fließender Vorhang um Hinterkopf und Seiten – mit leichten Wellen.
    private static func curtain(_ material: SCNMaterial) -> SCNNode {
        let azSteps = 56, ySteps = 34
        let azFrom: Float = 72 * .pi / 180, azTo: Float = 288 * .pi / 180
        let yTop: Float = 0.95, yBottom: Float = -2.35
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var uvs: [CGPoint] = []
        for j in 0...ySteps {
            let y = yTop + (yBottom - yTop) * Float(j) / Float(ySteps)
            let rel = min(max((y - HeadMesh.center.y) / (y > HeadMesh.center.y ? HeadMesh.ryTop : HeadMesh.ryBottom), -1), 1)
            let round = sqrt(max(0, 1 - rel * rel))
            let flare = 0.3 * smoothstep(-0.6, -2.35, y)
            let rx = max(HeadMesh.rx * round, 0.98) + 0.14 + flare
            let rz = max(HeadMesh.rz * 1.06 * round, 1.05) + 0.14 + flare
            for i in 0...azSteps {
                let az = azFrom + (azTo - azFrom) * Float(i) / Float(azSteps)
                let wave = 1 + 0.035 * sin(az * 11 + y * 2)
                positions.append(SIMD3(sin(az) * rx * wave, y, HeadMesh.center.z + cos(az) * rz * wave))
                normals.append(simd_normalize(SIMD3(sin(az), 0, cos(az))))
                uvs.append(CGPoint(x: CGFloat(az / (2 * .pi)), y: CGFloat(Float(j) / Float(ySteps))))
            }
        }
        var indices: [UInt32] = []
        let row = azSteps + 1
        for j in 0..<ySteps {
            for i in 0..<azSteps {
                let a = UInt32(j * row + i), b = a + 1, c = UInt32((j + 1) * row + i), d = c + 1
                indices += [a, c, b, b, c, d]
            }
        }
        let geometry = SCNGeometry.make(positions: positions, normals: normals, uvs: uvs, indices: indices)
        geometry.materials = [material]
        return SCNNode(geometry: geometry)
    }

    private static func hairMaterial(_ hair: HairSuggestion) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        m.diffuse.contents = strandTexture(base: hair.color, streak: hair.streak)
        m.roughness.contents = 0.62
        m.metalness.contents = 0.0
        m.isDoubleSided = true
        return m
    }

    /// Feine Haarsträhnen als Textur: dunkler Ansatz, Glanzband, optional farbige Spray-Strähnen.
    /// Bewusst deckend gemalt (normaler Mischmodus) – sonst werden die Haare durchsichtig.
    private static func strandTexture(base: UIColor, streak: UIColor?) -> UIImage {
        let size = CGSize(width: 512, height: 512)
        var rng = SeededRandom(seed: 42)
        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let cg = ctx.cgContext
            cg.setBlendMode(.normal)
            cg.setFillColor(base.cgColor)
            cg.fill(CGRect(origin: .zero, size: size))
            for _ in 0..<420 {
                let x = CGFloat(rng.next(0, 512))
                let w = CGFloat(rng.next(1, 3.5))
                let shade = CGFloat(rng.next(-0.28, 0.22))
                cg.setFillColor((shade > 0 ? UIColor.white : UIColor.black).withAlphaComponent(abs(shade)).cgColor)
                cg.fill(CGRect(x: x, y: 0, width: w, height: 512))
            }
            if let streak {
                for i in 0..<7 {
                    let x = CGFloat(i) * 73 + 20
                    cg.setFillColor(streak.withAlphaComponent(0.92).cgColor)
                    cg.fill(CGRect(x: x, y: 0, width: 18, height: 512))
                }
            }
            let space = CGColorSpaceCreateDeviceRGB()
            // Dunklerer Ansatz am Scheitel
            if let roots = CGGradient(colorsSpace: space, colors: [UIColor.black.withAlphaComponent(0.35).cgColor,
                                                                  UIColor.black.withAlphaComponent(0).cgColor] as CFArray,
                                      locations: [0, 1]) {
                cg.drawLinearGradient(roots, start: .zero, end: CGPoint(x: 0, y: 160), options: [])
            }
            // Glanzband wie bei echtem Haar
            if let sheen = CGGradient(colorsSpace: space, colors: [UIColor.white.withAlphaComponent(0).cgColor,
                                                                  UIColor.white.withAlphaComponent(0.18).cgColor,
                                                                  UIColor.white.withAlphaComponent(0).cgColor] as CFArray,
                                      locations: [0, 0.5, 1]) {
                cg.drawLinearGradient(sheen, start: CGPoint(x: 0, y: 150), end: CGPoint(x: 0, y: 230), options: [])
            }
        }
    }

    // MARK: Accessoires

    private static func build(_ accessory: Accessory) -> SCNNode {
        let node = SCNNode()
        func mat(_ hex: UInt32, roughness: CGFloat = 0.6) -> SCNMaterial {
            let m = SCNMaterial()
            m.lightingModel = .physicallyBased
            m.diffuse.contents = UIColor(hex: hex)
            m.roughness.contents = roughness
            return m
        }
        func add(_ g: SCNGeometry, _ m: SCNMaterial, _ p: SIMD3<Float>, euler: SIMD3<Float> = .zero, scale: SIMD3<Float> = .one) {
            g.materials = [m]
            let n = SCNNode(geometry: g)
            n.simdPosition = p
            n.simdEulerAngles = euler
            n.simdScale = scale
            node.addChildNode(n)
        }
        switch accessory {
        case .catEars:
            for s: Float in [-1, 1] {
                add(SCNPyramid(width: 0.6, height: 0.62, length: 0.16), mat(0x1C1714), SIMD3(s * 0.66, 1.62, 0.0), euler: SIMD3(0, 0, -s * 0.38))
                add(SCNPyramid(width: 0.34, height: 0.38, length: 0.04), mat(0xFF8FB8), SIMD3(s * 0.66, 1.66, 0.09), euler: SIMD3(0, 0, -s * 0.38))
            }
        case .witchHat:
            let hat = mat(0x2A1838, roughness: 0.75)
            add(SCNCylinder(radius: 1.8, height: 0.06), hat, SIMD3(0, 1.66, -0.15), euler: SIMD3(-0.1, 0, 0.04))
            add(SCNCone(topRadius: 0.05, bottomRadius: 0.98, height: 2.1), hat, SIMD3(0, 2.72, -0.3), euler: SIMD3(-0.12, 0, 0.06))
            add(SCNCone(topRadius: 0.0, bottomRadius: 0.1, height: 0.5), hat, SIMD3(0.12, 3.85, -0.48), euler: SIMD3(-0.2, 0, -0.7))
            add(SCNCylinder(radius: 0.99, height: 0.24), mat(0xFF7A1A), SIMD3(0, 1.82, -0.16), euler: SIMD3(-0.1, 0, 0.04))
        case .horns:
            let red = mat(0xB3102A, roughness: 0.35)
            for s: Float in [-1, 1] {
                add(SCNCone(topRadius: 0.012, bottomRadius: 0.15, height: 0.6), red, SIMD3(s * 0.52, 1.72, 0.2), euler: SIMD3(0.15, 0, -s * 0.5))
            }
        case .bow:
            let pink = mat(0xFF5FD2, roughness: 0.4)
            add(SCNPyramid(width: 0.4, height: 0.32, length: 0.12), pink, SIMD3(0.48, 1.55, 0.55), euler: SIMD3(0, 0, .pi / 2))
            add(SCNPyramid(width: 0.4, height: 0.32, length: 0.12), pink, SIMD3(0.92, 1.42, 0.45), euler: SIMD3(0, 0, -.pi / 2))
            add(SCNSphere(radius: 0.09), pink, SIMD3(0.7, 1.5, 0.52))
        case .flowers:
            let colors: [UInt32] = [0xFF5FD2, 0xFFD93B, 0x2EC4C6, 0xFF7A1A, 0xD3122F]
            for k in 0..<9 {
                let az = (-80 + Float(k) * 20) * .pi / 180
                let p = SIMD3<Float>(1.05 * sin(az), 1.52 - 0.12 * abs(sin(az)), HeadMesh.center.z + 1.1 * cos(az))
                add(SCNSphere(radius: 0.15), mat(colors[k % colors.count], roughness: 0.5), p, scale: SIMD3(1, 1, 0.6))
                add(SCNSphere(radius: 0.05), mat(0xFFF1A8), p + SIMD3(0, 0, 0.09))
            }
        }
        return node
    }
}

/// Reproduzierbarer Zufall – jede Frisur sieht bei jedem Start gleich aus.
struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed &* 6364136223846793005 &+ 1442695040888963407 }
    mutating func next(_ lo: Double, _ hi: Double) -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        let unit = Double(state >> 11) / Double(1 << 53)
        return lo + (hi - lo) * unit
    }
}
