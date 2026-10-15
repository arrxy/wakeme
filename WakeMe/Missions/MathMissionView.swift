import SwiftUI

/// Signature is fixed. Replace the body only.
struct MathMissionView: View {
    var kind: MathKind
    var questionCount: Int
    var difficulty: Difficulty
    var label: String
    var timeText: String
    var isPreview: Bool
    var onFinish: () -> Void

    @State private var seed = UInt64.random(in: 0..<UInt64.max)
    @State private var question = MathGenerator.Question(prompt: "", answer: 0)
    @State private var correct = 0
    @State private var entry = ""
    @State private var tryAnother = false
    @State private var feedbackToken = UUID()

    var body: some View {
        ZStack {
            WakeTheme.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 20) {
                header
                progressHeader
                progressBar
                Spacer(minLength: 8)
                prompt
                Spacer(minLength: 8)
                keypad
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 16)
        }
        .accessibilityIdentifier(label)
        .onAppear {
            guard question.prompt.isEmpty else { return }
            replaceQuestion()
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            HStack(spacing: 8) {
                if !isPreview {
                    Circle()
                        .fill(WakeTheme.snooze)
                        .frame(width: 8, height: 8)
                }
                Text(isPreview ? "PREVIEW" : "RINGING · \(timeText)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(WakeTheme.snooze)
            }
            Spacer(minLength: 12)
            if !isPreview {
                Text("Volume lowered while solving")
                    .font(.system(size: 13))
                    .foregroundStyle(WakeTheme.secondary)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    private var progressHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("\(kind.title.uppercased()) · \(difficulty.title.uppercased())")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
            Spacer()
            Text("\(correct) / \(questionCount)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(WakeTheme.secondary)
                .monospacedDigit()
        }
    }

    private var progressBar: some View {
        HStack(spacing: 6) {
            ForEach(0..<max(questionCount, 0), id: \.self) { index in
                Capsule()
                    .fill(segmentColor(index))
                    .frame(height: 4)
            }
        }
    }

    private var prompt: some View {
        VStack(spacing: 14) {
            Text(question.prompt)
                .font(.system(size: 40, weight: .regular, design: .serif))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            Text("?")
                .font(.system(size: 44, weight: .regular, design: .serif))
                .foregroundStyle(.white)
            VStack(spacing: 8) {
                Text(entry.isEmpty ? " " : entry)
                    .font(.system(size: 36, weight: .regular, design: .serif))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                Rectangle()
                    .fill(.white)
                    .frame(width: underlineWidth, height: 2)
            }
            Text("Try another")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(WakeTheme.snooze)
                .opacity(tryAnother ? 1 : 0)
        }
        .frame(maxWidth: .infinity)
    }

    private var keypad: some View {
        VStack(spacing: 10) {
            ForEach(keyRows, id: \.self) { row in
                HStack(spacing: 10) {
                    ForEach(row, id: \.self) { digit in
                        keyButton(digit) { append(digit) }
                    }
                }
            }
            HStack(spacing: 10) {
                Button {
                    backspace()
                } label: {
                    Image(systemName: "delete.left")
                        .font(.system(size: 22, weight: .medium))
                        .frame(maxWidth: .infinity, minHeight: 64)
                        .background(WakeTheme.elevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .accessibilityLabel("Backspace")

                keyButton("0") { append("0") }

                Button {
                    submit()
                } label: {
                    Text("Submit")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity, minHeight: 64)
                        .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Submit")
            }
        }
    }

    private var keyRows: [[String]] {
        [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"]]
    }

    private var underlineWidth: CGFloat {
        max(88, CGFloat(max(entry.count, 1)) * 22)
    }

    private func keyButton(_ digit: String, action: @escaping () -> Void) -> some View {
        Button(digit, action: action)
            .font(.system(size: 28, weight: .medium))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(WakeTheme.elevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .buttonStyle(.plain)
            .accessibilityLabel(digit)
    }

    private func segmentColor(_ index: Int) -> Color {
        if index < correct { return .white }
        if index == correct { return WakeTheme.snooze }
        return Color.white.opacity(0.16)
    }

    private func append(_ digit: String) {
        guard entry.count < 9 else { return }
        entry.append(digit)
    }

    private func backspace() {
        guard !entry.isEmpty else { return }
        entry.removeLast()
    }

    private func replaceQuestion() {
        var nextSeed = seed
        question = MathGenerator.question(kind: kind, difficulty: difficulty, seed: &nextSeed)
        seed = nextSeed
    }

    private func submit() {
        let value = Int(entry)
        entry = ""
        if value == question.answer {
            tryAnother = false
            correct += 1
            if correct >= questionCount {
                onFinish()
                return
            }
            replaceQuestion()
            return
        }
        replaceQuestion()
        let token = UUID()
        feedbackToken = token
        tryAnother = true
        Task {
            try? await Task.sleep(nanoseconds: 900_000_000)
            guard feedbackToken == token else { return }
            tryAnother = false
        }
    }
}
