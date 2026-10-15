import Foundation
import SwiftData

@Model
final class Alarm {
    var id: UUID
    var hour: Int
    var minute: Int
    var repeatDayRaws: [Int]
    var oneShotDate: Date?
    var label: String
    var sound: String
    var snoozeEnabled: Bool
    var missionJSON: Data?
    var seriesID: UUID?
    var isEnabled: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        hour: Int,
        minute: Int,
        repeatDayRaws: [Int] = [],
        oneShotDate: Date? = nil,
        label: String,
        sound: String,
        snoozeEnabled: Bool,
        missionJSON: Data? = nil,
        seriesID: UUID? = nil,
        isEnabled: Bool = true,
        createdAt: Date = .now
    ) {
        self.id = id
        self.hour = hour
        self.minute = minute
        self.repeatDayRaws = repeatDayRaws
        self.oneShotDate = oneShotDate
        self.label = label
        self.sound = sound
        self.snoozeEnabled = snoozeEnabled
        self.missionJSON = missionJSON
        self.seriesID = seriesID
        self.isEnabled = isEnabled
        self.createdAt = createdAt
    }

    var record: AlarmRecord {
        AlarmRecord(
            id: id,
            hour: hour,
            minute: minute,
            repeatDays: repeatDayRaws.compactMap(Weekday.init(rawValue:)),
            oneShotDate: oneShotDate,
            label: label,
            sound: sound,
            snoozeEnabled: snoozeEnabled,
            mission: missionJSON.flatMap { try? JSONDecoder().decode(Mission.self, from: $0) },
            seriesID: seriesID,
            isEnabled: isEnabled
        )
    }

    func apply(_ record: AlarmRecord) {
        hour = record.hour
        minute = record.minute
        repeatDayRaws = record.repeatDays.map(\.rawValue)
        oneShotDate = record.oneShotDate
        label = record.label
        sound = record.sound
        snoozeEnabled = record.snoozeEnabled
        missionJSON = record.mission.flatMap { try? JSONEncoder().encode($0) }
        seriesID = record.seriesID
        isEnabled = record.isEnabled
    }
}

extension AlarmRecord {
    func makeModel() -> Alarm {
        Alarm(
            id: id,
            hour: hour,
            minute: minute,
            repeatDayRaws: repeatDays.map(\.rawValue),
            oneShotDate: oneShotDate,
            label: label,
            sound: sound,
            snoozeEnabled: snoozeEnabled,
            missionJSON: mission.flatMap { try? JSONEncoder().encode($0) },
            seriesID: seriesID,
            isEnabled: isEnabled
        )
    }
}
