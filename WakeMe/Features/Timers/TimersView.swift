import SwiftData
import SwiftUI

struct TimersView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TimerItem.createdAt, order: .reverse) private var timers: [TimerItem]
    @State private var showingStart = false
    @State private var ringNotice: String?

    var body: some View {
        ZStack {
            WakeTheme.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                Text("Timers")
                    .font(.system(size: 34, weight: .bold, design: .serif))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                if let ringNotice {
                    Text(ringNotice)
                        .font(.subheadline)
                        .foregroundStyle(WakeTheme.secondary)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                }

                if timers.isEmpty {
                    Spacer()
                    Text("No Recent Timers")
                        .font(.title3)
                        .foregroundStyle(WakeTheme.tertiary)
                        .frame(maxWidth: .infinity)
                    Spacer()
                } else {
                    List {
                        Section {
                            ForEach(timers) { item in
                                TimerRow(item: item, onPause: pause, onResume: resume, onCancel: cancel)
                            }
                        } header: {
                            Text("Recents")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(WakeTheme.secondary)
                                .textCase(nil)
                        }
                        .listRowBackground(WakeTheme.card)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }

                Button {
                    showingStart = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.black)
                        .frame(width: 72, height: 72)
                        .background(Circle().fill(.white))
                }
                .accessibilityLabel("Start")
                .frame(maxWidth: .infinity)
                .padding(.bottom, 28)
            }
        }
        .sheet(isPresented: $showingStart) {
            TimerStartSheet { hours, minutes, seconds, label in
                Task { await start(hours: hours, minutes: minutes, seconds: seconds, label: label) }
            }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                tick()
            }
        }
    }

    private func start(hours: Int, minutes: Int, seconds: Int, label: String) async {
        let duration = TimeInterval(hours * 3600 + minutes * 60 + seconds)
        guard duration > 0 else { return }
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let item = TimerItem(label: trimmed.isEmpty ? "Timer" : trimmed, duration: duration, isRunning: true)
        modelContext.insert(item)
        try? modelContext.save()
        showingStart = false
        let authorization = await AlarmScheduling.requestAuthorization()
        if authorization != .authorized {
            ringNotice = "This timer will not ring until alarms are allowed."
        }
        try? await AlarmScheduling.scheduleTimer(id: item.id, duration: item.duration, label: item.label)
    }

    private func pause(_ item: TimerItem) {
        item.isRunning = false
        try? modelContext.save()
        Task { await AlarmScheduling.pauseTimer(id: item.id) }
    }

    private func resume(_ item: TimerItem) {
        item.isRunning = true
        try? modelContext.save()
        Task { await AlarmScheduling.resumeTimer(id: item.id) }
    }

    private func cancel(_ item: TimerItem) {
        let id = item.id
        modelContext.delete(item)
        try? modelContext.save()
        Task { await AlarmScheduling.cancelTimer(id: id) }
    }

    private func tick() {
        var changed = false
        for item in timers where item.isRunning && item.remaining > 0 {
            item.remaining = max(0, item.remaining - 1)
            if item.remaining == 0 { item.isRunning = false }
            changed = true
        }
        if changed { try? modelContext.save() }
    }
}

private struct TimerRow: View {
    let item: TimerItem
    let onPause: (TimerItem) -> Void
    let onResume: (TimerItem) -> Void
    let onCancel: (TimerItem) -> Void

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.label)
                    .font(.body)
                    .foregroundStyle(.white)
                Text(Self.format(item.isRunning || item.remaining != item.duration ? item.remaining : item.duration))
                    .font(.system(size: 28, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(item.isRunning ? .white : WakeTheme.secondary)
            }
            Spacer()
            if item.isRunning {
                control("pause.fill", label: "Pause", color: WakeTheme.accent) { onPause(item) }
            } else if item.remaining > 0 {
                control("play.fill", label: "Resume", color: WakeTheme.accent) { onResume(item) }
            }
            control("xmark", label: "Cancel", color: WakeTheme.destructive) { onCancel(item) }
        }
        .padding(.vertical, 6)
    }

    private func control(_ systemName: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.body.weight(.bold))
                .foregroundStyle(color)
                .frame(width: 44, height: 44)
                .background(Circle().fill(WakeTheme.elevated))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private static func format(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

private struct TimerStartSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var hours = 0
    @State private var minutes = 1
    @State private var seconds = 0
    @State private var label = ""
    let onStart: (Int, Int, Int, String) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                HStack(spacing: 0) {
                    wheel("Hours", selection: $hours, range: 0..<24, suffix: "hr")
                    wheel("Minutes", selection: $minutes, range: 0..<60, suffix: "min")
                    wheel("Seconds", selection: $seconds, range: 0..<60, suffix: "sec")
                }
                .frame(height: 180)

                TextField("Label", text: $label)
                    .textFieldStyle(.plain)
                    .foregroundStyle(.white)
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(WakeTheme.field))
                    .padding(.horizontal, 20)

                Spacer()
            }
            .padding(.top, 12)
            .background(WakeTheme.background.ignoresSafeArea())
            .navigationTitle("New Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(WakeTheme.accent)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") {
                        onStart(hours, minutes, seconds, label)
                    }
                    .disabled(hours == 0 && minutes == 0 && seconds == 0)
                    .fontWeight(.semibold)
                    .accessibilityLabel("Start")
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(WakeTheme.background)
    }

    private func wheel(_ title: String, selection: Binding<Int>, range: Range<Int>, suffix: String) -> some View {
        Picker(title, selection: selection) {
            ForEach(range, id: \.self) { value in
                Text("\(value) \(suffix)").tag(value)
            }
        }
        .pickerStyle(.wheel)
        .labelsHidden()
    }
}
