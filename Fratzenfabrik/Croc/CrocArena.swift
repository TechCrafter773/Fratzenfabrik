import SwiftUI

/// Das goldene Krokodil-Maul. `close` geht von 0 (weit offen) bis 1 (zu).
struct CrocJaws: View {
    var close: Double
    var animal: CrocAnimal
    /// 0…1: das Tier springt nach oben weg.
    var escape: Double = 0
    var showAnimal = true

    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            let maxGap = h * 0.5
            let shut = CGFloat(min(max(close, 0), 1))
            let gap = maxGap * (1 - shut)
            let mid = h * 0.52
            let upper = mid - gap / 2
            let lower = mid + gap / 2

            // Maul innen und Zunge
            let mouth = CGRect(x: w * 0.08, y: mid - maxGap / 2 - 20, width: w * 0.84, height: maxGap + 40)
            ctx.fill(Path(roundedRect: mouth, cornerRadius: 50), with: .color(Color(hex: 0x7A0F2B)))
            let tongue = CGRect(x: w * 0.24, y: mid + maxGap * 0.1, width: w * 0.52, height: maxGap * 0.42)
            ctx.fill(Path(ellipseIn: tongue), with: .color(Kroko.rose))
            ctx.stroke(Path { p in
                p.move(to: CGPoint(x: w / 2, y: tongue.minY + 10)); p.addLine(to: CGPoint(x: w / 2, y: tongue.midY + 8))
            }, with: .color(Color(hex: 0xE0609A)), style: StrokeStyle(lineWidth: 4, lineCap: .round))

            // Das Tier sitzt auf der Zunge
            if showAnimal {
                let emojiSize = min(w * 0.36, maxGap * 0.72)
                let e = CGFloat(escape)
                let y = mid - e * h * 0.62 - sin(e * .pi) * 20
                var c = ctx
                c.translateBy(x: w / 2 + e * w * 0.18, y: y)
                c.rotate(by: .degrees(escape * 40))
                c.draw(Text(animal.emoji).font(.system(size: emojiSize)), at: .zero)
            }

            let gold = GraphicsContext.Shading.linearGradient(
                Gradient(colors: [Color(hex: 0xFFE07A), Kroko.gold, Kroko.deepGold]),
                startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: w, y: h))
            let tooth = Kroko.cream
            let teeth = 8
            let tw = (w - 110) / CGFloat(teeth) / 2

            // Oberkiefer
            let upperRect = CGRect(x: 10, y: -80, width: w - 20, height: upper + 80)
            ctx.fill(Path(roundedRect: upperRect, cornerRadius: 60), with: gold)
            for i in 0..<teeth {
                let x = 55 + tw + CGFloat(i) * tw * 2
                var t = Path()
                t.move(to: CGPoint(x: x - tw * 0.85, y: upper - 6))
                t.addLine(to: CGPoint(x: x + tw * 0.85, y: upper - 6))
                t.addLine(to: CGPoint(x: x, y: upper + 30))
                t.closeSubpath()
                ctx.fill(t, with: .color(tooth))
            }
            // Schuppen, Nasenlöcher, Augen, Bäckchen
            for i in 0..<5 {
                let x = w * (0.18 + CGFloat(i) * 0.16)
                ctx.fill(Path(ellipseIn: CGRect(x: x - 16, y: upper - 70 - CGFloat(i % 2) * 14, width: 32, height: 20)),
                         with: .color(Kroko.deepGold.opacity(0.55)))
            }
            for dx: CGFloat in [-26, 26] {
                ctx.fill(Path(ellipseIn: CGRect(x: w / 2 + dx - 9, y: upper - 34, width: 18, height: 11)),
                         with: .color(Color(hex: 0x7A4A00)))
            }
            let eyeR = min(w, h) * 0.075
            for ex in [w * 0.27, w * 0.73] {
                let ey = upper - h * 0.17
                ctx.fill(Path(ellipseIn: CGRect(x: ex - eyeR * 1.35, y: ey - eyeR * 1.35, width: eyeR * 2.7, height: eyeR * 2.7)), with: gold)
                ctx.fill(Path(ellipseIn: CGRect(x: ex - eyeR, y: ey - eyeR, width: eyeR * 2, height: eyeR * 2)), with: .color(.white))
                let slit = eyeR * (0.6 + 0.3 * shut)
                ctx.fill(Path(roundedRect: CGRect(x: ex - slit / 2, y: ey - eyeR * 0.8, width: slit, height: eyeR * 1.6),
                              cornerRadius: slit / 2), with: .color(Color(hex: 0x2A1200)))
                ctx.fill(Path(ellipseIn: CGRect(x: ex - eyeR * 0.15, y: ey - eyeR * 0.6, width: eyeR * 0.35, height: eyeR * 0.35)),
                         with: .color(.white))
                ctx.fill(Path(ellipseIn: CGRect(x: ex - eyeR * 0.9, y: ey + eyeR * 1.3, width: eyeR * 1.8, height: eyeR * 0.8)),
                         with: .color(Kroko.rose.opacity(0.75)))
            }

            // Unterkiefer
            let lowerRect = CGRect(x: 10, y: lower, width: w - 20, height: h - lower + 80)
            for i in 0..<teeth {
                let x = 55 + CGFloat(i) * tw * 2 + tw * 2
                guard x < w - 50 else { continue }
                var t = Path()
                t.move(to: CGPoint(x: x - tw * 0.85, y: lower + 6))
                t.addLine(to: CGPoint(x: x + tw * 0.85, y: lower + 6))
                t.addLine(to: CGPoint(x: x, y: lower - 28))
                t.closeSubpath()
                ctx.fill(t, with: .color(tooth))
            }
            ctx.fill(Path(roundedRect: lowerRect, cornerRadius: 60), with: gold)
            for i in 0..<4 {
                let x = w * (0.26 + CGFloat(i) * 0.16)
                ctx.fill(Path(ellipseIn: CGRect(x: x - 14, y: lower + 40 + CGFloat(i % 2) * 12, width: 28, height: 16)),
                         with: .color(Kroko.deepGold.opacity(0.5)))
            }
        }
    }
}

/// Das Spielfeld eines Spielers: Maul, Tier, Punkte und die passenden Knöpfe.
struct CrocPlayerPanel: View {
    @ObservedObject var match: CrocMatch
    var compact = false

    var body: some View {
        VStack(spacing: compact ? 6 : 14) {
            scoreBar
            roleBanner
            arena
            controls
        }
        .overlay { resultOverlay }
        .overlay { overOverlay }
    }

    // MARK: Punkte

    private var scoreBar: some View {
        HStack {
            scoreChip(emoji: match.me.emoji, label: "Du", score: match.myScore, color: Kroko.gold)
            Spacer()
            Text("bis \(CrocMatch.winningScore)")
                .font(Spook.body(12, weight: .heavy))
                .foregroundStyle(Kroko.blush.opacity(0.7))
            Spacer()
            scoreChip(emoji: match.opponent.emoji, label: match.opponent.name, score: match.theirScore, color: Kroko.rose)
        }
    }

    private func scoreChip(emoji: String, label: String, score: Int, color: Color) -> some View {
        HStack(spacing: 6) {
            Text(emoji).font(.system(size: compact ? 22 : 28))
            Text(label).font(Spook.body(compact ? 12 : 14, weight: .heavy)).lineLimit(1)
            Text("\(score)")
                .font(Spook.title(compact ? 20 : 26))
                .contentTransition(.numericText())
                .animation(.spring, value: score)
        }
        .foregroundStyle(Kroko.night)
        .padding(.horizontal, 12)
        .padding(.vertical, compact ? 4 : 6)
        .background(Capsule().fill(color))
    }

    private var roleBanner: some View {
        Group {
            if match.role == .croc {
                Text("Du bist das Krokodil 🐊")
            } else {
                Text("Du bist \(match.me.withArticle) \(match.me.emoji)")
            }
        }
        .font(Spook.title(compact ? 18 : 24))
        .foregroundStyle(Kroko.gold)
        .shadow(color: Kroko.red.opacity(0.8), radius: 0, x: 2, y: 2)
    }

    // MARK: Maul

    private var arena: some View {
        TimelineView(.animation) { timeline in
            let now = timeline.date
            CrocJaws(close: closeAmount(at: now), animal: match.preyAnimal,
                     escape: escapeAmount(at: now), showAnimal: match.lastReason != .caught || !isResult)
                .overlay { if match.role == .prey { holdPad(now: now) } }
        }
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 34, style: .continuous).stroke(Kroko.gold.opacity(0.7), lineWidth: 3))
        .frame(maxHeight: .infinity)
    }

    private var isResult: Bool {
        if case .result = match.phase { return true }
        return match.phase == .over
    }

    private func closeAmount(at now: Date) -> Double {
        let t = now.timeIntervalSinceReferenceDate
        var twitch = 0.0
        if let at = match.twitchAt {
            let dt = now.timeIntervalSince(at)
            if dt >= 0, dt < 0.4 { twitch = 0.38 * sin(.pi * dt / 0.4) }
        }
        switch match.phase {
        case .waiting:
            return 0.04 + 0.03 * sin(t * 1.4)
        case .armed:
            return 0.06 + 0.04 * sin(t * 2.2) + twitch
        case .snapping(let since, let window):
            let p = min(1, now.timeIntervalSince(since) / window)
            return 0.06 + 0.94 * p * p
        case .result(let reason):
            switch reason {
            case .caught, .escaped: return 1
            case .early: return 0.25 + 0.05 * sin(t * 8)
            case .slow: return 0.02
            }
        case .over:
            return 0.3 + 0.1 * sin(t * 3)
        }
    }

    private func escapeAmount(at now: Date) -> Double {
        guard case .result(let reason) = match.phase, reason == .escaped || reason == .early else { return 0 }
        return reason == .escaped ? 1 : 0.15
    }

    private func holdPad(now: Date) -> some View {
        let t = now.timeIntervalSinceReferenceDate
        let waiting = match.phase == .waiting
        return GeometryReader { geo in
            let d = min(geo.size.width * 0.52, geo.size.height * 0.5, 190)
            ZStack {
                Circle()
                    .stroke(Kroko.gold, style: StrokeStyle(lineWidth: 5, dash: waiting ? [12, 9] : []))
                    .frame(width: d, height: d)
                    .scaleEffect(waiting ? 1 + 0.06 * sin(t * 4) : 1)
                    .opacity(isResult ? 0 : 1)
                if waiting {
                    Text("Finger drauf! 👆")
                        .font(Spook.title(compact ? 14 : 17))
                        .foregroundStyle(Kroko.night)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Capsule().fill(Kroko.gold))
                        .offset(y: d / 2 + 4)
                }
            }
            .frame(width: d, height: d)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in match.preyTouchDown() }
                    .onEnded { _ in match.preyLift() }
            )
            .position(x: geo.size.width / 2, y: geo.size.height * 0.52)
        }
    }

    // MARK: Knöpfe

    @ViewBuilder
    private var controls: some View {
        let armed: Bool = { if case .armed = match.phase { return true }; return false }()
        if match.role == .croc {
            VStack(spacing: compact ? 6 : 10) {
                patienceBar
                HStack(spacing: 12) {
                    TouchDownButton(color: Kroko.rose, enabled: armed, height: compact ? 54 : 70) {
                        match.crocTwitch()
                    } label: {
                        VStack(spacing: 0) {
                            Text("😜").font(.system(size: compact ? 20 : 26))
                            Text("Zucken").font(Spook.title(compact ? 14 : 17))
                        }
                    }
                    .frame(maxWidth: 120)
                    TouchDownButton(color: Kroko.red, textColor: .white, enabled: armed, height: compact ? 54 : 70) {
                        match.crocSnap()
                    } label: {
                        Text("SCHNAPP! 🐊").font(Spook.title(compact ? 22 : 28))
                    }
                }
                Text(armed ? "Trick: erst ein paar Mal zucken – dann zuschnappen!"
                     : "Warte, bis \(match.opponent.withArticle) den Finger draufhat …")
                    .font(Spook.body(compact ? 11 : 13, weight: .bold))
                    .foregroundStyle(Kroko.blush.opacity(0.85))
            }
        } else {
            Text(preyHint)
                .font(Spook.title(compact ? 16 : 20))
                .foregroundStyle(Kroko.blush)
                .multilineTextAlignment(.center)
                .frame(height: compact ? 54 : 90)
        }
    }

    private var preyHint: String {
        switch match.phase {
        case .waiting: "Leg deinen Finger auf \(match.me.emoji) und halt ihn fest!"
        case .armed: "Pass auf … nicht zucken! 👀\nWenn es schnappt: Finger weg!"
        case .snapping: "WEG!!! 💨"
        default: " "
        }
    }

    private var patienceBar: some View {
        TimelineView(.animation(minimumInterval: 1 / 20)) { timeline in
            let left: Double = {
                guard case .armed(let since) = match.phase else { return 0 }
                return max(0, 1 - timeline.date.timeIntervalSince(since) / CrocMatch.crocPatience)
            }()
            GeometryReader { geo in
                Capsule().fill(Color.white.opacity(0.15))
                    .overlay(alignment: .leading) {
                        Capsule().fill(left < 0.3 ? Kroko.red : Kroko.gold).frame(width: geo.size.width * left)
                    }
            }
            .frame(height: 8)
        }
    }

    // MARK: Ergebnis

    @ViewBuilder
    private var resultOverlay: some View {
        if case .result(let reason) = match.phase {
            let iWin = (match.role == .croc) == reason.crocWins
            VStack(spacing: 6) {
                Text(resultTitle(reason))
                    .font(Spook.title(compact ? 30 : 42))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Kroko.gold)
                Text(iWin ? "+1 für dich! ⭐️" : "+1 für \(match.opponent.emoji) \(match.opponent.name)")
                    .font(Spook.title(compact ? 16 : 20))
                    .foregroundStyle(.white)
                Text("Gleich wird getauscht 🔄")
                    .font(Spook.body(compact ? 12 : 14, weight: .bold))
                    .foregroundStyle(Kroko.blush.opacity(0.8))
            }
            .padding(compact ? 14 : 22)
            .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Kroko.night.opacity(0.88)))
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(iWin ? Kroko.gold : Kroko.rose, lineWidth: 3))
            .rotationEffect(.degrees(-3))
            .transition(.scale.combined(with: .opacity))
            .allowsHitTesting(false)
        }
    }

    private func resultTitle(_ reason: CrocRoundReason) -> String {
        let croc = match.role == .croc
        switch reason {
        case .caught: return croc ? "Geschnappt! 🐊" : "Erwischt! 😱"
        case .escaped: return croc ? "Daneben! 💨" : "Entwischt! 💨"
        case .early: return croc ? "Reingelegt! 😜" : "Zu früh gezuckt! 😜"
        case .slow: return croc ? "Zu langsam! 🐢" : "Das Krokodil hat\nsich nicht getraut! 🐢"
        }
    }

    @ViewBuilder
    private var overOverlay: some View {
        if match.phase == .over {
            VStack(spacing: compact ? 10 : 16) {
                Text(match.iWonMatch ? "🏆" : match.opponent.emoji).font(.system(size: compact ? 60 : 90))
                Text(match.iWonMatch ? "Du hast gewonnen!" : "\(match.opponent.name) hat gewonnen!")
                    .font(Spook.title(compact ? 26 : 34))
                    .foregroundStyle(Kroko.gold)
                    .multilineTextAlignment(.center)
                Text("\(match.myScore) : \(match.theirScore)")
                    .font(Spook.title(compact ? 20 : 26))
                    .foregroundStyle(.white)
                Button("Nochmal! 🔁") { match.rematch() }
                    .buttonStyle(SlimeButtonStyle(color: Kroko.gold, textColor: Kroko.night))
                    .frame(maxWidth: 260)
            }
            .padding(compact ? 18 : 28)
            .background(RoundedRectangle(cornerRadius: 32, style: .continuous).fill(Kroko.night.opacity(0.94)))
            .overlay(RoundedRectangle(cornerRadius: 32, style: .continuous).stroke(Kroko.gold, lineWidth: 3))
            .padding(.horizontal, 12)
        }
    }
}

/// Ein Knopf, der schon beim Draufdrücken auslöst – beim Schnappen zählt jede Millisekunde.
struct TouchDownButton<Label: View>: View {
    var color: Color
    var textColor: Color = Kroko.night
    var enabled: Bool
    var height: CGFloat
    let action: () -> Void
    @ViewBuilder let label: () -> Label
    @State private var pressed = false

    var body: some View {
        label()
            .foregroundStyle(textColor)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(color)
                    .shadow(color: color.opacity(enabled ? 0.8 : 0), radius: pressed ? 2 : 12)
            )
            .scaleEffect(pressed ? 0.92 : 1)
            .opacity(enabled ? 1 : 0.35)
            .animation(.spring(response: 0.2, dampingFraction: 0.5), value: pressed)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !pressed else { return }
                        pressed = true
                        if enabled { action() }
                    }
                    .onEnded { _ in pressed = false }
            )
    }
}
