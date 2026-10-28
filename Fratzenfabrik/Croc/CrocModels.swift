import SwiftUI

/// Farben der Krokodil-Welt: Gold, Rosa, Rot.
enum Kroko {
    static let gold = Color(hex: 0xFFC83D)
    static let deepGold = Color(hex: 0xD89A12)
    static let rose = Color(hex: 0xFF8FC8)
    static let blush = Color(hex: 0xFFD3E8)
    static let red = Color(hex: 0xE8243C)
    static let wine = Color(hex: 0x4A0A26)
    static let night = Color(hex: 0x2A0416)
    static let cream = Color(hex: 0xFFF6E6)
}

/// Die Tiere, die man im Krokodilspiel sein kann.
enum CrocAnimal: String, CaseIterable, Identifiable, Codable {
    case unicorn, horse, dolphin, whale

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .unicorn: "🦄"
        case .horse: "🐴"
        case .dolphin: "🐬"
        case .whale: "🐋"
        }
    }

    var name: String {
        switch self {
        case .unicorn: "Einhorn"
        case .horse: "Pferd"
        case .dolphin: "Delfin"
        case .whale: "Wal"
        }
    }

    /// „das Einhorn“, „der Delfin“ …
    var withArticle: String {
        switch self {
        case .unicorn, .horse: "das \(name)"
        case .dolphin, .whale: "der \(name)"
        }
    }

    var color: Color {
        switch self {
        case .unicorn: Kroko.rose
        case .horse: Kroko.gold
        case .dolphin: Color(hex: 0xFF6FA0)
        case .whale: Kroko.red
        }
    }
}

enum CrocRole { case croc, prey }

/// Was zwischen den beiden Handys hin und her geht.
enum CrocMessage: Codable {
    case hello(animal: CrocAnimal, token: String)
    /// Die Beute hält ihren Finger drauf.
    case ready(round: Int)
    /// Das Krokodil zuckt nur (Finte).
    case twitch(round: Int)
    /// Das Krokodil schnappt zu.
    case snap(round: Int)
    /// Die Beute entscheidet, wie die Runde ausgegangen ist.
    case result(round: Int, reason: CrocRoundReason)
    case rematch
    case bye
}

enum CrocRoundReason: String, Codable {
    /// Krokodil hat geschnappt und erwischt.
    case caught
    /// Beute hat rechtzeitig weggezogen.
    case escaped
    /// Beute hat ohne Schnapp weggezogen.
    case early
    /// Krokodil hat sich nicht getraut.
    case slow

    var crocWins: Bool { self == .caught || self == .early }

    var sound: String {
        switch self {
        case .caught: "fx_croc_caught"
        case .escaped: "fx_croc_escape"
        case .early: "fx_croc_early"
        case .slow: "fx_croc_slow"
        }
    }
}

/// Wie die Nachrichten verschickt werden: über WLAN/Bluetooth zum anderen Handy oder direkt auf demselben Handy.
@MainActor
protocol CrocTransport: AnyObject {
    func send(_ message: CrocMessage)
    var onReceive: ((CrocMessage) -> Void)? { get set }
}

/// Zwei Spieler an einem Handy: Nachrichten gehen direkt an das andere Ende.
@MainActor
final class LocalCrocTransport: CrocTransport {
    weak var partner: LocalCrocTransport?
    var onReceive: ((CrocMessage) -> Void)?

    func send(_ message: CrocMessage) {
        DispatchQueue.main.async { [weak partner] in MainActor.assumeIsolated { partner?.onReceive?(message) } }
    }

    static func pair() -> (LocalCrocTransport, LocalCrocTransport) {
        let a = LocalCrocTransport(), b = LocalCrocTransport()
        a.partner = b
        b.partner = a
        return (a, b)
    }
}
