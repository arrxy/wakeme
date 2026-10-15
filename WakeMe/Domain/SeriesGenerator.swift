import Foundation

enum SeriesGenerator {
    struct Slot: Equatable, Identifiable, Sendable {
        var hour: Int
        var minute: Int
        var id: String { "\(hour):\(minute)" }

        var label: String {
            let twelve = hour % 12 == 0 ? 12 : hour % 12
            return "\(twelve):\(String(format: "%02d", minute))"
        }
    }

    static func slots(firstHour: Int, firstMinute: Int, lastHour: Int, lastMinute: Int, gapMinutes: Int) -> [Slot] {
        let gap = max(gapMinutes, 1)
        let start = firstHour * 60 + firstMinute
        var end = lastHour * 60 + lastMinute
        if end < start { end += 24 * 60 }
        var slots: [Slot] = []
        var cursor = start
        while cursor <= end {
            let wrapped = cursor % (24 * 60)
            slots.append(Slot(hour: wrapped / 60, minute: wrapped % 60))
            cursor += gap
            if slots.count > 288 { break }
        }
        return slots
    }

    static func createButtonTitle(count: Int) -> String {
        count == 1 ? "Create 1 alarm" : "Create \(count) alarms"
    }
}
