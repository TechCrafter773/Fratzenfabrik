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
                            Text("📱📱").font(.system(size: 26))
                            VStack(alignment: .leading, spacing: 0) {
                                Text("Mit zwei Handys")
                                Text("übers Internet – egal wo ihr seid").font(Spook.body(12, weight: .heavy)).opacity(0.7)
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
        .onAppear {
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

// MARK: - Zwei Handys übers Internet

struct CrocOnlineView: View {
    let animal: CrocAnimal
    @Environment(\.dismiss) private var dismiss
    @StateObject private var link: CrocLink
    @ObservedObject private var auth = GameCenterAuth.shared
    @AppStorage("crocCode") private var code = ""
    @State private var match: CrocMatch?

    init(animal: CrocAnimal) {
        self.animal = animal
        _link = StateObject(wrappedValue: CrocLink(animal: animal))
    }

    var body: some View {
        ZStack {
            CrocBackground()
            if let match {
                CrocGameScreen(match: match) { close() }
            } else {
                lobby
            }
        }
        .onAppear { auth.signIn() }
        .onDisappear { link.stop() }
        .onChange(of: link.peerAnimal) { _, opponent in
            guard match == nil, let opponent else { return }
            match = CrocMatch(me: animal, opponent: opponent, isHost: link.isHost, transport: link)
        }
    }

    private func close() {
        match?.leave()
        link.stop()
        dismiss()
    }

    private var lobby: some View {
        VStack(spacing: 18) {
            HStack {
                WorldBackButton(color: Kroko.gold, systemName: "xmark") { close() }
                Spacer()
            }
            Spacer(minLength: 0)
            switch auth.state {
            case .signedIn:
                switch link.state {
                case .searching(let searching):
                    SearchRadar(animal: animal)
                    title("Suche Mitspieler\nmit Code \(String(format: "%04d", searching)) …")
                    note("Auf dem anderen Handy denselben Code eingeben. Die Handys können überall sein – Hauptsache Internet.")
                    Button("Abbrechen") { link.stop() }
                        .buttonStyle(SlimeButtonStyle(color: Kroko.rose, textColor: Kroko.night))
                        .frame(maxWidth: 240)
                case .connected:
                    SearchRadar(animal: animal)
                    title("Verbunden mit\n\(link.peerName ?? "deinem Mitspieler")! 🎉")
                case .idle, .failed:
                    codeEntry
                }
            case .failed(let message):
                Text("🎮").font(.system(size: 70))
                title("Game Center fehlt")
                note("Fürs Spielen übers Internet bitte in den Einstellungen → Game Center anmelden.\n\n\(message)")
                Button("Nochmal versuchen") { auth.signIn() }
                    .buttonStyle(SlimeButtonStyle(color: Kroko.gold, textColor: Kroko.night))
                    .frame(maxWidth: 260)
            case .unknown, .signingIn:
                ProgressView().tint(Kroko.gold).scaleEffect(1.6)
                title("Melde bei Game Center an …")
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 22)
    }

    private var codeEntry: some View {
        VStack(spacing: 16) {
            title("Spielcode")
            note("Denkt euch zusammen einen Code aus und tippt ihn auf beiden Handys ein.")
            HStack(spacing: 10) {
                ForEach(0..<4, id: \.self) { i in
                    let digits = Array(code)
                    Text(i < digits.count ? String(digits[i]) : " ")
                        .font(Spook.title(40))
                        .foregroundStyle(Kroko.night)
                        .frame(width: 62, height: 76)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(i < digits.count ? Kroko.gold : Color.white.opacity(0.15)))
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Kroko.gold, lineWidth: i == digits.count ? 3 : 0))
                }
            }
            if case .failed(let message) = link.state {
                note("Hoppla: \(message)")
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(["1", "2", "3", "4", "5", "6", "7", "8", "9", "🎲", "0", "⌫"], id: \.self) { key in
                    Button {
                        tap(key)
                    } label: {
                        Text(key)
                            .font(Spook.title(26))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.12)))
                    }
                    .buttonStyle(PressableStyle())
                }
            }
            Button {
                if let number = Int(code) { link.search(code: number) }
            } label: {
                Label("Mitspieler suchen", systemImage: "globe")
            }
            .buttonStyle(SlimeButtonStyle(color: Kroko.gold, textColor: Kroko.night))
            .disabled(code.count != 4)
            .opacity(code.count == 4 ? 1 : 0.5)
        }
    }

    private func tap(_ key: String) {
        switch key {
        case "⌫": if !code.isEmpty { code.removeLast() }
        case "🎲": code = String(format: "%04d", Int.random(in: 0...9999))
        default: if code.count < 4 { code += key }
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
