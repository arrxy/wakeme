import SwiftUI

/// Try it now must not touch AlarmKit.
struct MissionPickerView: View {
    var mission: Mission?
    var onDone: (Mission?) -> Void

    @State private var choice: Choice = .none
    @State private var mathKind: MathKind = .arithmetic
    @State private var questionCount: Double = 5
    @State private var difficulty: Difficulty = .hard
    @State private var shakeCount: Double = 40
    @State private var strength: ShakeStrength = .medium
    @State private var phrase = Mission.defaultTypePhrase
    @State private var previewRecord: AlarmRecord?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                headline
                cards
                editor
                actions
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(WakeTheme.background.ignoresSafeArea())
        .navigationTitle("Wake-up mission")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .preferredColorScheme(.dark)
        .onAppear(perform: load)
        .fullScreenCover(item: $previewRecord) { record in
            MissionHostView(
                record: record,
                isPreview: true,
                onFinish: { previewRecord = nil },
                onSnooze: { previewRecord = nil }
            )
        }
    }

    private var headline: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Prove you're awake.")
                .font(.system(size: 34, weight: .regular, design: .serif))
                .foregroundStyle(.white)
            Text("Choose how this alarm gets turned off.")
                .font(.body)
                .foregroundStyle(WakeTheme.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var cards: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                card(.math, title: "Solve math", symbol: "plus.forwardslash.minus")
                card(.shake, title: "Shake", symbol: "iphone.radiowaves.left.and.right")
                card(.type, title: "Type text", symbol: "keyboard")
            }
            Button {
                choice = .none
            } label: {
                Text("None")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(choice == .none ? Color.black : Color.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(choice == .none ? Color.white : WakeTheme.card, in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("None")
            .accessibilityAddTraits(choice == .none ? .isSelected : [])
        }
    }

    private func card(_ option: Choice, title: String, symbol: String) -> some View {
        let selected = choice == option
        return Button {
            choice = option
        } label: {
            VStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.title2)
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(selected ? Color.black : Color.white)
            .frame(maxWidth: .infinity)
            .frame(height: 108)
            .background(selected ? Color.white : WakeTheme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder
    private var editor: some View {
        switch choice {
        case .none:
            Text("No mission. This alarm stops when you tap Stop, like a regular alarm.")
                .font(.body)
                .foregroundStyle(WakeTheme.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .math:
            mathEditor
                .padding(16)
                .background(WakeTheme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        case .shake:
            shakeEditor
                .padding(16)
                .background(WakeTheme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        case .type:
            typeEditor
                .padding(16)
                .background(WakeTheme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private var mathEditor: some View {
        VStack(alignment: .leading, spacing: 22) {
            Picker("Kind", selection: $mathKind) {
                ForEach(MathKind.allCases, id: \.self) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            .pickerStyle(.segmented)

            labeledSlider(
                title: "NUMBER OF QUESTIONS",
                valueText: "\(Int(questionCount))",
                value: $questionCount,
                range: 1...10,
                step: 1,
                captions: ["1", "10"]
            )

            labeledSlider(
                title: "DIFFICULTY",
                valueText: difficulty.title,
                value: difficultyValue,
                range: 0...3,
                step: 1,
                captions: Difficulty.allCases.map(\.title)
            )

            Divider().overlay(WakeTheme.separator)
            VStack(alignment: .leading, spacing: 8) {
                sectionLabel("SAMPLE QUESTION")
                Text(MathGenerator.sample(kind: mathKind, difficulty: difficulty))
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var shakeEditor: some View {
        VStack(alignment: .leading, spacing: 22) {
            labeledSlider(
                title: "SHAKES",
                valueText: "\(Int(shakeCount))",
                value: $shakeCount,
                range: 10...100,
                step: 5,
                captions: ["10", "40", "70", "100"]
            )

            VStack(alignment: .leading, spacing: 8) {
                sectionLabel("STRENGTH")
                Picker("Strength", selection: $strength) {
                    ForEach(ShakeStrength.allCases, id: \.self) { item in
                        Text(item.title).tag(item)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private var typeEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("PHRASE")
            TextEditor(text: $phrase)
                .scrollContentBackground(.hidden)
                .font(.body)
                .foregroundStyle(.white)
                .frame(minHeight: 140)
                .padding(12)
                .background(WakeTheme.field, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var actions: some View {
        HStack(spacing: 12) {
            if choice != .none {
                Button {
                    previewRecord = makePreviewRecord()
                } label: {
                    Text("Try it now")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(WakeTheme.elevated, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Try it now")
            }

            Button {
                onDone(currentMission)
            } label: {
                Text("Done")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.white, in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Done")
        }
    }

    private func labeledSlider(
        title: String,
        valueText: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        captions: [String]
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                sectionLabel(title)
                Spacer()
                Text(valueText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
            }
            Slider(value: value, in: range, step: step)
                .tint(WakeTheme.accent)
            HStack {
                ForEach(Array(captions.enumerated()), id: \.offset) { _, caption in
                    Text(caption)
                        .frame(maxWidth: .infinity, alignment: captions.count == 1 ? .center : .center)
                }
            }
            .font(.caption2)
            .foregroundStyle(WakeTheme.tertiary)
        }
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .tracking(0.6)
            .foregroundStyle(WakeTheme.secondary)
    }

    private var difficultyValue: Binding<Double> {
        Binding {
            Double(Difficulty.allCases.firstIndex(of: difficulty) ?? 0)
        } set: { newValue in
            let index = Int(newValue.rounded())
            difficulty = Difficulty.allCases[min(max(index, 0), Difficulty.allCases.count - 1)]
        }
    }

    private var currentMission: Mission? {
        switch choice {
        case .none:
            nil
        case .math:
            .math(kind: mathKind, count: Int(questionCount), difficulty: difficulty)
        case .shake:
            .shake(count: Int(shakeCount), strength: strength)
        case .type:
            .type(text: phrase)
        }
    }

    private func makePreviewRecord() -> AlarmRecord {
        AlarmRecord(
            id: UUID(),
            hour: 7,
            minute: 0,
            repeatDays: [],
            oneShotDate: nil,
            label: "Preview",
            sound: AlarmSound.radial.rawValue,
            snoozeEnabled: false,
            mission: currentMission ?? .defaultWake,
            seriesID: nil,
            isEnabled: false
        )
    }

    private func load() {
        guard let mission else {
            choice = .none
            return
        }
        switch mission {
        case let .math(kind, count, level):
            choice = .math
            mathKind = kind
            questionCount = Double(min(max(count, 1), 10))
            difficulty = level
        case let .shake(count, level):
            choice = .shake
            let snapped = Int((Double(count) / 5).rounded()) * 5
            shakeCount = Double(min(max(snapped, 10), 100))
            strength = level
        case let .type(text):
            choice = .type
            phrase = text.isEmpty ? Mission.defaultTypePhrase : text
        }
    }

    private enum Choice {
        case none, math, shake, type
    }
}
