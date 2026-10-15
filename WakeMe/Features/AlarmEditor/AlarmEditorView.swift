import SwiftUI

/// Signature is fixed.
struct AlarmEditorView: View {
    @Binding var record: AlarmRecord
    var isNew: Bool
    var authorizationDenied: Bool
    var onCancel: () -> Void
    var onSave: () -> Void
    var onDelete: (() -> Void)?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 0) {
                        Picker("Hour", selection: hourSelection) {
                            ForEach(1...12, id: \.self) { hour in
                                Text("\(hour)").tag(hour)
                            }
                        }
                        .pickerStyle(.wheel)
                        .labelsHidden()

                        Picker("Minute", selection: $record.minute) {
                            ForEach(0..<60, id: \.self) { minute in
                                Text(String(format: "%02d", minute)).tag(minute)
                            }
                        }
                        .pickerStyle(.wheel)
                        .labelsHidden()

                        Picker("Period", selection: periodSelection) {
                            Text("AM").tag(false)
                            Text("PM").tag(true)
                        }
                        .pickerStyle(.wheel)
                        .labelsHidden()
                    }
                    .frame(height: 180)
                }
                .listRowBackground(WakeTheme.card)

                Section {
                    NavigationLink {
                        RepeatDaysView(record: $record)
                    } label: {
                        settingsRow("Repeat", value: record.repeatSummary)
                    }

                    NavigationLink {
                        LabelEditorView(label: $record.label)
                    } label: {
                        settingsRow("Label", value: record.label)
                    }

                    NavigationLink {
                        SoundPickerView(sound: $record.sound)
                    } label: {
                        settingsRow("Sound", value: record.sound)
                    }

                    Toggle("Snooze", isOn: $record.snoozeEnabled)
                        .tint(WakeTheme.accent)
                }
                .listRowBackground(WakeTheme.card)

                Section {
                    NavigationLink {
                        MissionPickerView(mission: record.mission) { mission in
                            record.mission = mission
                        }
                    } label: {
                        missionRow
                    }
                    .accessibilityLabel("Wake-up mission")
                } header: {
                    Text("WAKE-UP MISSION")
                } footer: {
                    Text(record.mission == nil
                         ? "This alarm stops when you tap Stop."
                         : "The alarm keeps ringing until the mission is complete.")
                }
                .listRowBackground(WakeTheme.card)

                if authorizationDenied {
                    Section {
                        Text("This alarm is saved. It will not ring until alarms are allowed.")
                            .font(.footnote)
                            .foregroundStyle(WakeTheme.secondary)
                            .listRowBackground(Color.clear)
                    }
                }

                if !isNew, let onDelete {
                    Section {
                        Button(action: onDelete) {
                            Text("Delete alarm")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(WakeTheme.destructive)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(WakeTheme.deleteFill, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Delete alarm")
                        .listRowBackground(Color.clear)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(WakeTheme.background)
            .navigationTitle(isNew ? "Add alarm" : "Edit alarm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: onSave)
                        .accessibilityLabel("Save")
                }
            }
        }
        .tint(WakeTheme.accent)
        .preferredColorScheme(.dark)
    }

    private var hourSelection: Binding<Int> {
        Binding(
            get: {
                let hour = record.hour % 12
                return hour == 0 ? 12 : hour
            },
            set: { newHour in
                let isPM = record.hour >= 12
                let base = newHour % 12
                record.hour = isPM ? base + 12 : base
            }
        )
    }

    private var periodSelection: Binding<Bool> {
        Binding(
            get: { record.hour >= 12 },
            set: { isPM in
                let base = record.hour % 12
                record.hour = isPM ? base + 12 : base
            }
        )
    }

    private var missionRow: some View {
        HStack(spacing: 12) {
            Image(systemName: record.mission?.symbolName ?? "alarm")
                .font(.title3)
                .foregroundStyle(WakeTheme.accent)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(record.mission?.editorTitle ?? "None")
                    .foregroundStyle(.white)
                Text(record.mission?.editorDetail ?? "Regular alarm")
                    .font(.subheadline)
                    .foregroundStyle(WakeTheme.secondary)
                    .lineLimit(2)
            }
        }
    }

    private func settingsRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(WakeTheme.secondary)
                .lineLimit(1)
        }
    }
}

private struct RepeatDaysView: View {
    @Binding var record: AlarmRecord

    var body: some View {
        List {
            Section {
                presetRow("Never", days: [])
                presetRow("Every day", days: Weekday.allCases)
                presetRow("Weekdays", days: Weekday.weekdays)
                presetRow("Weekends", days: Weekday.weekend)
            }
            .listRowBackground(WakeTheme.card)

            Section {
                ForEach(Weekday.allCases) { day in
                    Toggle(day.fullName, isOn: binding(for: day))
                        .tint(WakeTheme.accent)
                }
            }
            .listRowBackground(WakeTheme.card)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(WakeTheme.background)
        .navigationTitle("Repeat")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func presetRow(_ title: String, days: [Weekday]) -> some View {
        Button {
            setDays(days)
        } label: {
            HStack {
                Text(title)
                    .foregroundStyle(.white)
                Spacer()
                if matches(days) {
                    Image(systemName: "checkmark")
                        .foregroundStyle(WakeTheme.accent)
                }
            }
        }
    }

    private func matches(_ days: [Weekday]) -> Bool {
        Set(record.repeatDays) == Set(days)
    }

    private func binding(for day: Weekday) -> Binding<Bool> {
        Binding(
            get: { record.repeatDays.contains(day) },
            set: { isOn in
                var days = record.repeatDays
                if isOn {
                    if !days.contains(day) { days.append(day) }
                } else {
                    days.removeAll { $0 == day }
                }
                setDays(days.sorted { $0.rawValue < $1.rawValue })
            }
        )
    }

    private func setDays(_ days: [Weekday]) {
        record.repeatDays = days
        if !days.isEmpty {
            record.oneShotDate = nil
        }
    }
}

private struct LabelEditorView: View {
    @Binding var label: String

    var body: some View {
        List {
            TextField("Label", text: $label)
                .listRowBackground(WakeTheme.field)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(WakeTheme.background)
        .navigationTitle("Label")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SoundPickerView: View {
    @Binding var sound: String

    var body: some View {
        List {
            ForEach(AlarmSound.allCases) { option in
                Button {
                    sound = option.rawValue
                    AudioService.shared.preview(named: option.fileName)
                } label: {
                    HStack {
                        Text(option.rawValue)
                            .foregroundStyle(.white)
                        Spacer()
                        if sound == option.rawValue {
                            Image(systemName: "checkmark")
                                .foregroundStyle(WakeTheme.accent)
                        }
                    }
                }
                .buttonStyle(.borderless)
                .listRowBackground(WakeTheme.card)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(WakeTheme.background)
        .navigationTitle("Sound")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { AudioService.shared.stop() }
    }
}
