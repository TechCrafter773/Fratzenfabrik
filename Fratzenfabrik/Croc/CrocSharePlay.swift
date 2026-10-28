import Combine
import GroupActivities
import UIKit

/// Das Krokodilspiel als SharePlay-Aktivität: man spielt im FaceTime-Anruf und sieht und hört sich dabei.
struct CrocActivity: GroupActivity {
    static let activityIdentifier = "com.techcrafter773.fratzenfabrik.krokodil"

    var metadata: GroupActivityMetadata {
        var meta = GroupActivityMetadata()
        meta.title = "Krokodilspiel 🐊"
        meta.subtitle = "Wer ist schneller – das Krokodil oder dein Tier?"
        meta.type = .generic
        return meta
    }
}

/// Verbindet zwei Handys über SharePlay im FaceTime-Anruf.
///
/// Läuft die ganze Zeit mit: Startet das andere Handy das Spiel, kommt die Sitzung hier an
/// und die App springt direkt ins Krokodilspiel.
@MainActor
final class CrocSharePlay: ObservableObject, CrocTransport {
    static let shared = CrocSharePlay()

    @Published private(set) var session: GroupSession<CrocActivity>?
    @Published private(set) var peerAnimal: CrocAnimal?
    @Published private(set) var otherJoined = false
    @Published var problem: String?

    /// Zufallslos: entscheidet, wer in Runde 1 das Krokodil ist.
    private(set) var token = UUID().uuidString
    private var peerToken: String?
    var isHost: Bool { token < (peerToken ?? "") }

    var onReceive: ((CrocMessage) -> Void)? {
        didSet { flushInbox() }
    }

    private var messenger: GroupSessionMessenger?
    private var tasks: [Task<Void, Never>] = []
    private var subscriptions = Set<AnyCancellable>()
    private var lastSend: Task<Void, Never>?
    private var inbox: [CrocMessage] = []
    private var observing = false

    /// Einmal beim App-Start aufrufen: wartet auf Krokodilspiele aus FaceTime.
    func observeSessions() async {
        guard !observing else { return }
        observing = true
        for await session in CrocActivity.sessions() {
            configure(session)
        }
    }

    /// Startet SharePlay. Ohne laufenden FaceTime-Anruf öffnet sich die Apple-Auswahl zum Einladen.
    func start() async {
        problem = nil
        switch await CrocActivity().prepareForActivation() {
        case .activationPreferred:
            do {
                _ = try await CrocActivity().activate()
            } catch {
                problem = "SharePlay ließ sich nicht starten: \(error.localizedDescription)"
            }
        case .activationDisabled:
            inviteViaSheet()
        case .cancelled:
            break
        @unknown default:
            break
        }
    }

    private func inviteViaSheet() {
        do {
            let controller = try GroupActivitySharingController(CrocActivity())
            UIApplication.presentOnTop(controller)
        } catch {
            problem = "Bitte zuerst einen FaceTime-Videoanruf starten, dann nochmal tippen."
        }
    }

    /// Spiel verlassen; der FaceTime-Anruf läuft weiter.
    func leave() {
        session?.leave()
        reset()
    }

    func send(_ message: CrocMessage) {
        guard let messenger else { return }
        let previous = lastSend
        // Nacheinander verschicken, damit die Reihenfolge stimmt.
        lastSend = Task {
            await previous?.value
            try? await messenger.send(message)
        }
    }

    private func configure(_ newSession: GroupSession<CrocActivity>) {
        reset()
        token = UUID().uuidString
        session = newSession
        let messenger = GroupSessionMessenger(session: newSession, deliveryMode: .reliable)
        self.messenger = messenger

        tasks.append(Task { [weak self] in
            for await (message, _) in messenger.messages(of: CrocMessage.self) {
                self?.handle(message)
            }
        })

        newSession.$activeParticipants
            .receive(on: DispatchQueue.main)
            .sink { [weak self] participants in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    let together = participants.count >= 2
                    if together {
                        self.otherJoined = true
                        self.send(.hello(animal: self.myAnimal, token: self.token))
                    } else if self.otherJoined {
                        self.handle(.bye)
                    }
                }
            }
            .store(in: &subscriptions)

        newSession.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                MainActor.assumeIsolated {
                    guard let self, case .invalidated = state, self.session === newSession else { return }
                    self.handle(.bye)
                    self.reset()
                }
            }
            .store(in: &subscriptions)

        newSession.join()
    }

    private var myAnimal: CrocAnimal {
        UserDefaults.standard.string(forKey: "crocAnimal").flatMap(CrocAnimal.init(rawValue:)) ?? .unicorn
    }

    private func reset() {
        tasks.forEach { $0.cancel() }
        tasks.removeAll()
        subscriptions.removeAll()
        lastSend = nil
        messenger = nil
        session = nil
        peerAnimal = nil
        peerToken = nil
        otherJoined = false
        inbox.removeAll()
        onReceive = nil
    }

    private func flushInbox() {
        guard let onReceive, !inbox.isEmpty else { return }
        let pending = inbox
        inbox.removeAll()
        pending.forEach(onReceive)
    }

    private func handle(_ message: CrocMessage) {
        if case .hello(let animal, let theirToken) = message {
            let first = peerAnimal == nil
            peerToken = theirToken
            peerAnimal = animal
            if first {
                SpookAudio.shared.play(sound: "fx_croc_hello")
                // Antworten, falls unser Hallo zu früh losging.
                send(.hello(animal: myAnimal, token: token))
            }
            return
        }
        if let onReceive { onReceive(message) } else { inbox.append(message) }
    }
}

extension UIApplication {
    /// Zeigt einen UIKit-Bildschirm (z. B. die SharePlay-Einladung) über allem an.
    @MainActor
    static func presentOnTop(_ viewController: UIViewController) {
        let window = shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow }.first
        guard var top = window?.rootViewController else { return }
        while let next = top.presentedViewController { top = next }
        top.present(viewController, animated: true)
    }
}
