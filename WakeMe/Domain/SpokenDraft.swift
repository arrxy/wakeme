import Foundation

struct SpokenAlarmDraft: Identifiable, Equatable, Codable, Sendable {
    var id: UUID
    var hour: Int
    var minute: Int
    var repeatDays: [Weekday]
    var oneShotDate: Date?
    var label: String
    var mission: Mission?
    var usedDefaultMission: Bool
    var isDuplicate: Bool
    var include: Bool
    var seriesID: UUID?

    var record: AlarmRecord {
        AlarmRecord(
            id: id,
            hour: hour,
            minute: minute,
            repeatDays: repeatDays,
            oneShotDate: oneShotDate,
            label: label,
            sound: AlarmSound.radial.rawValue,
            snoozeEnabled: true,
            mission: mission,
            seriesID: seriesID,
            isEnabled: true
        )
    }

    var detailLine: String {
        var parts = [record.repeatSummary.capitalizedFirst, mission?.summary ?? "None"]
        if isDuplicate { parts.append("Already exists") }
        return parts.joined(separator: " · ")
    }
}

extension String {
    var capitalizedFirst: String {
        guard let first = first else { return self }
        return first.uppercased() + dropFirst()
    }
}
