import Foundation

enum MathKind: String, Codable, CaseIterable, Hashable, Sendable {
    case arithmetic
    case geometry

    var title: String {
        switch self {
        case .arithmetic: "Arithmetic"
        case .geometry: "Geometry"
        }
    }
}

enum Difficulty: String, Codable, CaseIterable, Hashable, Sendable {
    case easy
    case medium
    case hard
    case expert

    var title: String { rawValue.capitalized }
}

enum ShakeStrength: String, Codable, CaseIterable, Hashable, Sendable {
    case gentle
    case medium
    case firm
    case strong

    var title: String { rawValue.capitalized }

    /// Acceleration magnitude, in g, that counts as one shake.
    var threshold: Double {
        switch self {
        case .gentle: 1.2
        case .medium: 1.8
        case .firm: 2.4
        case .strong: 3.2
        }
    }
}

enum Mission: Codable, Equatable, Hashable, Sendable {
    case math(kind: MathKind, count: Int, difficulty: Difficulty)
    case shake(count: Int, strength: ShakeStrength)
    case type(text: String)

    static let defaultTypePhrase = "I am awake and I am getting out of bed now."
    static let defaultWake: Mission = .math(kind: .arithmetic, count: 5, difficulty: .hard)

    var summary: String {
        switch self {
        case let .math(kind, count, difficulty):
            "\(kind.title), \(count) Q, \(difficulty.rawValue)"
        case let .shake(count, _):
            "Shake, \(count) times"
        case .type:
            "Type text"
        }
    }

    var pill: String {
        switch self {
        case let .math(kind, count, difficulty):
            "\(kind.title.uppercased()) · \(count) Q · \(difficulty.title.uppercased())"
        case let .shake(count, _):
            "SHAKE · \(count) TIMES"
        case .type:
            "TYPE TEXT"
        }
    }

    var symbolName: String {
        switch self {
        case .math(let kind, _, _):
            kind == .geometry ? "triangle" : "plus.forwardslash.minus"
        case .shake:
            "iphone.radiowaves.left.and.right"
        case .type:
            "keyboard"
        }
    }

    var editorTitle: String {
        switch self {
        case .math(let kind, _, _):
            kind == .geometry ? "Solve geometry" : "Solve arithmetic"
        case .shake:
            "Shake the phone"
        case .type:
            "Type a phrase"
        }
    }

    var editorDetail: String {
        switch self {
        case let .math(_, count, difficulty):
            "\(count) questions · \(difficulty.title)"
        case let .shake(count, strength):
            "\(count) shakes · \(strength.title)"
        case let .type(text):
            text
        }
    }
}
