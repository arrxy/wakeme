import Foundation

struct AlarmRecord: Codable, Equatable, Identifiable, Hashable, Sendable {
    var id: UUID
    var hour: Int
    var minute: Int
    var repeatDays: [Weekday]
    var oneShotDate: Date?
    var label: String
    var sound: String
    var snoozeEnabled: Bool
    var mission: Mission?
    var seriesID: UUID?
    var isEnabled: Bool

    var isRepeating: Bool { !repeatDays.isEmpty }

    var soundFile: String { AlarmSound.named(sound).fileName }

    var hourText: String {
        let twelve = hour % 12 == 0 ? 12 : hour % 12
        return "\(twelve):\(String(format: "%02d", minute))"
    }

    var periodText: String { hour < 12 ? "AM" : "PM" }

    var repeatSummary: String {
        let days = repeatDays.sorted { $0.rawValue < $1.rawValue }
        if days.isEmpty { return oneShotPhrase() }
        if days == Weekday.allCases { return "every day" }
        if days == Weekday.weekdays { return "weekdays" }
        if days == Weekday.weekend { return "weekends" }
        return days.map(\.shortName).joined(separator: " ")
    }

    var subtitle: String {
        let when = repeatSummary
        if label.isEmpty { return when }
        if when.isEmpty { return label }
        return "\(label), \(when)"
    }

    func nextFireDate(after now: Date = .now, calendar: Calendar = .current) -> Date? {
        guard isEnabled else { return nil }
        if repeatDays.isEmpty {
            if let oneShotDate { return oneShotDate > now ? oneShotDate : nil }
            return Self.nextClockTime(hour: hour, minute: minute, weekday: nil, after: now, calendar: calendar)
        }
        return repeatDays
            .compactMap { Self.nextClockTime(hour: hour, minute: minute, weekday: $0, after: now, calendar: calendar) }
            .min()
    }

    static func nextClockTime(hour: Int, minute: Int, weekday: Weekday?, after now: Date, calendar: Calendar) -> Date? {
        var parts = calendar.dateComponents([.year, .month, .day], from: now)
        parts.hour = hour
        parts.minute = minute
        parts.second = 0
        guard var candidate = calendar.date(from: parts) else { return nil }
        if let weekday {
            let wanted = weekday.rawValue
            let current = calendar.component(.weekday, from: candidate)
            var delta = (wanted - current + 7) % 7
            if delta == 0, candidate <= now { delta = 7 }
            candidate = calendar.date(byAdding: .day, value: delta, to: candidate) ?? candidate
        } else if candidate <= now {
            candidate = calendar.date(byAdding: .day, value: 1, to: candidate) ?? candidate
        }
        return candidate
    }

    static func nextAlarmLine(from records: [AlarmRecord], now: Date = .now, calendar: Calendar = .current) -> String {
        let upcoming = records.compactMap { record -> Date? in
            record.nextFireDate(after: now, calendar: calendar)
        }
        guard let next = upcoming.min() else { return "No upcoming alarm" }
        let parts = calendar.dateComponents([.day, .hour, .minute], from: now, to: next)
        let days = parts.day ?? 0
        let hours = (parts.hour ?? 0) + days * 24
        let minutes = parts.minute ?? 0
        switch (hours, minutes) {
        case (0, 0): return "Next alarm in less than a minute"
        case (0, let minute): return "Next alarm in \(minute) min"
        case (let hour, 0): return "Next alarm in \(hour) hr"
        default: return "Next alarm in \(hours) hr \(minutes) min"
        }
    }

    static func newDraft(now: Date = .now, calendar: Calendar = .current) -> AlarmRecord {
        let parts = calendar.dateComponents([.hour, .minute], from: now)
        var hour = parts.hour ?? 7
        var minute = ((parts.minute ?? 0) / 5 + 1) * 5
        if minute >= 60 {
            minute = 0
            hour = (hour + 1) % 24
        }
        return AlarmRecord(
            id: UUID(),
            hour: hour,
            minute: minute,
            repeatDays: [],
            oneShotDate: nil,
            label: "Alarm",
            sound: AlarmSound.radial.rawValue,
            snoozeEnabled: true,
            mission: nil,
            seriesID: nil,
            isEnabled: true
        )
    }

    func overlaps(_ other: AlarmRecord, calendar: Calendar = .current) -> Bool {
        guard hour == other.hour, minute == other.minute else { return false }
        if isRepeating, other.isRepeating {
            return !Set(repeatDays).isDisjoint(with: other.repeatDays)
        }
        if isRepeating || other.isRepeating {
            let repeating = isRepeating ? self : other
            let once = isRepeating ? other : self
            guard let date = once.oneShotDate ?? once.nextFireDate(after: .distantPast, calendar: calendar) else { return false }
            let weekday = Weekday(rawValue: calendar.component(.weekday, from: date))
            return weekday.map { repeating.repeatDays.contains($0) } ?? false
        }
        guard let lhs = oneShotDate, let rhs = other.oneShotDate else { return true }
        return calendar.isDate(lhs, inSameDayAs: rhs)
    }

    private func oneShotPhrase(calendar: Calendar = .current, now: Date = .now) -> String {
        guard let oneShotDate else { return "once" }
        if calendar.isDateInTomorrow(oneShotDate) { return "tomorrow" }
        if calendar.isDateInToday(oneShotDate) { return "today" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: oneShotDate)
    }
}

enum ScheduleKind: Equatable, Sendable {
    case fixed(Date)
    case weekly(hour: Int, minute: Int, days: [Weekday])
}

enum AlarmScheduleMapping {
    static func kind(for record: AlarmRecord, fireDate: Date?, now: Date = .now) -> ScheduleKind {
        if record.repeatDays.isEmpty {
            let date = fireDate
                ?? record.oneShotDate
                ?? AlarmRecord.nextClockTime(hour: record.hour, minute: record.minute, weekday: nil, after: now, calendar: .current)
                ?? now.addingTimeInterval(60)
            return .fixed(date)
        }
        return .weekly(hour: record.hour, minute: record.minute, days: record.repeatDays)
    }
}
