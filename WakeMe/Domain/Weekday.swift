import Foundation

enum Weekday: Int, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case sunday = 1
    case monday
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday

    var id: Int { rawValue }

    var shortName: String {
        switch self {
        case .sunday: "Sun"
        case .monday: "Mon"
        case .tuesday: "Tue"
        case .wednesday: "Wed"
        case .thursday: "Thu"
        case .friday: "Fri"
        case .saturday: "Sat"
        }
    }

    var fullName: String {
        switch self {
        case .sunday: "Sunday"
        case .monday: "Monday"
        case .tuesday: "Tuesday"
        case .wednesday: "Wednesday"
        case .thursday: "Thursday"
        case .friday: "Friday"
        case .saturday: "Saturday"
        }
    }

    var localeWeekday: Locale.Weekday {
        switch self {
        case .sunday: .sunday
        case .monday: .monday
        case .tuesday: .tuesday
        case .wednesday: .wednesday
        case .thursday: .thursday
        case .friday: .friday
        case .saturday: .saturday
        }
    }

    static let weekdays: [Weekday] = [.monday, .tuesday, .wednesday, .thursday, .friday]
    static let weekend: [Weekday] = [.saturday, .sunday]

    static func parse(word: String) -> Weekday? {
        switch word.lowercased() {
        case "sunday", "sun": .sunday
        case "monday", "mon": .monday
        case "tuesday", "tue", "tues": .tuesday
        case "wednesday", "wed": .wednesday
        case "thursday", "thu", "thur", "thurs": .thursday
        case "friday", "fri": .friday
        case "saturday", "sat": .saturday
        default: nil
        }
    }
}
