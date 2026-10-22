import SwiftUI

enum DesignID: String, CaseIterable, Identifiable {
    case ghost, cat, cyclops, pumpkin, witch, devil, mummy, spiderweb, bat, vampire, werewolf, skeleton, sugarSkull, frankenstein
    var id: String { rawValue }
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

    static func == (lhs: FaceDesign, rhs: FaceDesign) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

extension Array where Element == PaintStep {
    /// Baut Schritte aus (Titel, Text, Werkzeug) und nummeriert sie durch.
    static func steps(_ list: [(String, String, String)]) -> [PaintStep] {
        list.enumerated().map { PaintStep(id: $0.offset, title: $0.element.0, text: $0.element.1, tool: $0.element.2) }
    }
}
