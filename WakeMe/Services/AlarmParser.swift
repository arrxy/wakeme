import Foundation

enum AlarmParser {
    static func parse(
        _ text: String,
        now: Date = .now,
        existing: [AlarmRecord] = [],
        defaultMission: Mission? = nil,
        calendar: Calendar = .current
    ) -> [SpokenAlarmDraft] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let series = parseSeries(trimmed, now: now, existing: existing, defaultMission: defaultMission, calendar: calendar)
        if !series.isEmpty { return series }
        let clauses = splitClauses(trimmed)
        return clauses.flatMap { clause in
            drafts(from: clause, now: now, existing: existing, defaultMission: defaultMission, calendar: calendar, seriesID: nil)
        }
    }

    static func highlightRanges(in text: String) -> [Range<String.Index>] {
        let patterns = [
            #"\d{1,2}:\d{2}"#,
            #"\b\d{1,2}\s*(?:a\.?m\.?|p\.?m\.?)\b"#,
            #"\b(?:tomorrow|today|weekdays?|weekends?|every day|daily|monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|tues|wed|thu|thur|thurs|fri|sat|sun)\b"#
        ]
        var ranges: [Range<String.Index>] = []
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            let ns = text as NSString
            for match in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
                if let range = Range(match.range, in: text) { ranges.append(range) }
            }
        }
        return ranges
    }

    private static func parseSeries(
        _ text: String,
        now: Date,
        existing: [AlarmRecord],
        defaultMission: Mission?,
        calendar: Calendar
    ) -> [SpokenAlarmDraft] {
        guard let span = seriesSpan(in: text) else { return [] }
        let gap = span.gap
        let start = span.start
        let end = span.end
        let slots = SeriesGenerator.slots(
            firstHour: start.hour,
            firstMinute: start.minute,
            lastHour: end.hour,
            lastMinute: end.minute,
            gapMinutes: gap
        )
        guard !slots.isEmpty else { return [] }
        let seriesID = UUID()
        let mission = mission(in: text, defaultMission: defaultMission)
        let days = days(in: text, now: now, calendar: calendar)
        return slots.map { slot in
            makeDraft(
                hour: slot.hour,
                minute: slot.minute,
                days: days,
                label: label(in: text),
                mission: mission,
                now: now,
                existing: existing,
                calendar: calendar,
                seriesID: seriesID
            )
        }
    }

    private static func splitClauses(_ text: String) -> [String] {
        let pattern = #"(?:,\s*)?\band\s+(?=set\b|a\s+\w+\s+alarm\b|an\s+\w+\s+alarm\b)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [text] }
        let ns = text as NSString
        var clauses: [String] = []
        var cursor = 0
        for match in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            let piece = ns.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
            if !piece.trimmingCharacters(in: .whitespaces).isEmpty { clauses.append(piece) }
            cursor = match.range.location + match.range.length
        }
        let tail = ns.substring(from: cursor)
        if !tail.trimmingCharacters(in: .whitespaces).isEmpty { clauses.append(tail) }
        return clauses.isEmpty ? [text] : clauses
    }

    private static func drafts(
        from clause: String,
        now: Date,
        existing: [AlarmRecord],
        defaultMission: Mission?,
        calendar: Calendar,
        seriesID: UUID?
    ) -> [SpokenAlarmDraft] {
        let times = times(in: clause)
        guard !times.isEmpty else { return [] }
        let dayPlan = days(in: clause, now: now, calendar: calendar)
        let chosenMission = mission(in: clause, defaultMission: defaultMission)
        let chosenLabel = label(in: clause)
        return times.map { time in
            makeDraft(
                hour: time.hour,
                minute: time.minute,
                days: dayPlan,
                label: chosenLabel,
                mission: chosenMission,
                now: now,
                existing: existing,
                calendar: calendar,
                seriesID: seriesID
            )
        }
    }

    private static func makeDraft(
        hour: Int,
        minute: Int,
        days: DayPlan,
        label: String,
        mission: (mission: Mission?, usedDefault: Bool),
        now: Date,
        existing: [AlarmRecord],
        calendar: Calendar,
        seriesID: UUID?
    ) -> SpokenAlarmDraft {
        var oneShot: Date?
        if days.weekdays.isEmpty {
            oneShot = AlarmRecord.nextClockTime(hour: hour, minute: minute, weekday: nil, after: now, calendar: calendar)
            if days.tomorrow, let base = oneShot, calendar.isDateInToday(base) {
                oneShot = calendar.date(byAdding: .day, value: 1, to: base)
            }
        }
        let candidate = AlarmRecord(
            id: UUID(),
            hour: hour,
            minute: minute,
            repeatDays: days.weekdays,
            oneShotDate: oneShot,
            label: label,
            sound: AlarmSound.radial.rawValue,
            snoozeEnabled: true,
            mission: mission.mission,
            seriesID: seriesID,
            isEnabled: true
        )
        let duplicate = existing.contains { $0.overlaps(candidate, calendar: calendar) }
        return SpokenAlarmDraft(
            id: candidate.id,
            hour: hour,
            minute: minute,
            repeatDays: days.weekdays,
            oneShotDate: oneShot,
            label: label,
            mission: mission.mission,
            usedDefaultMission: mission.usedDefault,
            isDuplicate: duplicate,
            include: !duplicate,
            seriesID: seriesID
        )
    }

    private struct ClockTime { var hour: Int; var minute: Int }
    private struct DayPlan { var weekdays: [Weekday]; var tomorrow: Bool }

    private static func seriesSpan(in text: String) -> (gap: Int, start: ClockTime, end: ClockTime)? {
        let patterns: [(String, Int, Int, Int)] = [
            (#"every\s+(\d+)\s+minutes?\s+from\s+(.+?)\s+to\s+(.+?)(?:$|\.|,)"#, 1, 2, 3),
            (#"from\s+(.+?)\s+to\s+(.+?)\s+(?:in\s+)?intervals?\s+of\s+(\d+)\s+minutes?"#, 3, 1, 2),
            (#"from\s+(.+?)\s+to\s+(.+?)\s+every\s+(\d+)\s+minutes?"#, 3, 1, 2),
            (#"(?:in\s+)?intervals?\s+of\s+(\d+)\s+minutes?\s+from\s+(.+?)\s+to\s+(.+?)(?:$|\.|,)"#, 1, 2, 3)
        ]
        for (pattern, gapGroup, startGroup, endGroup) in patterns {
            if let span = matchSeries(text, pattern: pattern, gapGroup: gapGroup, startGroup: startGroup, endGroup: endGroup) {
                return span
            }
        }
        return nil
    }

    private static func matchSeries(
        _ text: String,
        pattern: String,
        gapGroup: Int,
        startGroup: Int,
        endGroup: Int
    ) -> (gap: Int, start: ClockTime, end: ClockTime)? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let gapRange = Range(match.range(at: gapGroup), in: text),
              let startRange = Range(match.range(at: startGroup), in: text),
              let endRange = Range(match.range(at: endGroup), in: text),
              let gap = Int(text[gapRange]), gap > 0,
              let start = firstTime(in: String(text[startRange])),
              let end = firstTime(in: String(text[endRange]))
        else { return nil }
        return (gap, start, end)
    }

    private static func times(in text: String) -> [ClockTime] {
        let pattern = #"(?<![\d:])(\d{1,2})(?::(\d{2}))?(?:\s*(a\.?m\.?|p\.?m\.?))?"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let ns = text as NSString
        var found: [ClockTime] = []
        for match in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            guard let hourRange = Range(match.range(at: 1), in: text), let rawHour = Int(text[hourRange]) else { continue }
            if match.range.location > 0 {
                let previous = ns.substring(with: NSRange(location: match.range.location - 1, length: 1))
                if previous == ":" { continue }
            }
            var minute = 0
            if match.range(at: 2).location != NSNotFound, let minuteRange = Range(match.range(at: 2), in: text) {
                minute = Int(text[minuteRange]) ?? 0
            }
            var hour = rawHour
            var meridiem: String?
            if match.range(at: 3).location != NSNotFound, let meridiemRange = Range(match.range(at: 3), in: text) {
                meridiem = String(text[meridiemRange]).lowercased()
            }
            if minute > 59 || hour > 23 { continue }
            if let meridiem {
                let isPM = meridiem.hasPrefix("p")
                if hour > 12 { continue }
                if hour == 12 { hour = isPM ? 12 : 0 }
                else if isPM { hour += 12 }
            } else if hour <= 12 {
                if hour == 12 { hour = 12 }
                else if hour == 0 { hour = 0 }
            }
            if found.contains(where: { $0.hour == hour && $0.minute == minute }) { continue }
            let tail = ns.substring(from: match.range.location + match.range.length)
                .trimmingCharacters(in: .whitespaces)
                .lowercased()
            if tail.hasPrefix("minute") || tail.hasPrefix("question") || tail.hasPrefix("interval") { continue }
            found.append(ClockTime(hour: hour, minute: minute))
        }
        return found
    }

    private static func firstTime(in text: String) -> ClockTime? { times(in: text).first }

    private static func days(in text: String, now: Date, calendar: Calendar) -> DayPlan {
        let lower = text.lowercased()
        var weekdays: [Weekday] = []
        let tokens = lower.split { !$0.isLetter }
        for token in tokens {
            if let day = Weekday.parse(word: String(token)), !weekdays.contains(day) {
                weekdays.append(day)
            }
        }
        if lower.contains("weekday") { weekdays = Weekday.weekdays }
        if lower.contains("weekend") { weekdays = Weekday.weekend }
        if lower.contains("every day") || lower.contains("everyday") || lower.contains("daily") {
            weekdays = Weekday.allCases
        }
        let tomorrow = lower.contains("tomorrow")
        if tomorrow { weekdays = [] }
        return DayPlan(weekdays: weekdays, tomorrow: tomorrow)
    }

    private static func mission(in text: String, defaultMission: Mission?) -> (mission: Mission?, usedDefault: Bool) {
        let lower = text.lowercased()
        if lower.contains("geometry") || lower.contains("arithmetic") || lower.contains("math") {
            let kind: MathKind = lower.contains("geometry") && !lower.contains("arithmetic") ? .geometry : .arithmetic
            let fallbackCount = kind == .geometry ? 3 : 5
            let fallbackDifficulty: Difficulty = kind == .geometry ? .medium : .hard
            return (
                .math(
                    kind: kind,
                    count: questionCount(in: lower) ?? fallbackCount,
                    difficulty: namedDifficulty(in: lower) ?? fallbackDifficulty
                ),
                false
            )
        }
        if lower.contains("shake") {
            return (.shake(count: 40, strength: .firm), false)
        }
        if lower.contains("type") {
            return (.type(text: Mission.defaultTypePhrase), false)
        }
        return (defaultMission, true)
    }

    private static func questionCount(in text: String) -> Int? {
        let pattern = #"\b(\d+|one|two|three|four|five|six|seven|eight|nine|ten)\s+questions?\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text)
        else { return nil }
        let word = String(text[range]).lowercased()
        let words = ["one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10]
        let count = Int(word) ?? words[word]
        guard let count else { return nil }
        return min(max(count, 1), 10)
    }

    private static func namedDifficulty(in text: String) -> Difficulty? {
        let pattern = #"\b(easy|medium|hard|expert)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text)
        else { return nil }
        return Difficulty(rawValue: String(text[range]).lowercased())
    }

    private static func label(in text: String) -> String {
        let lower = text.lowercased()
        if lower.contains("gym") { return "Gym" }
        if lower.contains("exercise") || lower.contains("workout") { return "Exercise" }
        if lower.contains("work") { return "Work" }
        if lower.contains("wake") { return "Wake up" }
        if lower.contains("school") { return "School" }
        if lower.contains("medicine") || lower.range(of: #"\bmeds?\b"#, options: .regularExpression) != nil { return "Medicine" }
        return "Alarm"
    }
}
