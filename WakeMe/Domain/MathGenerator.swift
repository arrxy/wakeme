import Foundation

enum MathGenerator {
    struct Question: Equatable, Sendable {
        var prompt: String
        var answer: Int

        var display: String { "\(prompt) = ?" }
    }

    static func sample(kind: MathKind, difficulty: Difficulty) -> String {
        var seed = stableSeed(kind: kind, difficulty: difficulty)
        return question(kind: kind, difficulty: difficulty, seed: &seed).display
    }

    static func stableSeed(kind: MathKind, difficulty: Difficulty) -> UInt64 {
        var value = UInt64(kind == .arithmetic ? 11 : 29)
        value = value &* 100 + UInt64(Difficulty.allCases.firstIndex(of: difficulty) ?? 0)
        return value &* 0x9E3779B97F4A7C15
    }

    static func question(kind: MathKind, difficulty: Difficulty, seed: inout UInt64) -> Question {
        var rng = SplitMix64(state: seed)
        let question: Question
        switch kind {
        case .arithmetic:
            question = arithmetic(difficulty: difficulty, rng: &rng)
        case .geometry:
            question = geometry(difficulty: difficulty, rng: &rng)
        }
        seed = rng.state
        return question
    }

    private static func arithmetic(difficulty: Difficulty, rng: inout SplitMix64) -> Question {
        switch difficulty {
        case .easy:
            let left = rng.int(10...99)
            let right = rng.int(10...99)
            if rng.bool() {
                return Question(prompt: "\(left) + \(right)", answer: left + right)
            }
            let high = max(left, right)
            let low = min(left, right)
            return Question(prompt: "\(high) − \(low)", answer: high - low)
        case .medium:
            if rng.bool() {
                let left = rng.int(10...99)
                let right = rng.int(2...9)
                return Question(prompt: "\(left) × \(right)", answer: left * right)
            }
            let left = rng.int(100...999)
            let right = rng.int(100...999)
            if rng.bool() {
                return Question(prompt: "\(left) + \(right)", answer: left + right)
            }
            let high = max(left, right)
            let low = min(left, right)
            return Question(prompt: "\(high) − \(low)", answer: high - low)
        case .hard:
            let left = rng.int(12...99)
            let factor = rng.int(2...9)
            if rng.bool() {
                return Question(prompt: "\(left) × \(factor)", answer: left * factor)
            }
            let extra = rng.int(10...40)
            if rng.bool() {
                return Question(prompt: "\(left) × \(factor) + \(extra)", answer: left * factor + extra)
            }
            let product = left * factor
            let subtract = min(extra, product)
            return Question(prompt: "\(left) × \(factor) − \(subtract)", answer: product - subtract)
        case .expert:
            let left = rng.int(100...250)
            let factor = rng.int(2...9)
            let extra = rng.int(10...80)
            let product = left * factor
            if rng.bool() {
                return Question(prompt: "\(left) × \(factor) − \(extra)", answer: product - extra)
            }
            return Question(prompt: "\(left) × \(factor) + \(extra)", answer: product + extra)
        }
    }

    private static func geometry(difficulty: Difficulty, rng: inout SplitMix64) -> Question {
        let scale: Int
        switch difficulty {
        case .easy: scale = 1
        case .medium: scale = 2
        case .hard: scale = 3
        case .expert: scale = 4
        }
        switch rng.int(0...5) {
        case 0:
            let width = rng.int(2...8) * scale
            let height = rng.int(2...8) * scale
            return Question(prompt: "Rectangle \(width) by \(height), area", answer: width * height)
        case 1:
            let width = rng.int(2...8) * scale
            let height = rng.int(2...8) * scale
            return Question(prompt: "Rectangle \(width) by \(height), perimeter", answer: 2 * (width + height))
        case 2:
            let side = rng.int(2...12) * scale
            return Question(prompt: "Square side \(side), area", answer: side * side)
        case 3:
            let base = rng.int(2...10) * scale
            let height = rng.int(1...6) * 2
            return Question(prompt: "Triangle base \(base) height \(height), area", answer: base * height / 2)
        case 4:
            let angle = rng.int(15...70)
            return Question(prompt: "Complement of \(angle)°", answer: 90 - angle)
        default:
            let first = rng.int(20...70)
            let second = rng.int(20...70)
            let third = 180 - first - second
            if third > 0 {
                return Question(prompt: "Triangle angles \(first)° and \(second)°, third angle", answer: third)
            }
            return Question(prompt: "Complement of \(first)°", answer: 90 - first)
        }
    }
}

struct SplitMix64: RandomNumberGenerator {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var mixed = state
        mixed = (mixed ^ (mixed >> 30)) &* 0xBF58476D1CE4E5B9
        mixed = (mixed ^ (mixed >> 27)) &* 0x94D049BB133111EB
        return mixed ^ (mixed >> 31)
    }

    mutating func int(_ range: ClosedRange<Int>) -> Int {
        let span = UInt64(range.upperBound - range.lowerBound + 1)
        return range.lowerBound + Int(next() % span)
    }

    mutating func bool() -> Bool { next() & 1 == 0 }
}
