import SwiftUI

struct StopwatchView: View {
    @State private var accumulated: TimeInterval = 0
    @State private var startedAt: Date?
    @State private var laps: [Lap] = []

    private var running: Bool { startedAt != nil }

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.01, paused: !running)) { context in
            let elapsed = currentElapsed(at: context.date)
            ZStack {
                WakeTheme.background.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 0) {
                    Text("Stopwatch")
                        .font(.system(size: 34, weight: .bold, design: .serif))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                    Text(format(elapsed))
                        .font(.system(size: 72, weight: .thin, design: .monospaced))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.4)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 36)
                        .accessibilityLabel("Elapsed time")
                        .accessibilityValue(spoken(elapsed))

                    HStack {
                        sideButton(
                            title: running ? "Lap" : "Reset",
                            fill: WakeTheme.elevated,
                            foreground: (running || elapsed > 0 || !laps.isEmpty) ? .white : WakeTheme.tertiary
                        ) {
                            if running {
                                recordLap(at: context.date)
                            } else {
                                reset()
                            }
                        }
                        .disabled(!running && elapsed == 0 && laps.isEmpty)

                        Spacer()

                        sideButton(
                            title: running ? "Stop" : "Start",
                            fill: running ? WakeTheme.destructive : Color.green,
                            foreground: .white
                        ) {
                            toggleRunning(at: Date())
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 48)

                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(laps.enumerated()), id: \.element.id) { index, lap in
                                HStack {
                                    Text("Lap \(laps.count - index)")
                                    Spacer()
                                    Text(format(lap.split))
                                    Spacer()
                                    Text(format(lap.total))
                                }
                                .font(.system(size: 17, weight: .regular, design: .monospaced))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                Divider().overlay(WakeTheme.separator)
                            }
                        }
                    }
                    .padding(.top, 28)
                }
            }
        }
    }

    private func currentElapsed(at date: Date) -> TimeInterval {
        accumulated + (startedAt.map { date.timeIntervalSince($0) } ?? 0)
    }

    private func toggleRunning(at date: Date) {
        if let startedAt {
            accumulated += date.timeIntervalSince(startedAt)
            self.startedAt = nil
        } else {
            startedAt = date
        }
    }

    private func recordLap(at date: Date) {
        let total = currentElapsed(at: date)
        let previous = laps.first?.total ?? 0
        laps.insert(Lap(split: total - previous, total: total), at: 0)
    }

    private func reset() {
        accumulated = 0
        startedAt = nil
        laps = []
    }

    private func format(_ interval: TimeInterval) -> String {
        let hundredthsTotal = Int((max(0, interval) * 100).rounded(.down))
        let hundredths = hundredthsTotal % 100
        let secondsTotal = hundredthsTotal / 100
        let seconds = secondsTotal % 60
        let minutes = (secondsTotal / 60) % 60
        let hours = secondsTotal / 3600
        if hours > 0 {
            return String(format: "%d:%02d:%02d.%02d", hours, minutes, seconds, hundredths)
        }
        return String(format: "%02d:%02d.%02d", minutes, seconds, hundredths)
    }

    private func spoken(_ interval: TimeInterval) -> String {
        let hundredthsTotal = Int((max(0, interval) * 100).rounded(.down))
        let hundredths = hundredthsTotal % 100
        let secondsTotal = hundredthsTotal / 100
        let seconds = secondsTotal % 60
        let minutes = (secondsTotal / 60) % 60
        let hours = secondsTotal / 3600
        var parts: [String] = []
        if hours > 0 { parts.append("\(hours) hours") }
        if minutes > 0 { parts.append("\(minutes) minutes") }
        parts.append("\(seconds) seconds")
        parts.append("\(hundredths) hundredths")
        return parts.joined(separator: ", ")
    }

    private func sideButton(title: String, fill: Color, foreground: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(foreground)
                .frame(width: 84, height: 84)
                .background(fill, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

private struct Lap: Identifiable {
    let id = UUID()
    let split: TimeInterval
    let total: TimeInterval
}
