import SwiftUI

struct MissionHostView: View {
    var record: AlarmRecord
    var isPreview: Bool
    var onFinish: () -> Void
    var onSnooze: () -> Void

    var body: some View {
        Group {
            switch record.mission {
            case let .math(kind, count, difficulty):
                MathMissionView(
                    kind: kind,
                    questionCount: count,
                    difficulty: difficulty,
                    label: record.label,
                    timeText: "\(record.hourText) \(record.periodText)",
                    isPreview: isPreview,
                    onFinish: onFinish
                )
            case let .shake(count, strength):
                ShakeMissionView(
                    targetCount: count,
                    strength: strength,
                    label: record.label,
                    timeText: "\(record.hourText) \(record.periodText)",
                    snoozeEnabled: record.snoozeEnabled && !isPreview,
                    isPreview: isPreview,
                    onFinish: onFinish,
                    onSnooze: onSnooze
                )
            case let .type(text):
                TypeMissionView(
                    phrase: text,
                    label: record.label,
                    timeText: "\(record.hourText) \(record.periodText)",
                    isPreview: isPreview,
                    onFinish: onFinish
                )
            case nil:
                missing
            }
        }
        .onAppear {
            guard !isPreview else { return }
            AudioService.shared.playLoop(named: record.soundFile, volume: RingPolicy.missionVolume)
        }
    }

    private var missing: some View {
        ZStack {
            WakeTheme.background.ignoresSafeArea()
            VStack(spacing: 20) {
                Text(record.label).font(.title)
                Button("Stop alarm", action: onFinish)
            }
            .foregroundStyle(.white)
        }
    }
}
