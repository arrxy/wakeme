import ActivityKit
import AlarmKit
import AppIntents
import Foundation

struct AlarmKitScheduler: AlarmScheduler, Sendable {
    func authorizationState() -> AlarmAuthorization {
        switch AlarmManager.shared.authorizationState {
        case .notDetermined: .notDetermined
        case .denied: .denied
        case .authorized: .authorized
        @unknown default: .denied
        }
    }

    func requestAuthorization() async throws -> AlarmAuthorization {
        switch try await AlarmManager.shared.requestAuthorization() {
        case .notDetermined: .notDetermined
        case .denied: .denied
        case .authorized: .authorized
        @unknown default: .denied
        }
    }

    func upsert(_ record: AlarmRecord) async throws {
        RingSession.save(record)
        if record.isEnabled {
            try await schedule(record, identifier: record.id, fireDate: nil, allowsSnooze: RingPolicy.allowsSnooze(enabled: record.snoozeEnabled, count: RingSession.snoozeCount(record.id)))
        } else {
            try? AlarmManager.shared.cancel(id: record.id)
        }
    }

    func cancel(id: UUID) async throws {
        try AlarmManager.shared.cancel(id: id)
        RingSession.update { snapshot in
            snapshot.records[id] = nil
            if snapshot.backupID != nil { }
            snapshot.snoozeCounts[id] = nil
        }
    }

    func startMission(alertID: UUID, parentID: UUID) async throws {
        let parent = RingSession.record(parentID)
        try? AlarmManager.shared.stop(id: alertID)
        if alertID != parentID { try? AlarmManager.shared.cancel(id: alertID) }
        if let parent, parent.isRepeating {
            try await restoreRecurrenceIfMissing(parent)
        }
        guard let parent, parent.mission != nil else { return }
        RingSession.update { $0.pendingParentID = parentID }
        if let existing = RingSession.read().backupID {
            try? AlarmManager.shared.cancel(id: existing)
        }
        let backupID = UUID()
        RingSession.update { $0.backupID = backupID }
        var backup = parent
        backup.id = backupID
        backup.repeatDays = []
        backup.oneShotDate = Date().addingTimeInterval(RingPolicy.backupDelay)
        backup.seriesID = nil
        try await schedule(backup, identifier: backupID, fireDate: backup.oneShotDate, allowsSnooze: RingPolicy.allowsSnooze(enabled: parent.snoozeEnabled, count: RingSession.snoozeCount(parentID)), parentID: parentID)
    }

    func snooze(alertID: UUID, parentID: UUID) async throws {
        guard let parent = RingSession.record(parentID) else { return }
        let count = RingSession.snoozeCount(parentID) + 1
        guard RingPolicy.allowsSnooze(enabled: parent.snoozeEnabled, count: count - 1) else { return }
        try? AlarmManager.shared.stop(id: alertID)
        if alertID != parentID { try? AlarmManager.shared.cancel(id: alertID) }
        if let backup = RingSession.read().backupID {
            try? AlarmManager.shared.cancel(id: backup)
        }
        RingSession.update {
            $0.pendingParentID = nil
            $0.backupID = nil
            $0.snoozeCounts[parentID] = count
        }
        if parent.isRepeating {
            try await restoreRecurrenceIfMissing(parent)
        }
        let snoozeID = UUID()
        var snooze = parent
        snooze.id = snoozeID
        snooze.repeatDays = []
        snooze.oneShotDate = Date().addingTimeInterval(RingPolicy.snoozeDuration)
        try await schedule(
            snooze,
            identifier: snoozeID,
            fireDate: snooze.oneShotDate,
            allowsSnooze: RingPolicy.allowsSnooze(enabled: true, count: count),
            parentID: parentID
        )
    }

    func stopAlert(alertID: UUID, parentID: UUID) async throws {
        try? AlarmManager.shared.stop(id: alertID)
        if alertID != parentID { try? AlarmManager.shared.cancel(id: alertID) }
        if let backup = RingSession.read().backupID, backup == alertID {
            RingSession.update { $0.backupID = nil }
        }
        if let parent = RingSession.record(parentID), parent.isRepeating, alertID == parentID {
            try await restoreRecurrenceIfMissing(parent)
        }
        RingSession.update {
            $0.pendingParentID = nil
            if $0.backupID == alertID { $0.backupID = nil }
            $0.snoozeCounts[parentID] = nil
        }
    }

    func scheduleTimer(id: UUID, duration: TimeInterval, label: String) async throws {
        let attributes = AlarmAttributes<WakeMetadata>(
            presentation: AlarmPresentation(
                alert: AlarmPresentation.Alert(
                    title: LocalizedStringResource(stringLiteral: label),
                    stopButton: AlarmButton(text: "Stop", textColor: .white, systemImageName: "stop.fill")
                ),
                countdown: AlarmPresentation.Countdown(
                    title: LocalizedStringResource(stringLiteral: label),
                    pauseButton: AlarmButton(text: "Pause", textColor: .white, systemImageName: "pause.fill")
                ),
                paused: AlarmPresentation.Paused(
                    title: LocalizedStringResource(stringLiteral: label),
                    resumeButton: AlarmButton(text: "Resume", textColor: .white, systemImageName: "play.fill")
                )
            ),
            metadata: WakeMetadata(parentID: id, label: label, hasMission: false),
            tintColor: .orange
        )
        let configuration = AlarmManager.AlarmConfiguration(
            countdownDuration: AlarmKit.Alarm.CountdownDuration(preAlert: duration, postAlert: nil),
            schedule: nil,
            attributes: attributes,
            stopIntent: StopAlarmIntent(alertID: id, parentID: id),
            sound: .default
        )
        _ = try await AlarmManager.shared.schedule(id: id, configuration: configuration)
    }

    func pauseTimer(id: UUID) async throws { try AlarmManager.shared.pause(id: id) }
    func resumeTimer(id: UUID) async throws { try AlarmManager.shared.resume(id: id) }
    func cancelTimer(id: UUID) async throws { try AlarmManager.shared.cancel(id: id) }

    private func schedule(_ record: AlarmRecord, identifier: UUID, fireDate: Date?, allowsSnooze: Bool, parentID: UUID? = nil) async throws {
        let parent = parentID ?? record.id
        let kind = AlarmScheduleMapping.kind(for: record, fireDate: fireDate)
        let schedule: AlarmKit.Alarm.Schedule
        switch kind {
        case let .fixed(date):
            schedule = .fixed(date)
        case let .weekly(hour, minute, days):
            schedule = .relative(AlarmKit.Alarm.Schedule.Relative(
                time: AlarmKit.Alarm.Schedule.Relative.Time(hour: hour, minute: minute),
                repeats: .weekly(days.map(\.localeWeekday))
            ))
        }
        let secondary: AlarmButton? = allowsSnooze
            ? AlarmButton(text: "Snooze", textColor: .white, systemImageName: "zzz")
            : nil
        let stopTitle: LocalizedStringResource = record.mission == nil ? "Stop" : "Start mission"
        let alert = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: record.label),
            stopButton: AlarmButton(text: stopTitle, textColor: .white, systemImageName: record.mission == nil ? "stop.fill" : "flag.fill"),
            secondaryButton: secondary,
            secondaryButtonBehavior: secondary == nil ? nil : .custom
        )
        let attributes = AlarmAttributes<WakeMetadata>(
            presentation: AlarmPresentation(alert: alert),
            metadata: WakeMetadata(parentID: parent, label: record.label, hasMission: record.mission != nil),
            tintColor: .orange
        )
        let stopIntent: any LiveActivityIntent = record.mission == nil
            ? StopAlarmIntent(alertID: identifier, parentID: parent)
            : StartMissionIntent(alertID: identifier, parentID: parent)
        let configuration = AlarmManager.AlarmConfiguration<WakeMetadata>(
            countdownDuration: nil,
            schedule: schedule,
            attributes: attributes,
            stopIntent: stopIntent,
            secondaryIntent: allowsSnooze ? SnoozeAlarmIntent(alertID: identifier, parentID: parent) : nil,
            sound: .named(record.soundFile)
        )
        _ = try await AlarmManager.shared.schedule(id: identifier, configuration: configuration)
    }

    private func restoreRecurrenceIfMissing(_ record: AlarmRecord) async throws {
        let alarms = try AlarmManager.shared.alarms
        if alarms.contains(where: { $0.id == record.id }) { return }
        try await schedule(
            record,
            identifier: record.id,
            fireDate: nil,
            allowsSnooze: RingPolicy.allowsSnooze(enabled: record.snoozeEnabled, count: RingSession.snoozeCount(record.id))
        )
    }
}
