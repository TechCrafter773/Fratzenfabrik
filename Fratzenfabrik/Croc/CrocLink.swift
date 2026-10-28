import MultipeerConnectivity
import UIKit

/// Verbindet zwei Handys über WLAN/Bluetooth (ohne Internet).
///
/// Beide Handys suchen und werben gleichzeitig. Wer das kleinere Los gezogen hat, lädt ein –
/// so verbinden sich zwei Handys von selbst, ohne dass jemand etwas antippen muss.
@MainActor
final class CrocLink: NSObject, ObservableObject, CrocTransport {
    enum State: Equatable {
        case searching
        case connecting(String)
        case connected
        case failed(String)
    }

    static let serviceType = "fratz-kroko"

    @Published private(set) var state: State = .searching
    @Published private(set) var peerAnimal: CrocAnimal?
    @Published private(set) var peerName: String?

    let myAnimal: CrocAnimal
    /// Zufallslos: entscheidet, wer einlädt und wer in Runde 1 Krokodil ist.
    let token = UUID().uuidString
    private(set) var peerToken: String?
    var isHost: Bool { token < (peerToken ?? "") }

    var onReceive: ((CrocMessage) -> Void)? {
        didSet { flushInbox() }
    }

    private let peerID: MCPeerID
    private let session: MCSession
    private let advertiser: MCNearbyServiceAdvertiser
    private let browser: MCNearbyServiceBrowser
    private var inbox: [CrocMessage] = []
    private var invited: Set<MCPeerID> = []

    init(animal: CrocAnimal) {
        myAnimal = animal
        peerID = MCPeerID(displayName: String(UIDevice.current.name.prefix(20)))
        session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: ["t": token], serviceType: Self.serviceType)
        browser = MCNearbyServiceBrowser(peer: peerID, serviceType: Self.serviceType)
        super.init()
        session.delegate = self
        advertiser.delegate = self
        browser.delegate = self
    }

    func start() {
        advertiser.startAdvertisingPeer()
        browser.startBrowsingForPeers()
    }

    func stop() {
        advertiser.stopAdvertisingPeer()
        browser.stopBrowsingForPeers()
        session.disconnect()
    }

    func send(_ message: CrocMessage) {
        guard !session.connectedPeers.isEmpty, let data = try? JSONEncoder().encode(message) else { return }
        try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
    }

    private func flushInbox() {
        guard let onReceive, !inbox.isEmpty else { return }
        let pending = inbox
        inbox.removeAll()
        pending.forEach(onReceive)
    }

    private func handle(_ message: CrocMessage) {
        if case .hello(let animal, let token) = message {
            peerAnimal = animal
            peerToken = token
            SpookAudio.shared.play(sound: "fx_croc_hello")
            return
        }
        if let onReceive { onReceive(message) } else { inbox.append(message) }
    }
}

extension CrocLink: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async { [self] in MainActor.assumeIsolated {
            switch state {
            case .connected:
                self.state = .connected
                peerName = peerID.displayName
                advertiser.stopAdvertisingPeer()
                browser.stopBrowsingForPeers()
                send(.hello(animal: myAnimal, token: token))
            case .connecting:
                self.state = .connecting(peerID.displayName)
            case .notConnected:
                invited.remove(peerID)
                if self.state == .connected || peerAnimal != nil {
                    // Verbindung verloren: dem Spiel Bescheid sagen.
                    handle(.bye)
                } else {
                    self.state = .searching
                    advertiser.startAdvertisingPeer()
                    browser.startBrowsingForPeers()
                }
            @unknown default:
                break
            }
        } }
    }

    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let message = try? JSONDecoder().decode(CrocMessage.self, from: data) else { return }
        DispatchQueue.main.async { [self] in MainActor.assumeIsolated { handle(message) } }
    }

    nonisolated func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

extension CrocLink: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID,
                    withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        DispatchQueue.main.async { [self] in MainActor.assumeIsolated {
            invitationHandler(session.connectedPeers.isEmpty, session)
        } }
    }

    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        DispatchQueue.main.async { [self] in MainActor.assumeIsolated {
            state = .failed("Bitte erlaube „Lokales Netzwerk“ für die Fratzenfabrik in den Einstellungen.")
        } }
    }
}

extension CrocLink: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        DispatchQueue.main.async { [self] in MainActor.assumeIsolated {
            guard session.connectedPeers.isEmpty, !invited.contains(peerID),
                  let theirToken = info?["t"], token < theirToken else { return }
            invited.insert(peerID)
            browser.invitePeer(peerID, to: session, withContext: nil, timeout: 15)
        } }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        DispatchQueue.main.async { [self] in MainActor.assumeIsolated { _ = invited.remove(peerID) } }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        DispatchQueue.main.async { [self] in MainActor.assumeIsolated {
            state = .failed("Bitte erlaube „Lokales Netzwerk“ für die Fratzenfabrik in den Einstellungen.")
        } }
    }
}
