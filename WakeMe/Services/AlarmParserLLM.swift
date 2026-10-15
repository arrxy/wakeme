import Foundation
import FoundationModels

@Generable
struct LLMAlarmBatch {
    @Guide(description: "Every alarm the person asked for")
    var alarms: [LLMAlarmItem]
}

@Generable
struct LLMAlarmItem {
    @Guide(description: "Hour on a 24-hour clock, 0 through 23")
    var hour: Int
    @Guide(description: "Minute, 0 through 59")
    var minute: Int
    @Guide(description: "Comma-separated weekdays, or tomorrow, or once")
    var days: String
    @Guide(description: "Short label such as Gym, Wake up, or Alarm")
    var label: String
    @Guide(description: "math, geometry, shake, type, or none")
    var mission: String
}

enum AlarmParserLLM {
    static func complete(
        text: String,
        now: Date,
        existing: [AlarmRecord],
        defaultMission: Mission?
    ) async -> [SpokenAlarmDraft] {
        let deterministic = AlarmParser.parse(text, now: now, existing: existing, defaultMission: defaultMission)
        if !deterministic.isEmpty { return deterministic }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, SystemLanguageModel.default.isAvailable else { return deterministic }
        let session = LanguageModelSession(instructions: """
        Extract every alarm from the sentence. Use 24-hour time. \
        If no mission is named, set mission to none. If no label is named, use Alarm.
        """)
        do {
            let response = try await session.respond(to: trimmed, generating: LLMAlarmBatch.self)
            let drafts = response.content.alarms.compactMap { item in
                draft(from: item, now: now, existing: existing, defaultMission: defaultMission)
            }
            return drafts.isEmpty ? deterministic : drafts
        } catch {
            return deterministic
        }
    }

    private static func draft(
        from item: LLMAlarmItem,
        now: Date,
        existing: [AlarmRecord],
        defaultMission: Mission?
    ) -> SpokenAlarmDraft? {
        guard (0...23).contains(item.hour), (0...59).contains(item.minute) else { return nil }
        let lowerDays = item.days.lowercased()
        var weekdays: [Weekday] = []
        var tomorrow = lowerDays.contains("tomorrow")
        if lowerDays.contains("weekday") {
            weekdays = Weekday.weekdays
            tomorrow = false
        } else if lowerDays.contains("weekend") {
            weekdays = Weekday.weekend
            tomorrow = false
        } else if !tomorrow {
            for word in lowerDays.split(whereSeparator: { !$0.isLetter }) {
                if let day = Weekday.parse(word: String(word)), !weekdays.contains(day) {
                    weekdays.append(day)
                }
            }
        }
        let mission = mission(named: item.mission, defaultMission: defaultMission)
        var oneShot: Date?
        if weekdays.isEmpty {
            oneShot = AlarmRecord.nextClockTime(hour: item.hour, minute: item.minute, weekday: nil, after: now, calendar: .current)
            if tomorrow, let base = oneShot, Calendar.current.isDateInToday(base) {
                oneShot = Calendar.current.date(byAdding: .day, value: 1, to: base)
            }
        }
        let candidate = AlarmRecord(
            id: UUID(),
            hour: item.hour,
            minute: item.minute,
            repeatDays: weekdays,
            oneShotDate: oneShot,
            label: item.label.isEmpty ? "Alarm" : item.label,
            sound: AlarmSound.radial.rawValue,
            snoozeEnabled: true,
            mission: mission.mission,
            seriesID: nil,
            isEnabled: true
        )
        let duplicate = existing.contains { $0.overlaps(candidate) }
        return SpokenAlarmDraft(
            id: candidate.id,
            hour: item.hour,
            minute: item.minute,
            repeatDays: weekdays,
            oneShotDate: oneShot,
            label: candidate.label,
            mission: mission.mission,
            usedDefaultMission: mission.usedDefault,
            isDuplicate: duplicate,
            include: !duplicate,
            seriesID: nil
        )
    }

    private static func mission(named: String, defaultMission: Mission?) -> (mission: Mission?, usedDefault: Bool) {
        switch named.lowercased() {
        case let value where value.contains("geometry"):
            return (.math(kind: .geometry, count: 3, difficulty: .medium), false)
        case let value where value.contains("math") || value.contains("arithmetic"):
            return (.math(kind: .arithmetic, count: 5, difficulty: .hard), false)
        case let value where value.contains("shake"):
            return (.shake(count: 40, strength: .firm), false)
        case let value where value.contains("type"):
            return (.type(text: Mission.defaultTypePhrase), false)
        case let value where value.contains("none"):
            return (nil, false)
        default:
            return (defaultMission, true)
        }
    }
}
