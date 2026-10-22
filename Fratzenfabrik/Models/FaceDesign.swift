import SwiftUI
import UIKit

enum DesignID: String, CaseIterable, Identifiable {
    case ghostCute, ghostFunny, ghostScary
    case cat, cyclops, pumpkin, witch, devil, mummy, spiderweb, bat, batSwarm
    case vampire, werewolf, skeleton, sugarSkull, frankenstein
    var id: String { rawValue }
}

/// Für wen ein Design gedacht ist – und welches 3D-Modell es zeigt.
enum Kid: String, CaseIterable, Identifiable {
    case girl, boy
    var id: String { rawValue }
    var label: String { self == .girl ? "Mädchen" : "Junge" }
    var plural: String { self == .girl ? "Mädchen" : "Jungs" }
    var emoji: String { self == .girl ? "👧" : "👦" }
}

struct PaintColor: Identifiable, Hashable {
    let name: String
    let color: Color
    var id: String { name }
}

enum Paint {
    static let white = PaintColor(name: "Weiß", color: Color(hex: 0xF7F6F0))
    static let black = PaintColor(name: "Schwarz", color: Color(hex: 0x17121C))
    static let grey = PaintColor(name: "Grau", color: Color(hex: 0x8D8A99))
    static let orange = PaintColor(name: "Orange", color: Color(hex: 0xFF8A1F))
    static let darkOrange = PaintColor(name: "Dunkelorange", color: Color(hex: 0xC94F0C))
    static let green = PaintColor(name: "Grün", color: Color(hex: 0x6BC43A))
    static let paleGreen = PaintColor(name: "Hellgrün", color: Color(hex: 0x9EE07A))
    static let darkGreen = PaintColor(name: "Dunkelgrün", color: Color(hex: 0x2F6B2A))
    static let red = PaintColor(name: "Rot", color: Color(hex: 0xD3122F))
    static let purple = PaintColor(name: "Lila", color: Color(hex: 0x7A3FC2))
    static let pink = PaintColor(name: "Rosa", color: Color(hex: 0xFF8FB8))
    static let yellow = PaintColor(name: "Gelb", color: Color(hex: 0xFFD93B))
    static let brown = PaintColor(name: "Braun", color: Color(hex: 0x6B4226))
    static let turquoise = PaintColor(name: "Türkis", color: Color(hex: 0x2EC4C6))
    static let lightBlue = PaintColor(name: "Hellblau", color: Color(hex: 0x9FD8FF))
    static let beige = PaintColor(name: "Beige", color: Color(hex: 0xE8D9B5))
    static let darkRed = PaintColor(name: "Dunkelrot", color: Color(hex: 0x8E0F24))
    static let darkBrown = PaintColor(name: "Dunkelbraun", color: Color(hex: 0x3B2414))
    static let glitter = PaintColor(name: "Glitzer", color: Color(hex: 0xE9E4FF))
}

enum Difficulty: Int, CaseIterable, Identifiable, Comparable {
    case superEasy = 1, easy, medium

    var id: Int { rawValue }
    var label: String {
        switch self {
        case .superEasy: "Kinderleicht"
        case .easy: "Leicht"
        case .medium: "Für Mutige"
        }
    }
    var pumpkins: String { String(repeating: "🎃", count: rawValue) }

    static func < (lhs: Difficulty, rhs: Difficulty) -> Bool { lhs.rawValue < rhs.rawValue }
}

struct PaintStep: Identifiable {
    let id: Int
    let title: String
    let text: String
    let tool: String
}

// MARK: - Frisuren

enum HairStyle {
    case short, spiky, slicked, wild, pigtails, long, buns, ponytail, flatTop, bandaged, braids
}

enum Accessory {
    case catEars, witchHat, horns, bow, flowers
}

/// Ein Frisur-Vorschlag passend zum Design. Das 3D-Modell trägt ihn.
struct HairSuggestion {
    var style: HairStyle
    var color: UIColor
    var streak: UIColor? = nil
    var accessory: Accessory? = nil
    var title: String
    var tip: String
}

struct FaceDesign: Identifiable, Hashable {
    let id: DesignID
    let name: String
    let emoji: String
    let tagline: String
    let difficulty: Difficulty
    let minutes: Int
    let accent: Color
    let colors: [PaintColor]
    let tools: [String]
    let tip: String
    let steps: [PaintStep]
    var kids: Set<Kid> = [.girl, .boy]
    var hairGirl: HairSuggestion
    var hairBoy: HairSuggestion
    /// Was beim Mund-Aufreißen herausfliegt.
    var mouthEmojis: [String]

    func hair(for kid: Kid) -> HairSuggestion { kid == .girl ? hairGirl : hairBoy }

    /// Welches Modell auf Karten gezeigt wird, wenn kein Filter aktiv ist.
    var preferredKid: Kid {
        if kids == [.girl] { return .girl }
        if kids == [.boy] { return .boy }
        return id.rawValue.count.isMultiple(of: 2) ? .girl : .boy
    }

    static func == (lhs: FaceDesign, rhs: FaceDesign) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

extension Array where Element == PaintStep {
    /// Baut Schritte aus (Titel, Text, Werkzeug) und nummeriert sie durch.
    static func steps(_ list: [(String, String, String)]) -> [PaintStep] {
        list.enumerated().map { PaintStep(id: $0.offset, title: $0.element.0, text: $0.element.1, tool: $0.element.2) }
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

enum HairColor {
    static let black = UIColor(hex: 0x1C1714)
    static let darkBrown = UIColor(hex: 0x3B2416)
    static let brown = UIColor(hex: 0x6B4224)
    static let blond = UIColor(hex: 0xC9A15E)
    static let ginger = UIColor(hex: 0xB5531F)
    static let white = UIColor(hex: 0xE9E6EF)
    static let grey = UIColor(hex: 0x8E8A96)
    static let green = UIColor(hex: 0x4FA83A)
    static let red = UIColor(hex: 0xA5162C)
    static let purple = UIColor(hex: 0x6A35B0)
    static let orange = UIColor(hex: 0xE2741E)
    static let pink = UIColor(hex: 0xFF7FB6)
    static let silver = UIColor(hex: 0xCFD3DA)
    static let beige = UIColor(hex: 0xE3D5B1)
}
