import SwiftData
import SwiftUI

@main
struct WakeMeApp: App {
    var body: some Scene {
        WindowGroup {
            RootTabView()
                .preferredColorScheme(.dark)
        }
        .modelContainer(for: [Alarm.self, AppSettings.self, TimerItem.self])
    }
}
