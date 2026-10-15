import SwiftData
import SwiftUI

struct RootTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var missionRecord: AlarmRecord?

    var body: some View {
        TabView {
            WorldClockView()
                .tabItem { Label("World Clock", systemImage: "globe") }
            NavigationStack {
                AlarmListView()
            }
            .tabItem { Label("Alarms", systemImage: "alarm.fill") }
            StopwatchView()
                .tabItem { Label("Stopwatch", systemImage: "stopwatch.fill") }
            TimersView()
                .tabItem { Label("Timers", systemImage: "timer") }
        }
        .tint(.white)
        .task { seedIfNeeded() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { presentPendingMission() }
        }
        .fullScreenCover(item: $missionRecord) { record in
            MissionHostView(record: record, isPreview: false) {
                Task {
                    await AlarmScheduling.finishMission(parentID: record.id)
                    AudioService.shared.stop()
                    missionRecord = nil
                }
            } onSnooze: {
                Task {
                    AudioService.shared.stop()
                    await AlarmScheduling.snoozeMission(parentID: record.id)
                    missionRecord = nil
                }
            }
        }
    }

    private func presentPendingMission() {
        guard missionRecord == nil, let parentID = RingSession.read().pendingParentID else { return }
        let identifier = parentID
        let descriptor = FetchDescriptor<Alarm>(predicate: #Predicate { $0.id == identifier })
        if let alarm = try? modelContext.fetch(descriptor).first {
            missionRecord = alarm.record
            return
        }
        missionRecord = RingSession.record(parentID)
    }

    private func seedIfNeeded() {
        let existing = (try? modelContext.fetch(FetchDescriptor<Alarm>())) ?? []
        guard existing.isEmpty else { return }
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        var nine = calendar.dateComponents([.year, .month, .day], from: tomorrow)
        nine.hour = 9
        nine.minute = 0
        let samples: [AlarmRecord] = [
            AlarmRecord(id: UUID(), hour: 6, minute: 30, repeatDays: Weekday.weekdays, oneShotDate: nil, label: "Wake up", sound: AlarmSound.radial.rawValue, snoozeEnabled: true, mission: .math(kind: .arithmetic, count: 5, difficulty: .hard), seriesID: nil, isEnabled: true),
            AlarmRecord(id: UUID(), hour: 8, minute: 15, repeatDays: Weekday.weekend, oneShotDate: nil, label: "Weekend", sound: AlarmSound.beacon.rawValue, snoozeEnabled: true, mission: .shake(count: 40, strength: .firm), seriesID: nil, isEnabled: true),
            AlarmRecord(id: UUID(), hour: 5, minute: 45, repeatDays: [.monday, .wednesday, .friday], oneShotDate: nil, label: "Gym", sound: AlarmSound.circuit.rawValue, snoozeEnabled: true, mission: .math(kind: .geometry, count: 3, difficulty: .medium), seriesID: nil, isEnabled: false),
            AlarmRecord(id: UUID(), hour: 9, minute: 0, repeatDays: [], oneShotDate: calendar.date(from: nine), label: "Alarm", sound: AlarmSound.rise.rawValue, snoozeEnabled: false, mission: .type(text: Mission.defaultTypePhrase), seriesID: nil, isEnabled: false)
        ]
        for sample in samples {
            modelContext.insert(sample.makeModel())
            RingSession.save(sample)
        }
        if (try? modelContext.fetch(FetchDescriptor<AppSettings>()))?.isEmpty != false {
            modelContext.insert(AppSettings())
        }
        try? modelContext.save()
    }
}
