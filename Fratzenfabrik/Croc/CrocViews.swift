import GroupActivities
import SwiftUI

/// Rosa-roter Hintergrund mit Goldglitzer, Herzchen und Blubberblasen.
struct CrocBackground: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
                    Gradient(colors: [Color(hex: 0xC2185B), Kroko.wine, Kroko.night]),
                    startPoint: .zero, endPoint: CGPoint(x: size.width * 0.4, y: size.height)))
                ctx.drawLayer { l in
                    l.addFilter(.blur(radius: 60))
                    l.fill(Path(ellipseIn: CGRect(x: -80, y: size.height * 0.1, width: 260, height: 260)), with: .color(Kroko.rose.opacity(0.35)))
                    l.fill(Path(ellipseIn: CGRect(x: size.width - 180, y: size.height * 0.55, width: 280, height: 280)), with: .color(Kroko.gold.opacity(0.25)))
                }
                for i in 0..<34 {
                    let s = Double(i) * 7.31
                    let x = CGFloat((sin(s) * 43758.5453).truncatingRemainder(dividingBy: 1)).magnitude * size.width
                    let speed = 0.02 + Double(i % 5) * 0.008
                    let y = size.height * CGFloat(1.1 - (t * speed + s * 0.13).truncatingRemainder(dividingBy: 1.2))
                    let wiggle = CGFloat(sin(t * 1.6 + s) * 12)
                    var c = ctx
                    c.opacity = 0.35 + 0.3 * (sin(t * 2 + s) + 1) / 2
                    let glyph = ["✨", "💖", "🫧", "✨", "💛"][i % 5]
                    c.draw(Text(glyph).font(.system(size: 12 + CGFloat(i % 4) * 5)), at: CGPoint(x: x + wiggle, y: y))
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

/// Großer goldener Schriftzug „Krokodilspiel“.
struct CrocLogo: View {
    var size: CGFloat = 46

    var body: some View {
        VStack(spacing: -size * 0.15) {
            Text("🐊").font(.system(size: size * 1.4))
                // Goldenes statt grünes Krokodil
                .hueRotation(.degrees(-75)).saturation(1.4)
                .wobble(6, speed: 3)
            Text("KROKODIL")
                .font(Spook.title(size))
                .foregroundStyle(LinearGradient(colors: [Color(hex: 0xFFF0A8), Kroko.gold, Kroko.deepGold], startPoint: .top, endPoint: .bottom))
                .shadow(color: Kroko.red, radius: 0, x: 3, y: 3)
            Text("SPIEL")
                .font(Spook.title(size * 0.8))
                .foregroundStyle(Kroko.rose)
                .shadow(color: Kroko.red, radius: 0, x: 3, y: 3)
                .rotationEffect(.degrees(-4))
        }
    }
}

/// Startseite der Krokodil-Welt: Tier wählen, dann mit zwei Handys oder an einem Handy spielen.
struct CrocHomeView: View {
    var onExit: () -> Void

    @AppStorage("crocAnimal") private var animalRaw = CrocAnimal.unicorn.rawValue
    @State private var online = false
    @State private var choosingSecond = false
    @State private var local: CrocLocalGame?
    @ObservedObject private var sharePlay = CrocSharePlay.shared

    private var animal: CrocAnimal { CrocAnimal(rawValue: animalRaw) ?? .unicorn }

    var body: some View {
        ZStack(alignment: .topLeading) {
            CrocBackground()
            ScrollView {
                VStack(spacing: 22) {
                    CrocLogo().padding(.top, 50)

                    Text("Wer ist schneller – das Krokodil\noder dein Tier?")
                        .font(Spook.body(17, weight: .heavy))
                        .foregroundStyle(Kroko.blush)
                        .multilineTextAlignment(.center)

                    sectionTitle("Wähle dein Tier")
                    AnimalGrid(selected: animal) { animalRaw = $0.rawValue }

                    Button {
                        online = true
                    } label: {
                        HStack(spacing: 10) {
                            Text("📞").font(.system(size: 26))
                            VStack(alignment: .leading, spacing: 0) {
                                Text("Per FaceTime spielen")
                                Text("sehen & hören beim Schnappen – egal wo ihr seid").font(Spook.body(12, weight: .heavy)).opacity(0.7)
                            }
                        }
                    }
                    .buttonStyle(SlimeButtonStyle(color: Kroko.gold, textColor: Kroko.night))
                    .wobble(1, speed: 1.8)

                    Button {
                        choosingSecond = true
                    } label: {
                        HStack(spacing: 10) {
                            Text("📱").font(.system(size: 26))
                            VStack(alignment: .leading, spacing: 0) {
                                Text("Zu zweit an einem Handy")
                                Text("Handy flach zwischen euch legen").font(Spook.body(12, weight: .heavy)).opacity(0.7)
                            }
                        }
                    }
                    .buttonStyle(SlimeButtonStyle(color: Kroko.rose, textColor: Kroko.night))

                    CrocRulesCard()
                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 18)
            }
            .scrollIndicators(.hidden)

            WorldBackButton(color: Kroko.gold, action: onExit)
        }
        .fullScreenCover(isPresented: $online) {
            CrocOnlineView(animal: animal)
        }
        .sheet(isPresented: $choosingSecond) {
            SecondPlayerPicker(first: animal) { second in
                choosingSecond = false
                local = CrocLocalGame(bottom: animal, top: second)
            }
            .presentationDetents([.medium])
        }
        .fullScreenCover(item: $local) { game in
            CrocLocalView(game: game)
        }
        // Kommt ein Spiel aus FaceTime an, direkt hinein.
        .onChange(of: sharePlay.session != nil) { _, active in
            if active { local = nil; online = true }
        }
        .onAppear {
            if sharePlay.session != nil { online = true }
            if let showcase = CrocShowcase.screen, showcase != "home" {
                local = CrocLocalGame(bottom: .dolphin, top: .unicorn, demoArmed: showcase == "armed")
            }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(Spook.title(22))
            .foregroundStyle(Kroko.gold)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AnimalGrid: View {
    var selected: CrocAnimal?
    var disabled: CrocAnimal? = nil
    var pick: (CrocAnimal) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(Array(CrocAnimal.allCases.enumerated()), id: \.element) { index, animal in
                let isOn = animal == selected
                Button { pick(animal) } label: {
                    VStack(spacing: 4) {
                        Text(animal.emoji).font(.system(size: 54))
                            .scaleEffect(isOn ? 1.12 : 1)
                        Text(animal.name).font(Spook.title(18))
                            .foregroundStyle(isOn ? Kroko.night : .white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(isOn ? animal.color : Color.white.opacity(0.1)))
                    .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(animal.color.opacity(isOn ? 0 : 0.6), lineWidth: 2))
                    .glow(isOn ? animal.color : .clear, radius: 10)
                    .rotationEffect(.degrees(index.isMultiple(of: 2) ? -2 : 2))
                }
                .buttonStyle(PressableStyle())
                .disabled(animal == disabled)
                .opacity(animal == disabled ? 0.35 : 1)
                .sensoryFeedback(.selection, trigger: isOn)
            }
        }
    }
}

struct SecondPlayerPicker: View {
    let first: CrocAnimal
    let start: (CrocAnimal) -> Void

    var body: some View {
        ZStack {
            Kroko.wine.ignoresSafeArea()
            VStack(spacing: 16) {
                Text("Welches Tier ist Spieler 2?")
                    .font(Spook.title(22))
                    .foregroundStyle(Kroko.gold)
                    .padding(.top, 22)
                AnimalGrid(selected: nil, disabled: first, pick: start)
            }
            .padding(.horizontal, 18)
        }
    }
}

struct CrocRulesCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("So geht's 🐊")
                .font(Spook.title(20))
                .foregroundStyle(Kroko.gold)
            rule("👆", "Das Tier legt den Finger auf den Kreis im Maul und hält ihn fest.")
            rule("😜", "Das Krokodil darf zucken, um zu tricksen – wer dabei loslässt, verliert die Runde.")
            rule("🐊", "Schnappt das Krokodil zu, schnell den Finger weg! Zu langsam = geschnappt.")
            rule("🔄", "Nach jeder Runde wird getauscht. Wer zuerst \(CrocMatch.winningScore) Punkte hat, gewinnt!")
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Kroko.night.opacity(0.6)))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(Kroko.rose.opacity(0.5), lineWidth: 2))
    }

    private func rule(_ emoji: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(emoji).font(.system(size: 22))
            Text(text).font(Spook.body(15, weight: .semibold)).foregroundStyle(.white.opacity(0.9))
        }
    }
}

// MARK: - Zwei Handys per FaceTime + SharePlay

struct CrocOnlineView: View {
    let animal: CrocAnimal
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var link = CrocSharePlay.shared
    @StateObject private var groupState = GroupStateObserver()
    @State private var match: CrocMatch?

    var body: some View {
        ZStack {
            CrocBackground()
            if let match {
                CrocGameScreen(match: match) { close() }
            } else {
                lobby
            }
        }
        .onAppear(perform: startMatchIfReady)
        .onChange(of: link.peerAnimal) { _, _ in startMatchIfReady() }
    }

    private func startMatchIfReady() {
        guard match == nil, let opponent = link.peerAnimal else { return }
        match = CrocMatch(me: animal, opponent: opponent, isHost: link.isHost, transport: link)
    }

    private func close() {
        match?.leave()
        link.leave()
        dismiss()
    }

    private var lobby: some View {
        VStack(spacing: 18) {
            HStack {
                WorldBackButton(color: Kroko.gold, systemName: "xmark") { close() }
                Spacer()
            }
            Spacer(minLength: 0)
            if link.session != nil {
                SearchRadar(animal: animal)
                title("Warte auf deinen\nMitspieler …")
                note("Auf dem anderen Handy erscheint oben „SharePlay“ – dort auf „Öffnen“ bzw. „Beitreten“ tippen.")
            } else {
                Text("📞🐊").font(.system(size: 64))
                title("Spielen im\nFaceTime-Anruf")
                VStack(alignment: .leading, spacing: 12) {
                    step("1", "Ruft euch per FaceTime-Video an.", done: groupState.isEligibleForGroupSession)
                    step("2", "Hier auf „SharePlay starten“ tippen.", done: false)
                    step("3", "Auf dem anderen Handy „Öffnen“ tippen – fertig! Ihr seht und hört euch beim Spielen.", done: false)
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Kroko.night.opacity(0.6)))
                if let problem = link.problem {
                    note(problem)
                }
                Button {
                    Task { await link.start() }
                } label: {
                    Label(groupState.isEligibleForGroupSession ? "SharePlay starten" : "Freund einladen",
                          systemImage: "shareplay")
                }
                .buttonStyle(SlimeButtonStyle(color: Kroko.gold, textColor: Kroko.night))
                if !groupState.isEligibleForGroupSession {
                    note("Noch kein FaceTime-Anruf aktiv – starte zuerst den Videoanruf, dann ist der Knopf bereit.")
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 22)
    }

    private func step(_ number: String, _ text: String, done: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(done ? "✓" : number)
                .font(Spook.title(16))
                .foregroundStyle(Kroko.night)
                .frame(width: 28, height: 28)
                .background(Circle().fill(done ? Kroko.gold : Kroko.rose))
            Text(text).font(Spook.body(15, weight: .semibold)).foregroundStyle(.white.opacity(0.9))
        }
    }

    private func title(_ text: String) -> some View {
        Text(text)
            .font(Spook.title(26))
            .foregroundStyle(Kroko.gold)
            .multilineTextAlignment(.center)
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(Spook.body(15, weight: .semibold))
            .foregroundStyle(.white.opacity(0.9))
            .multilineTextAlignment(.center)
    }
}

/// Wellen, die vom eigenen Tier ausgehen, während das andere Handy gesucht wird.
struct SearchRadar: View {
    let animal: CrocAnimal

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(0..<3) { i in
                    let p = (t * 0.6 + Double(i) / 3).truncatingRemainder(dividingBy: 1)
                    Circle()
                        .stroke(i % 2 == 0 ? Kroko.gold : Kroko.rose, lineWidth: 4)
                        .frame(width: 90 + 170 * p, height: 90 + 170 * p)
                        .opacity(1 - p)
                }
                Text(animal.emoji)
                    .font(.system(size: 80))
                    .offset(y: sin(t * 3) * 6)
            }
            .frame(width: 270, height: 270)
        }
    }
}

/// Vollbild-Spiel auf einem Handy (zwei Handys verbunden).
struct CrocGameScreen: View {
    @ObservedObject var match: CrocMatch
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                WorldBackButton(color: Kroko.gold, systemName: "xmark", action: onClose)
                Spacer()
                SoundToggle(size: 40)
            }
            CrocPlayerPanel(match: match)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .overlay {
            if match.disconnected {
                VStack(spacing: 14) {
                    Text("📡").font(.system(size: 60))
                    Text("Verbindung weg").font(Spook.title(28)).foregroundStyle(Kroko.gold)
                    Text("Das andere Handy ist nicht mehr da.").font(Spook.body(15)).foregroundStyle(.white)
                    Button("Zurück", action: onClose)
                        .buttonStyle(SlimeButtonStyle(color: Kroko.gold, textColor: Kroko.night))
                        .frame(maxWidth: 220)
                }
                .padding(28)
                .background(RoundedRectangle(cornerRadius: 30, style: .continuous).fill(Kroko.night.opacity(0.95)))
            }
        }
        .persistentSystemOverlays(.hidden)
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }
}

// MARK: - Ein Handy, zwei Spieler

struct CrocLocalGame: Identifiable {
    let id = UUID()
    let bottomMatch: CrocMatch
    let topMatch: CrocMatch

    @MainActor
    init(bottom: CrocAnimal, top: CrocAnimal, demoArmed: Bool = false) {
        let (a, b) = LocalCrocTransport.pair()
        bottomMatch = CrocMatch(me: bottom, opponent: top, isHost: false, transport: a)
        topMatch = CrocMatch(me: top, opponent: bottom, isHost: true, transport: b)
        if demoArmed {
            bottomMatch.patient = true
            topMatch.patient = true
            let prey = bottomMatch
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { MainActor.assumeIsolated { prey.preyTouchDown() } }
        }
    }
}

struct CrocLocalView: View {
    let game: CrocLocalGame
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            CrocBackground()
            VStack(spacing: 0) {
                CrocPlayerPanel(match: game.topMatch, compact: true)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .rotationEffect(.degrees(180))
                HStack {
                    Rectangle().fill(Kroko.gold.opacity(0.6)).frame(height: 2)
                    WorldBackButton(color: Kroko.gold, systemName: "xmark", size: 36, inset: false) { dismiss() }
                    Rectangle().fill(Kroko.gold.opacity(0.6)).frame(height: 2)
                }
                .padding(.horizontal, 12)
                CrocPlayerPanel(match: game.bottomMatch, compact: true)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }
        }
        .persistentSystemOverlays(.hidden)
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }
}

enum CrocShowcase {
    /// Für Bildschirmfotos: `-showcaseDesign croc-home|croc-local|croc-armed`.
    static var screen: String? {
        guard let value = UserDefaults.standard.string(forKey: "showcaseDesign"), value.hasPrefix("croc-") else { return nil }
        return String(value.dropFirst(5))
    }
}
