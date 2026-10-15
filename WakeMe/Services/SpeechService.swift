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
            try await Self.activate(session)
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
        let hardwareFormat = engine.inputNode.outputFormat(forBus: 0)
        let analysisFormat = await Self.analysisFormat(for: [transcriber], hardware: hardwareFormat)
        guard let converter = AVAudioConverter(from: hardwareFormat, to: analysisFormat) else {
            statusLine = "Could not start listening"
            return
        }
        inputBox.converter = converter
        do {
            try await analyzer.prepareToAnalyze(in: analysisFormat)
            engine.inputNode.installTap(onBus: 0, bufferSize: 4096, format: hardwareFormat) { [inputBox] buffer, _ in
                guard let samples = inputBox.int16Samples(from: buffer) else { return }
                inputBox.continuation?.yield(AnalyzerInput(buffer: samples))
            }
            engine.prepare()
            try engine.start()
        } catch {
            inputBox.converter = nil
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
        inputBox.converter = nil
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

    private static func activate(_ session: AVAudioSession) async throws {
        if #available(iOS 27, *) {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                session.activate(options: []) { activated, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if activated {
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: CancellationError())
                    }
                }
            }
        } else {
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        }
    }

    /// SpeechAnalyzer rejects the microphone's float buffers. It wants 16-bit integer PCM.
    private static func analysisFormat(for modules: [any SpeechModule], hardware: AVAudioFormat) async -> AVAudioFormat {
        if let best = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: modules, considering: hardware),
           best.commonFormat == .pcmFormatInt16 {
            return best
        }
        let rate = hardware.sampleRate > 0 ? hardware.sampleRate : 48_000
        let channels = max(1, hardware.channelCount)
        return AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: rate, channels: channels, interleaved: false)
            ?? hardware
    }
}

private final class InputBox: @unchecked Sendable {
    var continuation: AsyncStream<AnalyzerInput>.Continuation?
    var converter: AVAudioConverter?

    func int16Samples(from buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let converter else { return nil }
        let format = converter.outputFormat
        let ratio = format.sampleRate / max(buffer.format.sampleRate, 1)
        let frames = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up)) + 32
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: max(frames, 1)) else { return nil }
        var error: NSError?
        var fed = false
        let status = converter.convert(to: output, error: &error) { _, outStatus in
            if fed {
                outStatus.pointee = .noDataNow
                return nil
            }
            fed = true
            outStatus.pointee = .haveData
            return buffer
        }
        guard error == nil, status != .error, output.frameLength > 0 else { return nil }
        return output
    }
}
