import Foundation
import SwiftData

@MainActor
enum AlarmStore {
    static func upsert(_ record: AlarmRecord, in context: ModelContext) throws {
        var stored = record
        if stored.repeatDays.isEmpty, stored.oneShotDate == nil {
            stored.oneShotDate = stored.nextFireDate(after: .now)
        }
        let identifier = stored.id
        let descriptor = FetchDescriptor<Alarm>(predicate: #Predicate { $0.id == identifier })
        if let existing = try context.fetch(descriptor).first {
            existing.apply(stored)
        } else {
            context.insert(stored.makeModel())
        }
        try context.save()
        RingSession.save(stored)
    }

    static func delete(id: UUID, in context: ModelContext) throws {
        let identifier = id
        let descriptor = FetchDescriptor<Alarm>(predicate: #Predicate { $0.id == identifier })
        for alarm in try context.fetch(descriptor) {
            context.delete(alarm)
        }
        try context.save()
    }

    static func settings(in context: ModelContext) throws -> AppSettings {
        if let existing = try context.fetch(FetchDescriptor<AppSettings>()).first {
            return existing
        }
        let created = AppSettings()
        context.insert(created)
        try context.save()
        return created
    }
}

@MainActor
enum AlarmScheduling {
    private static let scheduler: any AlarmScheduler = AlarmKitScheduler()

    static func authorization() -> AlarmAuthorization { scheduler.authorizationState() }

    static func requestAuthorization() async -> AlarmAuthorization {
        do {
            return try await scheduler.requestAuthorization()
        } catch {
            return scheduler.authorizationState()
        }
    }

    static func upsert(_ record: AlarmRecord) async {
        guard record.isEnabled else {
            try? await scheduler.cancel(id: record.id)
            return
        }
        guard authorization() == .authorized else { return }
        try? await scheduler.upsert(record)
    }

    static func remove(id: UUID) async {
        try? await scheduler.cancel(id: id)
    }

    static func finishMission(parentID: UUID) async {
        if let backup = RingSession.read().backupID {
            try? await scheduler.cancel(id: backup)
        }
        RingSession.update {
            $0.pendingParentID = nil
            $0.backupID = nil
            $0.snoozeCounts[parentID] = nil
        }
    }

    static func snoozeMission(parentID: UUID) async {
        let alert = RingSession.read().backupID ?? parentID
        try? await scheduler.snooze(alertID: alert, parentID: parentID)
    }

    static func scheduleTimer(id: UUID, duration: TimeInterval, label: String) async throws {
        guard authorization() == .authorized else { return }
        try await scheduler.scheduleTimer(id: id, duration: duration, label: label)
    }

    static func pauseTimer(id: UUID) async { try? await scheduler.pauseTimer(id: id) }
    static func resumeTimer(id: UUID) async { try? await scheduler.resumeTimer(id: id) }
    static func cancelTimer(id: UUID) async { try? await scheduler.cancelTimer(id: id) }
}
