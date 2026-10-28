import SwiftUI
import UIKit

/// Ein Krokodilspiel aus Sicht eines Spielers.
///
/// Die Beute entscheidet jede Runde, denn nur ihr Handy weiß genau, wann der Finger weg war.
/// Das Schnapp-Zeitfenster startet, sobald der Schnapp dort ankommt, damit Funk-Verzögerung niemandem schadet.
@MainActor
final class CrocMatch: ObservableObject {
    enum Phase: Equatable {
        /// Beute hat den Finger noch nicht drauf.
        case waiting
        /// Beute hält, das Krokodil darf schnappen.
        case armed(since: Date)
        /// Das Maul geht zu.
        case snapping(since: Date, window: Double)
        case result(CrocRoundReason)
        case over
    }

    static let winningScore = 5
    /// So lange darf das Krokodil warten, bevor es als zu langsam gilt.
    static let crocPatience: Double = 9

    let me: CrocAnimal
    let opponent: CrocAnimal
    /// Der Gastgeber ist in der ersten Runde das Krokodil.
    let isHost: Bool

    @Published private(set) var round = 0
    @Published private(set) var phase: Phase = .waiting
    @Published private(set) var myScore = 0
    @Published private(set) var theirScore = 0
    /// Zeitpunkt des letzten Zuckens, für die Wackel-Animation.
    @Published private(set) var twitchAt: Date?
    @Published private(set) var lastReason: CrocRoundReason?
    @Published var disconnected = false

    /// Hält die Beute gerade ihren Finger drauf (nur auf dem eigenen Handy bekannt).
    private var holding = false
    private let transport: CrocTransport
    private var patienceToken = 0
    /// Für Bildschirmfotos im Simulator: kein Zeitlimit.
    var patient = false

    init(me: CrocAnimal, opponent: CrocAnimal, isHost: Bool, transport: CrocTransport) {
        self.me = me
        self.opponent = opponent
        self.isHost = isHost
        self.transport = transport
        transport.onReceive = { [weak self] message in
            MainActor.assumeIsolated { self?.receive(message) }
        }
    }

    var role: CrocRole { (round % 2 == 0) == isHost ? .croc : .prey }
    var preyAnimal: CrocAnimal { role == .prey ? me : opponent }
    var crocAnimal: CrocAnimal { role == .croc ? me : opponent }

    /// Wie lange die Beute nach dem Schnapp Zeit hat – wird mit jeder Runde etwas knapper.
    var snapWindow: Double { max(0.33, 0.52 - Double(round) * 0.015) }

    var iWonMatch: Bool { myScore > theirScore }

    // MARK: - Beute

    func preyTouchDown() {
        guard role == .prey, !holding else { return }
        holding = true
        guard phase == .waiting else { return }
        phase = .armed(since: .now)
        transport.send(.ready(round: round))
        startPatience()
    }

    func preyLift() {
        guard role == .prey, holding else { return }
        holding = false
        switch phase {
        case .armed:
            finish(.early)
        case .snapping(let since, let window):
            finish(Date.now.timeIntervalSince(since) < window ? .escaped : .caught)
        default:
            break
        }
    }

    private func startPatience() {
        patienceToken += 1
        let token = patienceToken
        guard !patient else { return }
        after(Self.crocPatience) { [weak self] in
            guard let self, token == self.patienceToken, case .armed = self.phase else { return }
            self.finish(.slow)
        }
    }

    private func preyReceivesSnap() {
        guard case .armed = phase else { return }
        patienceToken += 1
        let window = snapWindow
        phase = .snapping(since: .now, window: window)
        SpookAudio.shared.play(sound: "fx_croc_snap", volume: 1)
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        let r = round
        after(window) { [weak self] in
            guard let self, self.round == r, case .snapping = self.phase else { return }
            self.finish(.caught)
        }
    }

    /// Die Beute legt das Ergebnis fest und schickt es rüber.
    private func finish(_ reason: CrocRoundReason) {
        guard role == .prey else { return }
        transport.send(.result(round: round, reason: reason))
        apply(reason)
    }

    // MARK: - Krokodil

    func crocTwitch() {
        guard role == .croc, case .armed = phase else { return }
        transport.send(.twitch(round: round))
        twitchAt = .now
        SpookAudio.shared.play(sound: "fx_croc_twitch", volume: 0.7)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func crocSnap() {
        guard role == .croc, case .armed = phase else { return }
        transport.send(.snap(round: round))
        phase = .snapping(since: .now, window: snapWindow)
        SpookAudio.shared.play(sound: "fx_croc_snap", volume: 1)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    // MARK: - Gemeinsam

    private func after(_ seconds: Double, _ work: @escaping @MainActor () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { MainActor.assumeIsolated(work) }
    }

    func rematch() {
        transport.send(.rematch)
        reset()
    }

    func leave() {
        transport.send(.bye)
    }

    private func reset() {
        round = 0
        myScore = 0
        theirScore = 0
        holding = false
        lastReason = nil
        phase = .waiting
        patienceToken += 1
    }

    private func apply(_ reason: CrocRoundReason) {
        guard phase != .over else { return }
        if case .result = phase { return }
        let iWin = (role == .croc) == reason.crocWins
        if iWin { myScore += 1 } else { theirScore += 1 }
        lastReason = reason
        phase = .result(reason)
        SpookAudio.shared.play(sound: reason.sound, volume: 0.9)
        UINotificationFeedbackGenerator().notificationOccurred(iWin ? .success : .error)

        let r = round
        after(2.6) { [weak self] in
            guard let self, self.round == r, case .result = self.phase else { return }
            self.advance(to: r + 1)
        }
    }

    private func advance(to newRound: Int) {
        if myScore >= Self.winningScore || theirScore >= Self.winningScore {
            if phase != .over {
                phase = .over
                SpookAudio.shared.play(sound: iWonMatch ? "fx_croc_win" : "fx_croc_caught", volume: 0.9)
            }
            return
        }
        round = newRound
        phase = .waiting
        holding = false
        patienceToken += 1
    }

    private func receive(_ message: CrocMessage) {
        switch message {
        case .ready(let r):
            if r > round, phase != .over { advance(to: r) }
            guard r == round, role == .croc, phase == .waiting else { return }
            phase = .armed(since: .now)
        case .twitch(let r):
            guard r == round, role == .prey, case .armed = phase else { return }
            twitchAt = .now
            SpookAudio.shared.play(sound: "fx_croc_twitch", volume: 0.7)
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        case .snap(let r):
            guard r == round, role == .prey else { return }
            preyReceivesSnap()
        case .result(let r, let reason):
            guard r == round, role == .croc else { return }
            apply(reason)
        case .rematch:
            reset()
        case .bye:
            disconnected = true
        case .hello:
            break
        }
    }
}
