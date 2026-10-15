import SwiftUI

/// Signature is fixed. Do not schedule until onCreate.
struct SpeakAlarmsView: View {
    var existing: [AlarmRecord]
    var defaultMission: Mission?
    var onCancel: () -> Void
    var onCreate: ([SpokenAlarmDraft]) -> Void

    @StateObject private var speech = SpeechService()
    @State private var phase: Phase = .listening
    @State private var drafts: [SpokenAlarmDraft] = []
    @State private var editing: AlarmRecord?
    @State private var interpreting = false

    private enum Phase { case listening, review }

    private var liveDrafts: [SpokenAlarmDraft] {
        AlarmParser.parse(speech.transcript, existing: existing, defaultMission: defaultMission)
    }

    private var includedCount: Int { drafts.filter(\.include).count }

    var body: some View {
        ZStack {
            WakeTheme.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                header
                if phase == .listening {
                    listening
                } else {
                    review
                }
            }
            .foregroundStyle(.white)
        }
        .task {
            if !speech.isListening { await speech.start() }
        }
        .sheet(item: $editing) { record in
            DraftEditorSheet(
                record: record,
                onCancel: { editing = nil },
                onSave: { updated in
                    apply(updated)
                    editing = nil
                }
            )
        }
    }

    private var header: some View {
        ZStack {
            Text(phase == .listening ? "Speak alarms" : "Review")
                .font(.headline)
            HStack {
                Button("Cancel", action: onCancel)
                Spacer()
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var listening: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("ON-DEVICE · AUDIO NEVER LEAVES THIS IPHONE")
                .font(.caption2.weight(.semibold))
                .tracking(0.6)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .overlay(Capsule().stroke(WakeTheme.pillStroke, lineWidth: 1))
                .frame(maxWidth: .infinity)

            Text("LISTENING")
                .font(.caption.weight(.semibold))
                .tracking(1.2)
                .foregroundStyle(WakeTheme.secondary)

            Text(highlightedTranscript)
                .font(.title2)
                .frame(maxWidth: .infinity, alignment: .leading)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(liveDrafts) { draft in
                        Text(chipText(draft))
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(WakeTheme.elevated, in: Capsule())
                    }
                }
            }

            Spacer()

            Waveform(active: speech.isListening)
                .frame(maxWidth: .infinity)

            Button {
                stopAndReview()
            } label: {
                ZStack {
                    Circle()
                        .fill(WakeTheme.snooze)
                        .frame(width: 84, height: 84)
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(.white)
                        .frame(width: 26, height: 26)
                }
            }
            .buttonStyle(.plain)
            .disabled(interpreting)
            .frame(maxWidth: .infinity)
            .accessibilityLabel(speech.isListening ? "Stop listening" : "Start listening")

            Text("Tap to stop and review")
                .font(.subheadline)
                .foregroundStyle(WakeTheme.secondary)
                .frame(maxWidth: .infinity)

            Text("Try “every 10 minutes from 6 to 7”")
                .font(.footnote)
                .foregroundStyle(WakeTheme.tertiary)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 24)
        }
        .padding(.horizontal, 20)
    }

    private var review: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(heardTitle)
                .font(.system(size: 34, weight: .bold, design: .serif))

            Text("“\(speech.transcript)”")
                .font(.body)
                .foregroundStyle(WakeTheme.secondary)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(drafts) { draft in
                        reviewRow(draft)
                        Divider().overlay(WakeTheme.separator)
                    }
                }
            }

            Text(defaultMission.map { "Missions you didn't mention use your default: \($0.summary)." }
                 ?? "Alarms you didn't give a mission stop like a regular alarm.")
                .font(.footnote)
                .foregroundStyle(WakeTheme.secondary)

            HStack(spacing: 12) {
                Button {
                    phase = .listening
                    Task { await speech.start() }
                } label: {
                    Image(systemName: "mic.fill")
                        .font(.title3)
                        .frame(width: 56, height: 56)
                        .background(WakeTheme.elevated, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Listen again")

                Button {
                    onCreate(drafts.filter(\.include))
                } label: {
                    Text("Create \(includedCount) alarms")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(.white, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Create \(includedCount) alarms")
            }
            .padding(.bottom, 16)
        }
        .padding(.horizontal, 20)
    }

    private var heardTitle: String {
        drafts.count == 1 ? "Heard 1 alarm." : "Heard \(drafts.count) alarms."
    }

    private var highlightedTranscript: AttributedString {
        let text = speech.transcript.isEmpty ? " " : speech.transcript
        var attributed = AttributedString(text)
        guard !speech.transcript.isEmpty else { return attributed }
        for range in AlarmParser.highlightRanges(in: speech.transcript) {
            guard let lower = AttributedString.Index(range.lowerBound, within: attributed),
                  let upper = AttributedString.Index(range.upperBound, within: attributed)
            else { continue }
            attributed[lower..<upper].underlineStyle = .single
        }
        return attributed
    }

    private func chipText(_ draft: SpokenAlarmDraft) -> String {
        "\(draft.record.hourText) · \(draft.record.repeatSummary)"
    }

    private func reviewRow(_ draft: SpokenAlarmDraft) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Button {
                guard let index = drafts.firstIndex(where: { $0.id == draft.id }) else { return }
                drafts[index].include.toggle()
            } label: {
                Image(systemName: draft.include ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(draft.include ? .white : WakeTheme.secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text("\(draft.record.hourText) \(draft.record.periodText)")
                    .font(.title3.weight(.semibold))
                Text(rowDetail(draft))
                    .font(.subheadline)
                    .foregroundStyle(WakeTheme.secondary)
            }
            Spacer(minLength: 8)
            Button("Edit") {
                editing = draft.record
            }
            .font(.subheadline.weight(.semibold))
        }
        .padding(.vertical, 14)
    }

    private func rowDetail(_ draft: SpokenAlarmDraft) -> String {
        var parts = [draft.record.repeatSummary.capitalizedFirst]
        if draft.label != "Alarm" { parts.append(draft.label) }
        parts.append(draft.mission?.summary ?? "None")
        if draft.isDuplicate { parts.append("Already exists") }
        return parts.joined(separator: " · ")
    }

    private func stopAndReview() {
        Task {
            let wasListening = speech.isListening
            await speech.toggle()
            let text = speech.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            guard wasListening, !text.isEmpty else { return }
            interpreting = true
            let interpreted = await AlarmParserLLM.complete(
                text: speech.transcript,
                now: .now,
                existing: existing,
                defaultMission: defaultMission
            )
            drafts = interpreted.isEmpty
                ? AlarmParser.parse(speech.transcript, existing: existing, defaultMission: defaultMission)
                : interpreted
            interpreting = false
            phase = .review
        }
    }

    private func apply(_ record: AlarmRecord) {
        guard let index = drafts.firstIndex(where: { $0.id == record.id }) else { return }
        drafts[index].hour = record.hour
        drafts[index].minute = record.minute
        drafts[index].label = record.label
        drafts[index].repeatDays = record.repeatDays
        drafts[index].mission = record.mission
    }
}

private struct DraftEditorSheet: View {
    @State private var record: AlarmRecord
    var onCancel: () -> Void
    var onSave: (AlarmRecord) -> Void

    init(record: AlarmRecord, onCancel: @escaping () -> Void, onSave: @escaping (AlarmRecord) -> Void) {
        _record = State(initialValue: record)
        self.onCancel = onCancel
        self.onSave = onSave
    }

    var body: some View {
        AlarmEditorView(
            record: $record,
            isNew: false,
            authorizationDenied: false,
            onCancel: onCancel,
            onSave: { onSave(record) },
            onDelete: nil
        )
    }
}

private struct Waveform: View {
    var active: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 12.0, paused: !active)) { context in
            HStack(alignment: .center, spacing: 4) {
                ForEach(0..<28, id: \.self) { index in
                    Capsule()
                        .fill(.white.opacity(0.9))
                        .frame(width: 3, height: barHeight(index: index, date: context.date))
                }
            }
            .frame(height: 56)
        }
    }

    private func barHeight(index: Int, date: Date) -> CGFloat {
        guard active else { return 6 }
        let time = date.timeIntervalSinceReferenceDate
        let wave = abs(sin(time * 3.2 + Double(index) * 0.45))
        return 8 + 36 * wave
    }
}
