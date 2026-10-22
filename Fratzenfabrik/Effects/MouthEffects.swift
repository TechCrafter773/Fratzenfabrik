import SwiftUI

/// Wenn das Kind den Mund aufreißt, fliegen Geister, Fledermäuse, Flammen … heraus.
final class ParticleField {
    struct Particle {
        let origin: CGPoint
        let velocity: CGVector
        let birth: Date
        let emoji: String
        let size: CGFloat
        let spin: Double
    }

    private(set) var particles: [Particle] = []
    private var lastEmit = Date.distantPast
    static let lifetime: TimeInterval = 1.8

    func update(now: Date, mouth: CGPoint?, open: Bool, emojis: [String]) {
        particles.removeAll { now.timeIntervalSince($0.birth) > Self.lifetime }
        guard open, let mouth, let emoji = emojis.randomElement(), now.timeIntervalSince(lastEmit) > 0.09 else { return }
        lastEmit = now
        let angle = -Double.pi / 2 + Double.random(in: -0.95...0.95)
        let speed = Double.random(in: 170...330)
        particles.append(Particle(
            origin: mouth,
            velocity: CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed),
            birth: now,
            emoji: emoji,
            size: CGFloat.random(in: 26...46),
            spin: Double.random(in: -3...3)
        ))
    }
}

struct MouthEffectLayer: View {
    let mouth: CGPoint?
    let open: Bool
    let emojis: [String]
    @State private var field = ParticleField()

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { ctx, _ in
                let now = timeline.date
                field.update(now: now, mouth: mouth, open: open, emojis: emojis)
                for p in field.particles {
                    let t = now.timeIntervalSince(p.birth)
                    let x = p.origin.x + p.velocity.dx * t
                    let y = p.origin.y + p.velocity.dy * t + 70 * t * t
                    let grow = min(1, 0.35 + t / 0.25)
                    let fade = min(1, (ParticleField.lifetime - t) / 0.5)
                    var c = ctx
                    c.opacity = max(0, fade)
                    c.translateBy(x: x, y: y)
                    c.rotate(by: .radians(p.spin * t))
                    c.scaleBy(x: grow, y: grow)
                    c.draw(Text(p.emoji).font(.system(size: p.size)), at: .zero)
                }
            }
        }
        .allowsHitTesting(false)
    }
}
