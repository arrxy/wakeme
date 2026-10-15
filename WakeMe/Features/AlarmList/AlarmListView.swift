import SwiftData
import SwiftUI
import UIKit

/// Signature is fixed. Replace the body. Do not schedule alarms in this view.
struct AlarmListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Alarm.hour), SortDescriptor(\Alarm.minute)]) private var alarms: [Alarm]

    @State private var editMode: EditMode = .inactive
    @State private var plusOpen = false
    @State private var denied = false
    @State private var authorization = AlarmScheduling.authorization()
    @State private var authorizationNote: String?
    @State private var defaultMission: Mission?
    @State private var draft = AlarmRecord.newDraft()
    @State private var sheet: ActiveSheet?

    private var records: [AlarmRecord] { alarms.map(\.record) }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topTrailing) {
                list
                if plusOpen {
                    Color.black.opacity(0.55)
                        .ignoresSafeArea()
                        .onTapGesture { plusOpen = false }
                    plusMenu
                        .padding(.top, 8)
                        .padding(.trailing, 16)
                }
            }
            .background(WakeTheme.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(editMode == .active ? "Done" : "Edit") {
                        editMode = editMode == .active ? .inactive : .active
                    }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(WakeTheme.accent)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        plusOpen.toggle()
                    } label: {
                        Image(systemName: "plus")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(WakeTheme.elevated))
                    }
                    .accessibilityLabel("Add alarm")
                }
            }
            .sheet(item: $sheet) { active in
                sheetContent(active)
            }
            .task {
                authorization = AlarmScheduling.authorization()
                if let settings = try? AlarmStore.settings(in: modelContext) {
                    if settings.defaultMission == .defaultWake,
                       !UserDefaults.standard.bool(forKey: "wakeme.noneMissionDefault") {
                        settings.defaultMission = nil
                        try? modelContext.save()
                    }
                    UserDefaults.standard.set(true, forKey: "wakeme.noneMissionDefault")
                    defaultMission = settings.defaultMission
                }
            }
        }
    }

    private var list: some View {
        List {
            if authorization != .authorized {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Alarms won't ring until WakeMe is allowed to schedule alarms.")
                            .font(.subheadline)
                            .foregroundStyle(.white)
                        Button("Allow", action: allowAlarms)
                            .buttonStyle(.borderless)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(WakeTheme.accent)
                        if let authorizationNote {
                            Text(authorizationNote)
                                .font(.footnote)
                                .foregroundStyle(WakeTheme.secondary)
                        }
                    }
                    .listRowBackground(WakeTheme.card)
                }
            }

            Section {
                ForEach(alarms) { alarm in
                    row(alarm)
                        .opacity(alarm.isEnabled ? 1 : 0.4)
                        .listRowBackground(WakeTheme.card)
                        .listRowSeparatorTint(WakeTheme.separator)
                }
                .onDelete(perform: deleteOffsets)
            } header: {
                Text("SLEEP | WAKE UP")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(WakeTheme.tertiary)
                    .tracking(0.6)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.editMode, $editMode)
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Alarms")
                    .font(.system(size: 34, weight: .bold, design: .serif))
                    .foregroundStyle(.white)
                Text(AlarmRecord.nextAlarmLine(from: records))
                    .font(.subheadline)
                    .foregroundStyle(WakeTheme.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
            .background(WakeTheme.background)
        }
    }

    private var plusMenu: some View {
        VStack(alignment: .leading, spacing: 0) {
            menuRow(title: "Single alarm", subtitle: "One time, one mission", symbol: "clock") {
                openSingle()
            }
            Divider().overlay(WakeTheme.separator)
            menuRow(title: "Alarm series", subtitle: "Several alarms, evenly spaced", symbol: "list.bullet") {
                plusOpen = false
                sheet = .series
            }
            Divider().overlay(WakeTheme.separator)
            menuRow(title: "Speak alarms", subtitle: "Say one or many, on-device", symbol: "mic") {
                plusOpen = false
                denied = false
                sheet = .speak
            }
        }
        .frame(width: 280)
        .background(WakeTheme.elevated)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func menuRow(title: String, subtitle: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: symbol)
                    .font(.body)
                    .foregroundStyle(WakeTheme.secondary)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(WakeTheme.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    private func row(_ alarm: Alarm) -> some View {
        let record = alarm.record
        return HStack(alignment: .center, spacing: 12) {
            Button {
                openEditor(record)
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(record.hourText)
                            .font(.system(size: 46, weight: .regular, design: .serif))
                        Text(record.periodText)
                            .font(.system(size: 18, weight: .medium, design: .serif))
                    }
                    .foregroundStyle(.white)
                    Text(record.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(WakeTheme.secondary)
                    if let mission = record.mission {
                        HStack(spacing: 6) {
                            Image(systemName: mission.symbolName)
                            Text(mission.pill)
                        }
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .overlay(Capsule().stroke(WakeTheme.pillStroke, lineWidth: 1))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(record.hourText) \(record.periodText), \(record.subtitle)")

            Toggle(isOn: enabledBinding(alarm)) {
                Text("Enabled")
            }
            .labelsHidden()
            .tint(WakeTheme.accent)
            .accessibilityLabel(record.isEnabled ? "Alarm on" : "Alarm off")
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func sheetContent(_ active: ActiveSheet) -> some View {
        switch active {
        case .single:
            AlarmEditorView(
                record: $draft,
                isNew: true,
                authorizationDenied: denied,
                onCancel: dismissSheet,
                onSave: saveNew,
                onDelete: nil
            )
        case .series:
            SeriesEditorView(onCancel: dismissSheet, onCreate: createSeries)
        case .speak:
            SpeakAlarmsView(
                existing: records,
                defaultMission: defaultMission,
                onCancel: dismissSheet,
                onCreate: createSpoken
            )
        case .edit:
            AlarmEditorView(
                record: $draft,
                isNew: false,
                authorizationDenied: denied,
                onCancel: dismissSheet,
                onSave: saveExisting,
                onDelete: { removeDraft() }
            )
        }
    }

    private func enabledBinding(_ alarm: Alarm) -> Binding<Bool> {
        Binding(
            get: { alarm.isEnabled },
            set: { isOn in
                var record = alarm.record
                record.isEnabled = isOn
                persist(record)
            }
        )
    }

    private func openSingle() {
        plusOpen = false
        denied = false
        draft = AlarmRecord.newDraft()
        sheet = .single
    }

    private func openEditor(_ record: AlarmRecord) {
        plusOpen = false
        denied = false
        draft = record
        sheet = .edit(record.id)
    }

    private func dismissSheet() {
        denied = false
        sheet = nil
    }

    private func saveNew() {
        let record = draft
        do {
            try AlarmStore.upsert(record, in: modelContext)
        } catch {}
        Task {
            let status = await AlarmScheduling.requestAuthorization()
            authorization = status
            if status == .denied {
                denied = true
            }
            await AlarmScheduling.upsert(record)
            if status != .denied {
                sheet = nil
            }
        }
    }

    private func saveExisting() {
        persist(draft)
        sheet = nil
    }

    private func createSeries(_ created: [AlarmRecord]) {
        for record in created {
            try? AlarmStore.upsert(record, in: modelContext)
        }
        sheet = nil
        Task {
            for record in created {
                await AlarmScheduling.upsert(record)
            }
        }
    }

    private func createSpoken(_ drafts: [SpokenAlarmDraft]) {
        let chosen = drafts.filter(\.include).map(\.record)
        for record in chosen {
            try? AlarmStore.upsert(record, in: modelContext)
        }
        sheet = nil
        Task {
            for record in chosen {
                await AlarmScheduling.upsert(record)
            }
        }
    }

    private func persist(_ record: AlarmRecord) {
        try? AlarmStore.upsert(record, in: modelContext)
        Task { await AlarmScheduling.upsert(record) }
    }

    private func deleteOffsets(_ offsets: IndexSet) {
        for index in offsets {
            remove(alarms[index])
        }
    }

    private func remove(_ alarm: Alarm) {
        let id = alarm.id
        try? AlarmStore.delete(id: id, in: modelContext)
        Task { await AlarmScheduling.remove(id: id) }
    }

    private func removeDraft() {
        let id = draft.id
        try? AlarmStore.delete(id: id, in: modelContext)
        sheet = nil
        Task { await AlarmScheduling.remove(id: id) }
    }

    private func allowAlarms() {
        Task {
            let status = await AlarmScheduling.requestAuthorization()
            authorization = status
            switch status {
            case .authorized:
                authorizationNote = nil
            case .denied:
                authorizationNote = "Alarms are turned off for WakeMe. Turn them on in Settings."
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    await UIApplication.shared.open(url)
                }
            case .notDetermined:
                authorizationNote = "The alarm prompt did not appear. Allow alarms for WakeMe in Settings."
            }
        }
    }
}

private enum ActiveSheet: Identifiable {
    case single
    case series
    case speak
    case edit(UUID)

    var id: String {
        switch self {
        case .single: "single"
        case .series: "series"
        case .speak: "speak"
        case let .edit(id): id.uuidString
        }
    }
}
