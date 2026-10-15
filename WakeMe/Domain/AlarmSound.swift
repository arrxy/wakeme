import Foundation

enum AlarmSound: String, CaseIterable, Identifiable, Codable, Sendable {
    case radial = "Radial"
    case beacon = "Beacon"
    case circuit = "Circuit"
    case rise = "Rise"

    var id: String { rawValue }
    var fileName: String { "\(rawValue).caf" }

    static func named(_ raw: String) -> AlarmSound {
        AlarmSound(rawValue: raw) ?? .radial
    }
}

enum RingPolicy {
    static let backupDelay: TimeInterval = 60
    static let snoozeDuration: TimeInterval = 9 * 60
    static let snoozeCap = 3
    static let missionVolume: Float = 0.35

    static func allowsSnooze(enabled: Bool, count: Int) -> Bool {
        enabled && count < snoozeCap
    }
}
