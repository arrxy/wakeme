import Foundation

enum TypedPhrase {
    struct Progress: Equatable, Sendable {
        var correctCount: Int
        var typoIndex: Int?
        var isComplete: Bool
    }

    /// Counts only the matching prefix. A mismatch at the 24th character reports 23 correct.
    static func progress(typed: String, target: String) -> Progress {
        let typedChars = Array(typed)
        let targetChars = Array(target)
        var correct = 0
        for (index, character) in typedChars.enumerated() {
            if index >= targetChars.count || character != targetChars[index] {
                return Progress(correctCount: correct, typoIndex: index + 1, isComplete: false)
            }
            correct += 1
        }
        return Progress(correctCount: correct, typoIndex: nil, isComplete: !target.isEmpty && typed == target)
    }
}
