import Foundation
import SwiftData

@Model
final class AppSettings {
    var id: UUID
    var defaultMissionJSON: Data

    init(id: UUID = UUID(), defaultMission: Mission? = nil) {
        self.id = id
        self.defaultMissionJSON = defaultMission.flatMap { try? JSONEncoder().encode($0) } ?? Data()
    }

    var defaultMission: Mission? {
        get {
            guard !defaultMissionJSON.isEmpty else { return nil }
            return try? JSONDecoder().decode(Mission.self, from: defaultMissionJSON)
        }
        set { defaultMissionJSON = newValue.flatMap { try? JSONEncoder().encode($0) } ?? Data() }
    }
}

@Model
final class TimerItem {
    var id: UUID
    var label: String
    var duration: TimeInterval
    var remaining: TimeInterval
    var isRunning: Bool
    var createdAt: Date

    init(id: UUID = UUID(), label: String = "Timer", duration: TimeInterval, remaining: TimeInterval? = nil, isRunning: Bool = false) {
        self.id = id
        self.label = label
        self.duration = duration
        self.remaining = remaining ?? duration
        self.isRunning = isRunning
        self.createdAt = .now
    }
}
