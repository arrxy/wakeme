import AlarmKit
import AppIntents
import Foundation

struct StartMissionIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Start mission"
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Alert")
    var alertID: String

    @Parameter(title: "Parent")
    var parentID: String

    init() {
        alertID = ""
        parentID = ""
    }

    init(alertID: UUID, parentID: UUID) {
        self.alertID = alertID.uuidString
        self.parentID = parentID.uuidString
    }

    func perform() async throws -> some IntentResult {
        guard let alert = UUID(uuidString: alertID), let parent = UUID(uuidString: parentID) else { return .result() }
        try await AlarmKitScheduler().startMission(alertID: alert, parentID: parent)
        return .result()
    }
}

struct SnoozeAlarmIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Snooze"
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Alert")
    var alertID: String

    @Parameter(title: "Parent")
    var parentID: String

    init() {
        alertID = ""
        parentID = ""
    }

    init(alertID: UUID, parentID: UUID) {
        self.alertID = alertID.uuidString
        self.parentID = parentID.uuidString
    }

    func perform() async throws -> some IntentResult {
        guard let alert = UUID(uuidString: alertID), let parent = UUID(uuidString: parentID) else { return .result() }
        try await AlarmKitScheduler().snooze(alertID: alert, parentID: parent)
        return .result()
    }
}

struct StopAlarmIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Stop"
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Alert")
    var alertID: String

    @Parameter(title: "Parent")
    var parentID: String

    init() {
        alertID = ""
        parentID = ""
    }

    init(alertID: UUID, parentID: UUID) {
        self.alertID = alertID.uuidString
        self.parentID = parentID.uuidString
    }

    func perform() async throws -> some IntentResult {
        guard let alert = UUID(uuidString: alertID), let parent = UUID(uuidString: parentID) else { return .result() }
        try await AlarmKitScheduler().stopAlert(alertID: alert, parentID: parent)
        return .result()
    }
}
