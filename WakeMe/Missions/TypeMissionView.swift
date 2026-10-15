import SwiftUI
import UIKit

/// Signature is fixed. Replace the body only.
struct TypeMissionView: View {
    var phrase: String
    var label: String
    var timeText: String
    var isPreview: Bool
    var onFinish: () -> Void

    @State private var typed = ""

    private var progress: TypedPhrase.Progress {
        TypedPhrase.progress(typed: typed, target: phrase)
    }

    var body: some View {
        ZStack {
            WakeTheme.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 22) {
                header
                title
                targetCard
                entry
                Spacer(minLength: 12)
                stopButton
                Text("Paste is turned off for this mission.")
                    .font(.footnote)
                    .foregroundStyle(WakeTheme.tertiary)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 24)
            .padding(.top, 28)
            .padding(.bottom, 20)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(isPreview ? "PREVIEW" : "RINGING")
                .font(.caption.weight(.semibold))
                .tracking(1.6)
                .foregroundStyle(WakeTheme.secondary)
            Text(timeText)
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.white)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(WakeTheme.secondary)
        }
    }

    private var title: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("TYPE MISSION")
                .font(.caption.weight(.semibold))
                .tracking(1.4)
                .foregroundStyle(WakeTheme.tertiary)
            Text("Type it out.")
                .font(.system(size: 34, weight: .regular, design: .serif))
                .foregroundStyle(.white)
        }
    }

    private var targetCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("TYPE EXACTLY")
                    .font(.caption.weight(.semibold))
                    .tracking(1.2)
                    .foregroundStyle(WakeTheme.tertiary)
                Spacer()
                Text("\(progress.correctCount) / \(phrase.count)")
                    .font(.subheadline.monospacedDigit().weight(.medium))
                    .foregroundStyle(.white)
            }
            Text(highlightedPhrase)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(WakeTheme.card, in: RoundedRectangle(cornerRadius: 16))
    }

    private var highlightedPhrase: AttributedString {
        var result = AttributedString(phrase)
        let matched = min(progress.correctCount, phrase.count)
        let split = result.index(result.startIndex, offsetByCharacters: matched)
        if result.startIndex < split {
            result[result.startIndex..<split].foregroundColor = .white
        }
        if split < result.endIndex {
            result[split..<result.endIndex].foregroundColor = WakeTheme.secondary
        }
        return result
    }

    private var entry: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("YOUR TEXT")
                .font(.caption.weight(.semibold))
                .tracking(1.2)
                .foregroundStyle(WakeTheme.tertiary)
            LockedTextView(text: $typed, target: phrase)
                .frame(minHeight: 96)
                .background(WakeTheme.field, in: RoundedRectangle(cornerRadius: 14))
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            progress.typoIndex == nil ? WakeTheme.separator : WakeTheme.snooze,
                            lineWidth: progress.typoIndex == nil ? 1 : 1.5
                        )
                }
            if let typoIndex = progress.typoIndex {
                Text("Typo at character \(typoIndex) — fix it to continue")
                    .font(.footnote)
                    .foregroundStyle(WakeTheme.snooze)
                    .accessibilityLabel("Typo at character \(typoIndex) — fix it to continue")
            }
        }
    }

    private var stopButton: some View {
        Button(action: onFinish) {
            Text("Stop alarm")
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        }
        .buttonStyle(.plain)
        .disabled(!progress.isComplete)
        .foregroundStyle(progress.isComplete ? Color.black : WakeTheme.tertiary)
        .background {
            RoundedRectangle(cornerRadius: 14)
                .fill(progress.isComplete ? Color.white : Color.clear)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(progress.isComplete ? Color.clear : WakeTheme.pillStroke.opacity(0.45), lineWidth: 1)
        }
        .accessibilityLabel("Stop alarm")
    }
}

private struct LockedTextView: UIViewRepresentable {
    @Binding var text: String
    var target: String

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, target: target)
    }

    func makeUIView(context: Context) -> NoPasteTextView {
        let view = NoPasteTextView()
        view.delegate = context.coordinator
        view.backgroundColor = .clear
        view.textColor = .white
        view.tintColor = UIColor(WakeTheme.accent)
        view.font = .systemFont(ofSize: 18)
        view.autocorrectionType = .no
        view.spellCheckingType = .no
        view.smartQuotesType = .no
        view.smartDashesType = .no
        view.smartInsertDeleteType = .no
        view.autocapitalizationType = .none
        view.textContentType = nil
        view.textContainerInset = UIEdgeInsets(top: 12, left: 10, bottom: 12, right: 10)
        return view
    }

    func updateUIView(_ uiView: NoPasteTextView, context: Context) {
        context.coordinator.target = target
        if uiView.text != text {
            uiView.text = text
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var text: Binding<String>
        var target: String

        init(text: Binding<String>, target: String) {
            self.text = text
            self.target = target
        }

        func textViewDidChange(_ textView: UITextView) {
            var value = textView.text ?? ""
            let progress = TypedPhrase.progress(typed: value, target: target)
            if let typoIndex = progress.typoIndex, value.count > typoIndex {
                value = String(value.prefix(typoIndex))
                textView.text = value
            }
            if text.wrappedValue != value {
                text.wrappedValue = value
            }
        }
    }
}

private final class NoPasteTextView: UITextView {
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        let name = NSStringFromSelector(action)
        if name == "paste:" || name == "copy:" || name == "select:" {
            return false
        }
        return super.canPerformAction(action, withSender: sender)
    }

    override func insertDictationResult(_ dictationResult: [UIDictationPhrase]) {}
}
