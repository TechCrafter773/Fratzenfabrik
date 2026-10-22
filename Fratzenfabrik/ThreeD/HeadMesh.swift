import SceneKit
import simd

/// Ein modellierter Kinderkopf im Gesichtsraum: Augenabstand = 1, x nach rechts, y nach oben, z zum Betrachter.
/// Die Augen liegen bei (±0,5 | 0), die Nasenspitze bei y ≈ -0,62, der Mund bei y ≈ -1,05.
struct HeadMesh {
    static let center = SIMD3<Float>(0, -0.05, -0.25)
    static let rx: Float = 1.12
    static let ryTop: Float = 1.85
    static let ryBottom: Float = 1.95
    static let rz: Float = 1.3

    let rows: Int
    let cols: Int
    var positions: [SIMD3<Float>] = []
    var normals: [SIMD3<Float>] = []
    /// Azimut je Vertex: 0 = vorne, ±π = hinten.
    var azimuths: [Float] = []

    init(rows: Int = 110, cols: Int = 128) {
        self.rows = rows
        self.cols = cols
        for r in 0...rows {
            let theta = Float(r) / Float(rows) * .pi
            for c in 0...cols {
                let phi = Float(c) / Float(cols) * 2 * .pi - .pi
                let dir = SIMD3<Float>(sin(theta) * sin(phi), cos(theta), sin(theta) * cos(phi))
                positions.append(HeadMesh.surface(dir))
                azimuths.append(phi)
            }
        }
        normals = Array(repeating: SIMD3<Float>(0, 1, 0), count: positions.count)
        for r in 0...rows {
            for c in 0...cols {
                let up = positions[index(max(r - 1, 0), c)]
                let down = positions[index(min(r + 1, rows), c)]
                let left = positions[index(r, c == 0 ? cols - 1 : c - 1)]
                let right = positions[index(r, c == cols ? 1 : c + 1)]
                var n = simd_cross(right - left, down - up)
                let outward = positions[index(r, c)] - HeadMesh.center
                if simd_length(n) < 1e-6 { n = outward }
                n = simd_normalize(n)
                if simd_dot(n, outward) < 0 { n = -n }
                normals[index(r, c)] = n
            }
        }
    }

    func index(_ r: Int, _ c: Int) -> Int { r * (cols + 1) + c }

    var triangleIndices: [UInt32] {
        var idx: [UInt32] = []
        idx.reserveCapacity(rows * cols * 6)
        for r in 0..<rows {
            for c in 0..<cols {
                let a = UInt32(index(r, c)), b = UInt32(index(r, c + 1))
                let d = UInt32(index(r + 1, c)), e = UInt32(index(r + 1, c + 1))
                idx += [a, d, b, b, d, e]
            }
        }
        return idx
    }

    /// Punkt auf der Kopfoberfläche in Richtung `d` – Ellipsoid plus Gesichtsmodellierung.
    static func surface(_ d: SIMD3<Float>) -> SIMD3<Float> {
        var p = SIMD3<Float>(d.x * rx, d.y * (d.y > 0 ? ryTop : ryBottom), d.z * rz * (d.z < 0 ? 1.06 : 1)) + center

        // Kiefer und Kinn werden schmaler
        let jaw = smoothstep(-0.2, -1.9, p.y)
        p.x *= 1 - 0.3 * jaw
        p.z = center.z + (p.z - center.z) * (1 - 0.08 * jaw)

        let front = smoothstep(0.15, 0.6, d.z)
        guard front > 0 else { return p }
        let x = p.x
        let ax = abs(x)
        let ny = -p.y // Gesichtsraum: nach unten positiv
        var bump: Float = 0

        // Nase: Rücken wird zur Spitze hin höher und breiter, darunter fällt sie steil ab
        var noseHeight: Float = 0
        if ny > -0.05 && ny <= 0.62 {
            noseHeight = 0.06 + 0.26 * pow(max(ny, 0) / 0.62, 1.6)
        } else if ny > 0.62 && ny < 0.82 {
            noseHeight = 0.32 * (1 - smoothstep(0.62, 0.8, ny))
        }
        let noseWidth: Float = 0.08 + 0.09 * min(max(ny, 0) / 0.62, 1)
        bump += noseHeight * exp(-pow(x / noseWidth, 2))
        bump += 0.07 * exp(-pow((ax - 0.13) / 0.07, 2) - pow((ny - 0.66) / 0.07, 2))   // Nasenflügel
        bump -= 0.1 * exp(-pow((ax - 0.5) / 0.24, 2) - pow(ny / 0.17, 2))             // Augenhöhlen
        bump += 0.07 * exp(-pow((ny + 0.33) / 0.12, 2)) * exp(-pow(x / 0.95, 4))        // Brauenbogen
        bump += 0.08 * exp(-pow((ax - 0.62) / 0.28, 2) - pow((ny - 0.55) / 0.3, 2))    // Wangen
        bump += 0.06 * exp(-pow(x / 0.32, 2) - pow((ny - 0.98) / 0.07, 2))             // Oberlippe
        bump += 0.07 * exp(-pow(x / 0.28, 2) - pow((ny - 1.13) / 0.08, 2))             // Unterlippe
        bump -= 0.03 * exp(-pow(x / 0.34, 2) - pow((ny - 1.05) / 0.025, 2))            // Mundlinie
        bump += 0.1 * exp(-pow(x / 0.35, 2) - pow((ny - 1.62) / 0.2, 2))               // Kinn
        p.z += bump * front
        return p
    }

    /// Wo liegt die Haut an der Stelle (x, y) von vorne gesehen?
    static func frontZ(x: Float, y: Float) -> Float {
        // Grobe Suche entlang der Blickrichtung über die Richtungsparametrisierung
        var best = SIMD3<Float>(0, 0, 0)
        var bestDist = Float.greatestFiniteMagnitude
        for i in 0...40 {
            for j in 0...40 {
                let theta = Float.pi * (0.15 + 0.7 * Float(i) / 40)
                let phi = Float.pi * (-0.45 + 0.9 * Float(j) / 40)
                let dir = SIMD3<Float>(sin(theta) * sin(phi), cos(theta), sin(theta) * cos(phi))
                let s = surface(dir)
                let dist = hypot(s.x - x, s.y - y)
                if dist < bestDist { bestDist = dist; best = s }
            }
        }
        return best.z
    }
}

func smoothstep(_ edge0: Float, _ edge1: Float, _ x: Float) -> Float {
    let t = min(max((x - edge0) / (edge1 - edge0), 0), 1)
    return t * t * (3 - 2 * t)
}

extension SCNGeometry {
    static func make(positions: [SIMD3<Float>], normals: [SIMD3<Float>], uvs: [CGPoint], indices: [UInt32]) -> SCNGeometry {
        let v = SCNGeometrySource(vertices: positions.map { SCNVector3($0.x, $0.y, $0.z) })
        let n = SCNGeometrySource(normals: normals.map { SCNVector3($0.x, $0.y, $0.z) })
        let t = SCNGeometrySource(textureCoordinates: uvs)
        let e = SCNGeometryElement(indices: indices, primitiveType: .triangles)
        return SCNGeometry(sources: [v, n, t], elements: [e])
    }
}
