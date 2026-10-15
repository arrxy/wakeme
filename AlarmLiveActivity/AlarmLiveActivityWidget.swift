import ActivityKit
import AlarmKit
import SwiftUI
import WidgetKit

@main
struct AlarmLiveActivityBundle: WidgetBundle {
    var body: some Widget { AlarmLiveActivityWidget() }
}

struct AlarmLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<WakeMetadata>.self) { context in
            VStack(alignment: .leading, spacing: 8) {
                Text(context.attributes.metadata?.label ?? "Alarm")
                    .font(.system(size: 28, weight: .light, design: .serif))
                countdownLabel(context.state)
                    .font(.system(size: 20, weight: .medium, design: .monospaced))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .foregroundStyle(.white)
            .activityBackgroundTint(.black)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.attributes.metadata?.label ?? "Alarm")
                        .foregroundStyle(.white)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    countdownLabel(context.state)
                }
            } compactLeading: {
                Image(systemName: "alarm.fill")
            } compactTrailing: {
                countdownLabel(context.state)
            } minimal: {
                Image(systemName: "alarm.fill")
            }
        }
    }

    @ViewBuilder
    private func countdownLabel(_ state: AlarmPresentationState) -> some View {
        switch state.mode {
        case let .countdown(countdown):
            Text(timerInterval: countdown.startDate...countdown.fireDate, countsDown: true)
        case .paused:
            Text("Paused")
        case .alert:
            Text("Now")
        @unknown default:
            Text("Alarm")
        }
    }
}
