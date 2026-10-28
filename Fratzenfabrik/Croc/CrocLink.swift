import GameKit
import UIKit

/// Anmeldung bei Game Center – nötig, damit sich zwei Handys übers Internet finden.
@MainActor
final class GameCenterAuth: ObservableObject {
    enum State: Equatable { case unknown, signingIn, signedIn, failed(String) }

    static let shared = GameCenterAuth()
    @Published private(set) var state: State = .unknown

    func signIn() {
        if GKLocalPlayer.local.isAuthenticated { state = .signedIn; return }
        guard state != .signingIn else { return }
        state = .signingIn
        GKLocalPlayer.local.authenticateHandler = { viewController, error in
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    let auth = GameCenterAuth.shared
                    if let viewController {
                        UIApplication.presentOnTop(viewController)
                    } else if GKLocalPlayer.local.isAuthenticated {
                        auth.state = .signedIn
                    } else {
                        auth.state = .failed(error?.localizedDescription
                            ?? "Bitte in den Einstellungen bei Game Center anmelden.")
                    }
                }
            }
        }
    }
}

extension UIApplication {
    /// Zeigt einen UIKit-Bildschirm (z. B. die Game-Center-Anmeldung) über allem an.
    @MainActor
    static func presentOnTop(_ viewController: UIViewController) {
        let window = shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow }.first
        guard var top = window?.rootViewController else { return }
        while let next = top.presentedViewController { top = next }
        top.present(viewController, animated: true)
    }
}

/// Verbindet zwei Handys übers Internet (Game Center). Beide geben denselben Spielcode ein.
@MainActor
final class CrocLink: NSObject, ObservableObject, CrocTransport {
    enum State: Equatable {
        case idle
        case searching(Int)
        case connected
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var peerAnimal: CrocAnimal?
    @Published private(set) var peerName: String?

    let myAnimal: CrocAnimal
    /// Zufallslos: entscheidet, wer in Runde 1 das Krokodil ist.
    let token = UUID().uuidString
    private(set) var peerToken: String?
    var isHost: Bool { token < (peerToken ?? "") }

    var onReceive: ((CrocMessage) -> Void)? {
        didSet { flushInbox() }
    }

    private var match: GKMatch?
    private var inbox: [CrocMessage] = []
    private var helloSent = false

    init(animal: CrocAnimal) {
        myAnimal = animal
    }

    /// Sucht übers Internet nach dem anderen Handy mit demselben Code.
    func search(code: Int) {
        stop()
        state = .searching(code)
        let request = GKMatchRequest()
        request.minPlayers = 2
        request.maxPlayers = 2
        // Nur Spieler derselben Gruppe werden zusammengebracht – das ist unser Spielcode.
        request.playerGroup = 4_200_000 + code
        GKMatchmaker.shared().findMatch(for: request) { [weak self] match, error in
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    guard let self, case .searching(let current) = self.state, current == code else {
                        match?.disconnect()
                        return
                    }
                    if let match {
                        self.match = match
                        match.delegate = self
                        if match.expectedPlayerCount == 0 { self.didConnect() }
                    } else {
                        self.state = .failed(error?.localizedDescription ?? "Niemanden gefunden.")
                    }
                }
            }
        }
    }

    func stop() {
        GKMatchmaker.shared().cancel()
        match?.delegate = nil
        match?.disconnect()
        match = nil
        helloSent = false
        if case .searching = state { state = .idle }
    }

    func send(_ message: CrocMessage) {
        guard let match, let data = try? JSONEncoder().encode(message) else { return }
        try? match.sendData(toAllPlayers: data, with: .reliable)
    }

    private func didConnect() {
        guard !helloSent, let match else { return }
        helloSent = true
        state = .connected
        peerName = match.players.first?.displayName
        send(.hello(animal: myAnimal, token: token))
    }

    private func flushInbox() {
        guard let onReceive, !inbox.isEmpty else { return }
        let pending = inbox
        inbox.removeAll()
        pending.forEach(onReceive)
    }

    private func handle(_ message: CrocMessage) {
        if case .hello(let animal, let token) = message {
            peerToken = token
            peerAnimal = animal
            SpookAudio.shared.play(sound: "fx_croc_hello")
            return
        }
        if let onReceive { onReceive(message) } else { inbox.append(message) }
    }
}

extension CrocLink: GKMatchDelegate {
    nonisolated func match(_ match: GKMatch, didReceive data: Data, fromRemotePlayer player: GKPlayer) {
        guard let message = try? JSONDecoder().decode(CrocMessage.self, from: data) else { return }
        DispatchQueue.main.async { [self] in MainActor.assumeIsolated { handle(message) } }
    }

    nonisolated func match(_ match: GKMatch, player: GKPlayer, didChange state: GKPlayerConnectionState) {
        DispatchQueue.main.async { [self] in
            MainActor.assumeIsolated {
                switch state {
                case .connected:
                    if self.match?.expectedPlayerCount == 0 { didConnect() }
                case .disconnected:
                    handle(.bye)
                default:
                    break
                }
            }
        }
    }

    nonisolated func match(_ match: GKMatch, didFailWithError error: Error?) {
        DispatchQueue.main.async { [self] in
            MainActor.assumeIsolated {
                if peerAnimal != nil {
                    handle(.bye)
                } else {
                    self.state = .failed(error?.localizedDescription ?? "Verbindung fehlgeschlagen.")
                }
            }
        }
    }
}
