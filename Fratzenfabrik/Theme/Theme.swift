import SwiftUI

/// Farben & Schriften der Fratzenfabrik – Mitternachtslila, Schleimgrün, Kürbisorange.
enum Spook {
    static let night = Color(hex: 0x12051F)
    static let plum = Color(hex: 0x2B0B45)
    static let grape = Color(hex: 0x4A1673)
    static let violet = Color(hex: 0x9B4DFF)
    static let slime = Color(hex: 0x8CFF3F)
    static let pumpkin = Color(hex: 0xFF7A1A)
    static let blood = Color(hex: 0xFF2D55)
    static let ghost = Color(hex: 0xF4F0FF)
    static let candy = Color(hex: 0xFF5FD2)
    static let moon = Color(hex: 0xFFE66D)

    static func title(_ size: CGFloat) -> Font { .system(size: size, weight: .black, design: .rounded) }
    static func body(_ size: CGFloat = 16, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
    /// Kreide-Handschrift für die wilden Akzente.
    static func scribble(_ size: CGFloat) -> Font { .custom("Chalkduster", size: size) }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

// MARK: - Wackel-Effekt

/// Lässt Dinge leicht und dauerhaft herumwackeln, als wären sie lebendig.
struct Wobble: ViewModifier {
    var degrees: Double = 3
    var speed: Double = 2
    var phase: Double = 0

    func body(content: Content) -> some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            content
                .rotationEffect(.degrees(sin(t * speed + phase) * degrees))
                .offset(y: CGFloat(sin(t * speed * 0.7 + phase) * 3))
        }
    }
}

extension View {
    func wobble(_ degrees: Double = 3, speed: Double = 2, phase: Double = 0) -> some View {
        modifier(Wobble(degrees: degrees, speed: speed, phase: phase))
    }

    /// Neon-Glühen in einer Farbe.
    func glow(_ color: Color, radius: CGFloat = 10) -> some View {
        shadow(color: color.opacity(0.8), radius: radius / 2)
            .shadow(color: color.opacity(0.5), radius: radius)
    }
}

// MARK: - Schleim-Knopf

struct SlimeButtonStyle: ButtonStyle {
    var color: Color = Spook.slime
    var textColor: Color = Spook.night

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Spook.title(20))
            .foregroundStyle(textColor)
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(
                SlimeBlob(drips: [0.18, 0.42, 0.77], dripLength: 10)
                    .fill(color)
                    .glow(color, radius: configuration.isPressed ? 4 : 14)
            )
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .rotationEffect(.degrees(configuration.isPressed ? -2 : 0))
            .animation(.spring(response: 0.25, dampingFraction: 0.45), value: configuration.isPressed)
    }
}

/// Abgerundetes Rechteck mit Schleimtropfen an der Unterkante.
struct SlimeBlob: Shape {
    var drips: [CGFloat]
    var dripLength: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path(roundedRect: rect, cornerRadius: min(rect.height / 2, 26), style: .continuous)
        for x in drips {
            let w = max(10, rect.width * 0.05)
            let cx = rect.minX + rect.width * x
            p.addRoundedRect(
                in: CGRect(x: cx - w / 2, y: rect.maxY - w, width: w, height: w + dripLength),
                cornerSize: CGSize(width: w / 2, height: w / 2)
            )
        }
        return p
    }
}

/// Eine Schleimkante, deren Tropfen langsam länger und kürzer werden.
struct DrippingSlime: View {
    var color: Color = Spook.slime
    var height: CGFloat = 28

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                var path = Path(CGRect(x: 0, y: 0, width: size.width, height: height))
                let count = max(6, Int(size.width / 34))
                for i in 0..<count {
                    let seed = Double(i) * 1.73
                    let w = 12 + CGFloat((sin(seed * 3.1) + 1) * 7)
                    let x = size.width * (CGFloat(i) + 0.5) / CGFloat(count) + CGFloat(sin(seed) * 6)
                    let wave = (sin(t * (0.6 + seed.truncatingRemainder(dividingBy: 0.7)) + seed) + 1) / 2
                    let len = height * 0.4 + (size.height - height) * CGFloat(0.25 + 0.75 * wave) * CGFloat((sin(seed * 5) + 1.3) / 2.3)
                    path.addRoundedRect(
                        in: CGRect(x: x - w / 2, y: height - w, width: w, height: len + w),
                        cornerSize: CGSize(width: w / 2, height: w / 2)
                    )
                    // Abtropfender Tropfen
                    let dropPhase = (t * 0.35 + seed).truncatingRemainder(dividingBy: 3)
                    if dropPhase < 1, i % 3 == 0 {
                        let y = height + len + CGFloat(dropPhase) * 40
                        path.addEllipse(in: CGRect(x: x - w * 0.3, y: y, width: w * 0.6, height: w * 0.75))
                    }
                }
                ctx.fill(path, with: .color(color))
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Spuk-Hintergrund

/// Nachthimmel mit Mond, Nebel und herumflatternden Fledermäusen & Geistern.
struct SpookyBackground: View {
    private let critters = ["🦇", "👻", "🦇", "🕷️", "🦇", "👻", "🍬", "🦇"]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                ctx.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .linearGradient(
                        Gradient(colors: [Spook.night, Spook.plum, Spook.night]),
                        startPoint: .zero, endPoint: CGPoint(x: size.width * 0.3, y: size.height)
                    )
                )
                // Mond mit Glühen
                let moon = CGRect(x: size.width - 150, y: 70, width: 110, height: 110)
                ctx.drawLayer { l in
                    l.addFilter(.blur(radius: 40))
                    l.fill(Path(ellipseIn: moon.insetBy(dx: -20, dy: -20)), with: .color(Spook.moon.opacity(0.45)))
                }
                ctx.fill(Path(ellipseIn: moon), with: .color(Spook.moon.opacity(0.9)))
                ctx.fill(Path(ellipseIn: moon.offsetBy(dx: 26, dy: -14)), with: .color(Spook.plum))

                // Sterne
                for i in 0..<40 {
                    let s = Double(i) * 12.9898
                    let x = CGFloat((sin(s) * 43758.5453).truncatingRemainder(dividingBy: 1)).magnitude * size.width
                    let y = CGFloat((cos(s) * 24634.6345).truncatingRemainder(dividingBy: 1)).magnitude * size.height * 0.7
                    let twinkle = (sin(t * 2 + s) + 1) / 2
                    let r = 1 + CGFloat(twinkle) * 1.4
                    ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                             with: .color(.white.opacity(0.25 + twinkle * 0.5)))
                }

                // Fliegende Viecher
                for (i, critter) in critters.enumerated() {
                    let speed = 0.03 + Double(i % 4) * 0.012
                    let progress = (t * speed + Double(i) * 0.37).truncatingRemainder(dividingBy: 1.4) - 0.2
                    let x = size.width * CGFloat(i % 2 == 0 ? progress : 1 - progress)
                    let y = size.height * CGFloat(0.1 + Double(i) * 0.11) + CGFloat(sin(t * 2.5 + Double(i)) * 18)
                    var c = ctx
                    c.opacity = 0.55
                    c.translateBy(x: x, y: y)
                    c.rotate(by: .degrees(sin(t * 6 + Double(i)) * 12))
                    c.draw(Text(critter).font(.system(size: 22 + CGFloat(i % 3) * 8)), at: .zero)
                }

                // Bodennebel
                ctx.drawLayer { l in
                    l.addFilter(.blur(radius: 30))
                    for i in 0..<5 {
                        let x = CGFloat(i) * size.width / 4 + CGFloat(sin(t * 0.3 + Double(i)) * 40)
                        l.fill(Path(ellipseIn: CGRect(x: x - 120, y: size.height - 110, width: 240, height: 120)),
                               with: .color(Spook.violet.opacity(0.22)))
                    }
                }
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Logo

struct FratzenLogo: View {
    var size: CGFloat = 54

    var body: some View {
        VStack(spacing: -size * 0.22) {
            Text("FRATZEN")
                .font(Spook.title(size))
                .foregroundStyle(
                    LinearGradient(colors: [Spook.slime, Color(hex: 0x3FD12A)], startPoint: .top, endPoint: .bottom)
                )
                .glow(Spook.slime, radius: 14)
                .rotationEffect(.degrees(-4))
                .wobble(2, speed: 1.6)
            Text("FABRIK")
                .font(Spook.title(size * 0.92))
                .foregroundStyle(
                    LinearGradient(colors: [Spook.pumpkin, Spook.blood], startPoint: .top, endPoint: .bottom)
                )
                .glow(Spook.pumpkin, radius: 12)
                .rotationEffect(.degrees(3))
                .wobble(2.5, speed: 1.9, phase: 1.3)
        }
        .overlay(alignment: .topTrailing) {
            Text("🎃").font(.system(size: size * 0.6)).offset(x: size * 0.3, y: -size * 0.2).wobble(14, speed: 3)
        }
        .overlay(alignment: .bottomLeading) {
            Text("👻").font(.system(size: size * 0.5)).offset(x: -size * 0.35, y: size * 0.1).wobble(10, speed: 2.4, phase: 2)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Fratzenfabrik")
    }
}
