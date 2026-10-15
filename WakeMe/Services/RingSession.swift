import Foundation

enum AppGroup {
    static let identifier = "group.com.wakeme.shared"
}

struct RingSnapshot: Codable, Sendable {
    var records: [UUID: AlarmRecord] = [:]
    var pendingParentID: UUID?
    var backupID: UUID?
    var snoozeCounts: [UUID: Int] = [:]
}

enum RingSession {
    private static let key = "wakeme.ring.snapshot"
    private static let lock = NSLock()

    static func read() -> RingSnapshot {
        lock.lock()
        defer { lock.unlock() }
        guard let data = defaults.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(RingSnapshot.self, from: data) else {
            return RingSnapshot()
        }
        return snapshot
    }

    static func update(_ body: (inout RingSnapshot) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        var snapshot = RingSnapshot()
        if let data = defaults.data(forKey: key),
           let stored = try? JSONDecoder().decode(RingSnapshot.self, from: data) {
            snapshot = stored
        }
        body(&snapshot)
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: key)
        }
    }

    static func save(_ record: AlarmRecord) {
        update { $0.records[record.id] = record }
    }

    static func record(_ id: UUID) -> AlarmRecord? { read().records[id] }

    static func snoozeCount(_ id: UUID) -> Int { read().snoozeCounts[id] ?? 0 }

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: AppGroup.identifier) ?? .standard
    }
}
