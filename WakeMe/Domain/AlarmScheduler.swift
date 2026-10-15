import Foundation

enum AlarmAuthorization: String, Sendable {
    case notDetermined
    case denied
    case authorized
}

protocol AlarmScheduler: Sendable {
    func authorizationState() -> AlarmAuthorization
    func requestAuthorization() async throws -> AlarmAuthorization
    func upsert(_ record: AlarmRecord) async throws
    func cancel(id: UUID) async throws
    func startMission(alertID: UUID, parentID: UUID) async throws
    func snooze(alertID: UUID, parentID: UUID) async throws
    func stopAlert(alertID: UUID, parentID: UUID) async throws
    func scheduleTimer(id: UUID, duration: TimeInterval, label: String) async throws
    func pauseTimer(id: UUID) async throws
    func resumeTimer(id: UUID) async throws
    func cancelTimer(id: UUID) async throws
}
