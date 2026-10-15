import AVFoundation
import Foundation

@MainActor
final class AudioService {
    static let shared = AudioService()

    private var player: AVAudioPlayer?

    func playLoop(named fileName: String, volume: Float) {
        play(named: fileName, loops: -1, volume: volume, options: [.mixWithOthers])
    }

    func stop() {
        player?.stop()
        player = nil
    }

    func preview(named fileName: String) {
        play(named: fileName, loops: 0, volume: 1)
    }

    private func play(named fileName: String, loops: Int, volume: Float, options: AVAudioSession.CategoryOptions = []) {
        stop()
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: options)
        try? session.setActive(true)
        let base = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension
        guard let url = Bundle.main.url(forResource: base, withExtension: ext.isEmpty ? "caf" : ext) else { return }
        player = try? AVAudioPlayer(contentsOf: url)
        player?.numberOfLoops = loops
        player?.volume = volume
        player?.prepareToPlay()
        player?.play()
    }
}
