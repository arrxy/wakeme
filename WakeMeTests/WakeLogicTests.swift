import XCTest
@testable import WakeMe

final class WakeLogicTests: XCTestCase {
    private var calendar: Calendar!
    private var now: Date!

    override func setUp() {
        super.setUp()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        self.calendar = calendar
        now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 14, hour: 15))!
    }

    func testCreateButtonSpacing() {
        XCTAssertEqual(SeriesGenerator.createButtonTitle(count: 7), "Create 7 alarms")
        XCTAssertEqual(SeriesGenerator.createButtonTitle(count: 1), "Create 1 alarm")
    }

    func testSeriesCrossesMidnight() {
        let slots = SeriesGenerator.slots(firstHour: 23, firstMinute: 30, lastHour: 0, lastMinute: 30, gapMinutes: 30)
        XCTAssertEqual(slots.map(\.label), ["11:30", "12:00", "12:30"])
    }

    func testTenMinuteSeriesCount() {
        let slots = SeriesGenerator.slots(firstHour: 6, firstMinute: 0, lastHour: 7, lastMinute: 0, gapMinutes: 10)
        XCTAssertEqual(slots.count, 7)
    }

    func testNextAlarmLine() {
        let record = AlarmRecord(id: UUID(), hour: 6, minute: 30, repeatDays: Weekday.weekdays, oneShotDate: nil, label: "Wake up", sound: "Radial", snoozeEnabled: true, mission: nil, seriesID: nil, isEnabled: true)
        let morning = calendar.date(from: DateComponents(year: 2026, month: 10, day: 15, hour: 0, minute: 0))!
        let line = AlarmRecord.nextAlarmLine(from: [record], now: morning, calendar: calendar)
        XCTAssertEqual(line, "Next alarm in 6 hr 30 min")
    }

    func testTypedPrefixStopsAtTypo() {
        let target = Mission.defaultTypePhrase
        XCTAssertEqual(target.count, 43)
        let wrong = String(target.prefix(23)) + "X"
        let progress = TypedPhrase.progress(typed: wrong, target: target)
        XCTAssertEqual(progress.correctCount, 23)
        XCTAssertEqual(progress.typoIndex, 24)
        XCTAssertFalse(progress.isComplete)
        let longer = wrong + "more"
        let stuck = TypedPhrase.progress(typed: longer, target: target)
        XCTAssertEqual(stuck.correctCount, 23)
        XCTAssertEqual(stuck.typoIndex, 24)
    }

    func testShakePeaksDebounceAndDecay() {
        var counter = ShakeCounter(target: 40, threshold: 2.4, debounce: 0.35, idleBeforeDecay: 5)
        let start = Date(timeIntervalSince1970: 1_000)
        counter.addSample(magnitude: 3, at: start)
        counter.addSample(magnitude: 3, at: start.addingTimeInterval(0.1))
        counter.addSample(magnitude: 3, at: start.addingTimeInterval(0.4))
        XCTAssertEqual(counter.count, 2)
        counter.addSample(magnitude: 0.2, at: start.addingTimeInterval(1))
        counter.decay(at: start.addingTimeInterval(5))
        XCTAssertEqual(counter.count, 2)
        counter.decay(at: start.addingTimeInterval(6))
        XCTAssertEqual(counter.count, 1)
        counter.decay(at: start.addingTimeInterval(7))
        XCTAssertEqual(counter.count, 0)
        counter.decay(at: start.addingTimeInterval(20))
        XCTAssertEqual(counter.count, 0)
    }

    func testMathDifficultiesStayInBounds() {
        var seed: UInt64 = 42
        for _ in 0..<30 {
            let easy = MathGenerator.question(kind: .arithmetic, difficulty: .easy, seed: &seed)
            XCTAssertFalse(easy.prompt.contains("×"))
            XCTAssertGreaterThanOrEqual(easy.answer, 0)
            let hard = MathGenerator.question(kind: .arithmetic, difficulty: .hard, seed: &seed)
            XCTAssertTrue(hard.prompt.contains("×"))
            let expert = MathGenerator.question(kind: .arithmetic, difficulty: .expert, seed: &seed)
            XCTAssertTrue(expert.prompt.contains("×"))
            XCTAssertTrue(expert.prompt.contains("+") || expert.prompt.contains("−"))
            let geometry = MathGenerator.question(kind: .geometry, difficulty: .medium, seed: &seed)
            XCTAssertGreaterThan(geometry.answer, 0)
        }
        let sample = MathGenerator.sample(kind: .arithmetic, difficulty: .hard)
        XCTAssertTrue(sample.contains("= ?"))
    }

    func testUnspecifiedMissionIsNone() {
        let drafts = AlarmParser.parse("wake me at 7:15", now: now, existing: [], calendar: calendar)
        XCTAssertEqual(drafts.count, 1)
        XCTAssertNil(drafts.first?.mission)
        XCTAssertEqual(drafts.first?.usedDefaultMission, true)
    }

    func testSnoozeCap() {
        XCTAssertTrue(RingPolicy.allowsSnooze(enabled: true, count: 2))
        XCTAssertFalse(RingPolicy.allowsSnooze(enabled: true, count: 3))
        XCTAssertFalse(RingPolicy.allowsSnooze(enabled: false, count: 0))
    }

    func testDesignUtteranceAndDuplicate() {
        let existing = AlarmRecord(
            id: UUID(), hour: 5, minute: 45,
            repeatDays: [.monday, .wednesday, .friday],
            oneShotDate: nil, label: "Gym", sound: "Radial",
            snoozeEnabled: true, mission: .math(kind: .geometry, count: 3, difficulty: .medium),
            seriesID: nil, isEnabled: true
        )
        let text = "Wake me up at 6, 6:15 and 6:30 tomorrow with a math mission, and set a gym alarm at 5:45 on Monday, Wednesday and Friday"
        let drafts = AlarmParser.parse(text, now: now, existing: [existing], defaultMission: .defaultWake, calendar: calendar)
        XCTAssertEqual(drafts.count, 4)
        XCTAssertEqual(drafts[0].label, "Wake up")
        XCTAssertEqual(drafts[0].hour, 6)
        XCTAssertEqual(drafts[0].minute, 0)
        XCTAssertEqual(drafts[1].minute, 15)
        XCTAssertEqual(drafts[2].minute, 30)
        XCTAssertEqual(drafts[0].mission, .math(kind: .arithmetic, count: 5, difficulty: .hard))
        XCTAssertFalse(drafts[0].usedDefaultMission)
        XCTAssertTrue(drafts[0].repeatDays.isEmpty)
        XCTAssertEqual(drafts[3].label, "Gym")
        XCTAssertEqual(drafts[3].repeatDays, [.monday, .wednesday, .friday])
        XCTAssertTrue(drafts[3].usedDefaultMission)
        XCTAssertEqual(drafts[3].mission?.summary, "Arithmetic, 5 Q, hard")
        XCTAssertTrue(drafts[3].isDuplicate)
        XCTAssertFalse(drafts[3].include)
    }

    func testSeriesPhrase() {
        let drafts = AlarmParser.parse("every 10 minutes from 6 to 7 on weekdays", now: now, existing: [], calendar: calendar)
        XCTAssertEqual(drafts.count, 7)
        XCTAssertEqual(Set(drafts.compactMap(\.seriesID)).count, 1)
        XCTAssertEqual(drafts.first?.repeatDays, Weekday.weekdays)
    }

    func testPhraseTableHasAtLeastOneHundred() {
        let table = phraseTable()
        XCTAssertGreaterThanOrEqual(table.count, 100)
        for row in table {
            let drafts = AlarmParser.parse(row.phrase, now: now, existing: [], defaultMission: .defaultWake, calendar: calendar)
            XCTAssertEqual(drafts.count, row.count, row.phrase)
            if let hour = row.hour { XCTAssertEqual(drafts.first?.hour, hour, row.phrase) }
            if let minute = row.minute { XCTAssertEqual(drafts.first?.minute, minute, row.phrase) }
            if let label = row.label { XCTAssertEqual(drafts.first?.label, label, row.phrase) }
        }
    }

    private struct PhraseRow {
        var phrase: String
        var count: Int
        var hour: Int?
        var minute: Int?
        var label: String?
    }

    private func phraseTable() -> [PhraseRow] {
        var rows: [PhraseRow] = []
        for hour in [5, 6, 7, 8, 9] {
            for minute in [0, 15, 30, 45] {
                let stamp = "\(hour):\(String(format: "%02d", minute))"
                rows.append(PhraseRow(phrase: "wake me up at \(stamp)", count: 1, hour: hour, minute: minute, label: "Wake up"))
                rows.append(PhraseRow(phrase: "set an alarm for \(stamp) am", count: 1, hour: hour, minute: minute, label: "Alarm"))
            }
        }
        for day in ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"] {
            rows.append(PhraseRow(phrase: "alarm at 7 on \(day)", count: 1, hour: 7, minute: 0, label: "Alarm"))
            rows.append(PhraseRow(phrase: "gym alarm at 5:45 on \(day)", count: 1, hour: 5, minute: 45, label: "Gym"))
        }
        for hour in [1, 2, 3, 4, 10, 11] {
            rows.append(PhraseRow(phrase: "alarm at \(hour) am", count: 1, hour: hour, minute: 0, label: "Alarm"))
            rows.append(PhraseRow(phrase: "work alarm at \(hour):30 pm", count: 1, hour: hour + 12, minute: 30, label: "Work"))
        }
        for minute in [5, 10, 20, 25, 35, 40, 50, 55] {
            rows.append(PhraseRow(phrase: "wake me up at 6:\(String(format: "%02d", minute))", count: 1, hour: 6, minute: minute, label: "Wake up"))
        }
        rows.append(contentsOf: [
            PhraseRow(phrase: "weekdays at 6:30", count: 1, hour: 6, minute: 30, label: "Alarm"),
            PhraseRow(phrase: "every weekday at 6:30 am", count: 1, hour: 6, minute: 30, label: "Alarm"),
            PhraseRow(phrase: "weekends at 9", count: 1, hour: 9, minute: 0, label: "Alarm"),
            PhraseRow(phrase: "every day at 8", count: 1, hour: 8, minute: 0, label: "Alarm"),
            PhraseRow(phrase: "daily alarm at 7:15", count: 1, hour: 7, minute: 15, label: "Alarm"),
            PhraseRow(phrase: "tomorrow at 6:30", count: 1, hour: 6, minute: 30, label: "Alarm"),
            PhraseRow(phrase: "wake me tomorrow at 5", count: 1, hour: 5, minute: 0, label: "Wake up"),
            PhraseRow(phrase: "set a work alarm at 9:00 am", count: 1, hour: 9, minute: 0, label: "Work"),
            PhraseRow(phrase: "school alarm at 7:45", count: 1, hour: 7, minute: 45, label: "School"),
            PhraseRow(phrase: "medicine at 8:00", count: 1, hour: 8, minute: 0, label: "Medicine"),
            PhraseRow(phrase: "6, 6:15 and 6:30", count: 3, hour: 6, minute: 0, label: "Alarm"),
            PhraseRow(phrase: "wake me up at 6 and 6:30", count: 2, hour: 6, minute: 0, label: "Wake up"),
            PhraseRow(phrase: "at 7, 7:10 and 7:20 with a math mission", count: 3, hour: 7, minute: 0, label: "Alarm"),
            PhraseRow(phrase: "shake mission at 8:15 on weekends", count: 1, hour: 8, minute: 15, label: "Alarm"),
            PhraseRow(phrase: "geometry at 5:45 on monday", count: 1, hour: 5, minute: 45, label: "Alarm"),
            PhraseRow(phrase: "type mission at 9 tomorrow", count: 1, hour: 9, minute: 0, label: "Alarm"),
            PhraseRow(phrase: "every 10 minutes from 6 to 7", count: 7, hour: 6, minute: 0, label: "Alarm"),
            PhraseRow(phrase: "every 15 minutes from 6:00 am to 7:00 am", count: 5, hour: 6, minute: 0, label: "Alarm"),
            PhraseRow(phrase: "every 5 minutes from 8 to 8:20", count: 5, hour: 8, minute: 0, label: "Alarm"),
            PhraseRow(phrase: "gym at 6 pm", count: 1, hour: 18, minute: 0, label: "Gym"),
            PhraseRow(phrase: "wake me up at 6:30pm", count: 1, hour: 18, minute: 30, label: "Wake up"),
            PhraseRow(phrase: "alarm at 4:10", count: 1, hour: 4, minute: 10, label: "Alarm"),
            PhraseRow(phrase: "wake me up at 11:45", count: 1, hour: 11, minute: 45, label: "Wake up"),
            PhraseRow(phrase: "set an alarm for 12:15 pm", count: 1, hour: 12, minute: 15, label: "Alarm"),
            PhraseRow(phrase: "tomorrow at 8:20", count: 1, hour: 8, minute: 20, label: "Alarm"),
            PhraseRow(phrase: "work alarm at 2:05 pm", count: 1, hour: 14, minute: 5, label: "Work")
        ])
        return rows
    }

    func testFakeSchedulerRecordsEnabledUpsertCancelAndMission() async throws {
        let scheduler = FakeAlarmScheduler()
        scheduler.ignoreSnooze = true
        let record = AlarmRecord(
            id: UUID(), hour: 7, minute: 0, repeatDays: [], oneShotDate: nil,
            label: "Alarm", sound: "Radial", snoozeEnabled: true, mission: nil,
            seriesID: nil, isEnabled: true
        )
        try await scheduler.upsert(record)
        XCTAssertEqual(scheduler.upsertedIDs, [record.id])
        try await scheduler.cancel(id: record.id)
        XCTAssertEqual(scheduler.cancelledIDs, [record.id])
        let alertID = UUID()
        try await scheduler.snooze(alertID: alertID, parentID: record.id)
        XCTAssertTrue(scheduler.snoozed.isEmpty)
        XCTAssertFalse(RingPolicy.allowsSnooze(enabled: true, count: 3))
        XCTAssertTrue(RingPolicy.allowsSnooze(enabled: true, count: 2))
        try await scheduler.startMission(alertID: alertID, parentID: record.id)
        XCTAssertEqual(scheduler.missionParentIDs, [record.id])
    }
}

private final class FakeAlarmScheduler: AlarmScheduler {
    var ignoreSnooze = false
    var upsertedIDs: [UUID] = []
    var cancelledIDs: [UUID] = []
    var missionParentIDs: [UUID] = []
    var snoozed: [(alertID: UUID, parentID: UUID)] = []
    var stopped: [(alertID: UUID, parentID: UUID)] = []

    func authorizationState() -> AlarmAuthorization { .authorized }
    func requestAuthorization() async throws -> AlarmAuthorization { .authorized }

    func upsert(_ record: AlarmRecord) async throws {
        guard record.isEnabled else { return }
        upsertedIDs.append(record.id)
    }

    func cancel(id: UUID) async throws {
        cancelledIDs.append(id)
    }

    func startMission(alertID: UUID, parentID: UUID) async throws {
        missionParentIDs.append(parentID)
    }

    func snooze(alertID: UUID, parentID: UUID) async throws {
        if ignoreSnooze { return }
        snoozed.append((alertID, parentID))
    }

    func stopAlert(alertID: UUID, parentID: UUID) async throws {
        stopped.append((alertID, parentID))
    }

    func scheduleTimer(id: UUID, duration: TimeInterval, label: String) async throws {}
    func pauseTimer(id: UUID) async throws {}
    func resumeTimer(id: UUID) async throws {}
    func cancelTimer(id: UUID) async throws {}
}
