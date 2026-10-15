import Foundation

struct ShakeCounter: Equatable, Sendable {
    private(set) var count: Int
    let target: Int
    let threshold: Double
    var debounce: TimeInterval
    var idleBeforeDecay: TimeInterval
    private var lastPeak: Date?
    private var idleAnchor: Date?
    private var nextDecay: Date?

    init(target: Int, threshold: Double, count: Int = 0, debounce: TimeInterval = 0.35, idleBeforeDecay: TimeInterval = 5) {
        self.count = count
        self.target = target
        self.threshold = threshold
        self.debounce = debounce
        self.idleBeforeDecay = idleBeforeDecay
    }

    var remaining: Int { max(target - count, 0) }
    var isComplete: Bool { count >= target && target > 0 }

    mutating func addSample(magnitude: Double, at time: Date) {
        if magnitude >= threshold {
            idleAnchor = nil
            nextDecay = nil
            if let lastPeak, time.timeIntervalSince(lastPeak) < debounce { return }
            guard count < target else { return }
            count += 1
            lastPeak = time
        } else if idleAnchor == nil {
            idleAnchor = time
        }
    }

    mutating func decay(at time: Date) {
        guard count > 0, let idleAnchor else { return }
        let idle = time.timeIntervalSince(idleAnchor)
        guard idle >= idleBeforeDecay else { return }
        if nextDecay == nil {
            nextDecay = idleAnchor.addingTimeInterval(idleBeforeDecay)
        }
        while let due = nextDecay, time >= due, count > 0 {
            count -= 1
            nextDecay = due.addingTimeInterval(1)
        }
    }
}
