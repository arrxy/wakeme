import AVFoundation
import Foundation
import Speech

@MainActor
final class SpeechService: ObservableObject {
    @Published var transcript = ""
    @Published var isListening = false
    @Published var statusLine = "On-device · audio never leaves this iPhone"

    private var engine: AVAudioEngine?
    private var analyzer: SpeechAnalyzer?
    private let inputBox = InputBox()

    func toggle() async {
        if isListening { await stop() } else { await start() }
    }

    func start() async {
        guard !isListening else { return }
        let granted = await Self.requestMicrophone()
        guard granted else {
            statusLine = "Microphone access is off"
            return
        }
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            statusLine = "Audio session failed"
            return
        }
        let transcriber = SpeechTranscriber(locale: .current, preset: .progressiveTranscription)
        if await AssetInventory.status(forModules: [transcriber]) != .installed {
            if let request = try? await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
                try? await request.downloadAndInstall()
            }
        }
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        self.analyzer = analyzer
        let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
        inputBox.continuation = continuation
        let engine = AVAudioEngine()
        let format = engine.inputNode.outputFormat(forBus: 0)
        do {
            try await analyzer.prepareToAnalyze(in: format)
            engine.inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { [inputBox] buffer, _ in
                guard let copy = Self.copy(buffer) else { return }
                inputBox.continuation?.yield(AnalyzerInput(buffer: copy))
            }
            engine.prepare()
            try engine.start()
        } catch {
            statusLine = "Could not start listening"
            return
        }
        self.engine = engine
        isListening = true
        statusLine = "Listening"
        Task { try? await analyzer.start(inputSequence: stream) }
        Task { @MainActor in
            do {
                for try await result in transcriber.results {
                    transcript = String(result.text.characters)
                }
            } catch {
                if isListening { statusLine = "Transcription stopped" }
            }
        }
    }

    func stop() async {
        inputBox.continuation?.finish()
        inputBox.continuation = nil
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
        isListening = false
        await analyzer?.cancelAndFinishNow()
        analyzer = nil
        statusLine = "Tap to speak"
    }

    private static func requestMicrophone() async -> Bool {
        let current = AVAudioApplication.shared.recordPermission
        if current == .granted { return true }
        if current == .denied { return false }
        return await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    private static func copy(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let clone = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: buffer.frameCapacity) else { return nil }
        clone.frameLength = buffer.frameLength
        let channels = Int(buffer.format.channelCount)
        if let source = buffer.floatChannelData, let destination = clone.floatChannelData {
            for channel in 0..<channels {
                destination[channel].update(from: source[channel], count: Int(buffer.frameLength))
            }
        }
        return clone
    }
}

private final class InputBox: @unchecked Sendable {
    var continuation: AsyncStream<AnalyzerInput>.Continuation?
}
