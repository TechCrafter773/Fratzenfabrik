import SceneKit
import SwiftUI

/// Wunsch, das Modell auf einen bestimmten Winkel zu drehen (die `id` erlaubt Wiederholungen).
struct TurnRequest: Equatable {
    var id = UUID()
    var yaw: Float
}

/// Drehbares 3D-Kind mit Schminke und Frisur. Wischen dreht den Kopf.
struct Head3DView: UIViewRepresentable {
    let design: DesignID?
    let kid: Kid
    let hair: HairSuggestion
    var visibleSteps: Int?
    var turn: TurnRequest?

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero)
        view.backgroundColor = .clear
        view.scene = context.coordinator.stage.scene
        view.pointOfView = context.coordinator.stage.cameraNode
        view.antialiasingMode = .multisampling4X
        view.isJitteringEnabled = true
        view.autoenablesDefaultLighting = false
        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.pan(_:)))
        pan.delegate = context.coordinator
        view.addGestureRecognizer(pan)
        context.coordinator.stage.configure(kid: kid, hair: hair, design: design, visibleSteps: visibleSteps)
        context.coordinator.startIdleSway()
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        let c = context.coordinator
        c.stage.configure(kid: kid, hair: hair, design: design, visibleSteps: visibleSteps)
        if let turn, turn != c.lastTurn {
            c.lastTurn = turn
            c.stopIdleSway()
            c.stage.setYaw(turn.yaw, animated: true)
        }
    }

    @MainActor
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        let stage = KidStage()
        var lastTurn: TurnRequest?
        private var startYaw: Float = 0
        private var swaying = false

        /// Leichtes Hin- und Herdrehen, damit man sofort sieht: das ist 3D.
        func startIdleSway() {
            swaying = true
            let left = SCNAction.rotateTo(x: 0, y: -0.35, z: 0, duration: 2.4, usesShortestUnitArc: true)
            let right = SCNAction.rotateTo(x: 0, y: 0.35, z: 0, duration: 2.4, usesShortestUnitArc: true)
            left.timingMode = .easeInEaseOut
            right.timingMode = .easeInEaseOut
            stage.root.runAction(.repeatForever(.sequence([left, right])), forKey: "sway")
        }

        func stopIdleSway() {
            guard swaying else { return }
            swaying = false
            stage.root.removeAction(forKey: "sway")
        }

        /// Nur waagerechtes Wischen dreht – senkrecht scrollt die Seite weiter.
        func gestureRecognizerShouldBegin(_ gesture: UIGestureRecognizer) -> Bool {
            guard let pan = gesture as? UIPanGestureRecognizer else { return true }
            let v = pan.velocity(in: pan.view)
            return abs(v.x) > abs(v.y)
        }

        @objc func pan(_ gesture: UIPanGestureRecognizer) {
            switch gesture.state {
            case .began:
                stopIdleSway()
                startYaw = stage.yaw
            case .changed:
                let dx = Float(gesture.translation(in: gesture.view).x)
                stage.setYaw(startYaw + dx * 0.012, animated: false)
            default:
                break
            }
        }
    }
}

/// Erzeugt Vorschaubilder der 3D-Kinder für die Karten (einmal gerendert, dann zwischengespeichert).
@MainActor
final class HeadThumbnails: ObservableObject {
    static let shared = HeadThumbnails()

    @Published private(set) var images: [String: UIImage] = [:]
    private var pending: [(DesignID, Kid)] = []
    private var working = false
    private lazy var stage = KidStage()
    private lazy var renderer: SCNRenderer = {
        let r = SCNRenderer(device: MTLCreateSystemDefaultDevice(), options: nil)
        r.scene = stage.scene
        r.pointOfView = stage.thumbnailCameraNode
        r.autoenablesDefaultLighting = false
        return r
    }()

    static func key(_ design: DesignID, _ kid: Kid) -> String { "\(design.rawValue)|\(kid.rawValue)" }

    func image(_ design: DesignID, _ kid: Kid) -> UIImage? { images[Self.key(design, kid)] }

    func request(_ design: DesignID, _ kid: Kid) {
        guard images[Self.key(design, kid)] == nil, !pending.contains(where: { $0 == (design, kid) }) else { return }
        pending.append((design, kid))
        guard !working else { return }
        working = true
        Task { await work() }
    }

    private func work() async {
        while !pending.isEmpty {
            let (design, kid) = pending.removeFirst()
            let d = DesignCatalog.design(design)
            stage.configure(kid: kid, hair: d.hair(for: kid), design: design, visibleSteps: nil)
            stage.setYaw(-0.28, animated: false)
            stage.scene.background.contents = Self.backdrop
            let image = renderer.snapshot(atTime: 0, with: CGSize(width: 360, height: 420), antialiasingMode: .multisampling4X)
            stage.scene.background.contents = nil
            images[Self.key(design, kid)] = image
            await Task.yield()
        }
        working = false
    }

    private static let backdrop: UIImage = {
        let size = CGSize(width: 256, height: 300)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let colors = [UIColor(hex: 0x6A2C9E).cgColor, UIColor(hex: 0x2B0B45).cgColor] as CFArray
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
            ctx.cgContext.drawRadialGradient(gradient, startCenter: CGPoint(x: 128, y: 120), startRadius: 0,
                                             endCenter: CGPoint(x: 128, y: 120), endRadius: 220, options: .drawsAfterEndLocation)
        }
    }()
}

/// Karte-Vorschau: zeigt das gerenderte 3D-Kind oder ein Platzhalter-Emoji, solange es entsteht.
struct KidThumbnail: View {
    let design: FaceDesign
    let kid: Kid
    @ObservedObject private var thumbnails = HeadThumbnails.shared

    var body: some View {
        ZStack {
            if let image = thumbnails.image(design.id, kid) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity)
            } else {
                RadialGradient(colors: [Color(hex: 0x6A2C9E), Spook.plum], center: .center, startRadius: 0, endRadius: 120)
                Text(design.emoji).font(.system(size: 44)).wobble(10, speed: 3)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: thumbnails.image(design.id, kid) != nil)
        .onAppear { thumbnails.request(design.id, kid) }
        .onChange(of: kid) { _, newKid in thumbnails.request(design.id, newKid) }
    }
}
