import AlarmKit
import Foundation

struct WakeMetadata: AlarmMetadata {
    var parentID: String
    var label: String
    var hasMission: Bool

    init(parentID: UUID, label: String, hasMission: Bool) {
        self.parentID = parentID.uuidString
        self.label = label
        self.hasMission = hasMission
    }
}
