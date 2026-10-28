import SwiftUI

/// Die beiden Welten der App.
enum World {
    case chooser, halloween, croc

    /// Für Bildschirmfotos: Designs öffnen Halloween, `croc-…` das Krokodilspiel, `start` die Auswahl.
    static var initial: World {
        guard let showcase = UserDefaults.standard.string(forKey: "showcaseDesign") else { return .chooser }
        if showcase == "start" { return .chooser }
        return showcase.hasPrefix("croc-") ? .croc : .halloween
    }
}

struct RootView: View {
    @State private var world = World.initial
    @ObservedObject private var sharePlay = CrocSharePlay.shared

    var body: some View {
        ZStack {
            switch world {
            case .chooser:
                WorldChooserView { picked in
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { world = picked }
                }
                .transition(.opacity)
            case .halloween:
                HomeView(onExit: { withAnimation { world = .chooser } })
                    .transition(.move(edge: .top).combined(with: .opacity))
            case .croc:
                CrocHomeView(onExit: { withAnimation { world = .chooser } })
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        // Startet jemand im FaceTime-Anruf das Krokodilspiel, landet man direkt dort.
        .task { await sharePlay.observeSessions() }
        .onChange(of: sharePlay.session != nil) { _, active in
            if active { withAnimation { world = .croc } }
        }
    }
}

/// Startbildschirm: oben Halloween, unten das Krokodilspiel.
struct WorldChooserView: View {
    var pick: (World) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button { pick(.halloween) } label: {
                ZStack {
                    SpookyBackground()
                    VStack(spacing: 10) {
                        FratzenLogo(size: 44)
                        Text("🎃 Halloween-Schminke 👻")
                            .font(Spook.title(20))
                            .foregroundStyle(Spook.ghost)
                        Text("Gruselfratzen nachmalen & live anprobieren")
                            .font(Spook.body(14, weight: .bold))
                            .foregroundStyle(.white.opacity(0.75))
                        startLabel(color: Spook.slime, text: Spook.night)
                    }
                    .padding(.top, 30)
                }
                .clipped()
            }
            .buttonStyle(PressableStyle())

            Button { pick(.croc) } label: {
                ZStack {
                    CrocBackground()
                    VStack(spacing: 10) {
                        CrocLogo(size: 40)
                        Text("🦄 🐴 🐬 🐋")
                            .font(.system(size: 30))
                        Text("Schnapp-Spiel für zwei – wer ist schneller?")
                            .font(Spook.body(14, weight: .bold))
                            .foregroundStyle(Kroko.blush)
                        startLabel(color: Kroko.gold, text: Kroko.night)
                    }
                    .padding(.bottom, 10)
                }
                .clipped()
            }
            .buttonStyle(PressableStyle())
        }
        .overlay {
            Text("Was spielen wir?")
                .font(Spook.title(22))
                .foregroundStyle(Spook.night)
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(Capsule().fill(.white))
                .shadow(color: .black.opacity(0.4), radius: 8)
                .rotationEffect(.degrees(-3))
                .wobble(2, speed: 2)
                .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }

    private func startLabel(color: Color, text: Color) -> some View {
        Label("Los geht's", systemImage: "play.fill")
            .font(Spook.title(18))
            .foregroundStyle(text)
            .padding(.horizontal, 22)
            .padding(.vertical, 10)
            .background(Capsule().fill(color))
            .glow(color, radius: 10)
    }
}

/// Runder Knopf oben links zurück zur Weltenauswahl (oder zum Schließen).
struct WorldBackButton: View {
    var color: Color
    var systemName = "square.grid.2x2.fill"
    var size: CGFloat = 44
    var inset = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size * 0.4, weight: .black))
                .foregroundStyle(color)
                .frame(width: size, height: size)
                .background(Circle().fill(.black.opacity(0.45)))
                .overlay(Circle().stroke(color.opacity(0.6), lineWidth: 2))
        }
        .buttonStyle(PressableStyle())
        .padding(.leading, inset ? 16 : 0)
        .padding(.top, inset ? 4 : 0)
        .accessibilityLabel("Zurück")
    }
}
