import AVFoundation
import Foundation

@MainActor
final class AudioService {
    static let shared = AudioService()

    private var player: AVAudioPlayer?

    func playLoop(named fileName: String, volume: Float) {
        stop()
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
        let base = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension
        guard let url = Bundle.main.url(forResource: base, withExtension: ext.isEmpty ? "caf" : ext) else { return }
        player = try? AVAudioPlayer(contentsOf: url)
        player?.numberOfLoops = -1
        player?.volume = volume
        player?.prepareToPlay()
        player?.play()
    }

    func stop() {
        player?.stop()
        player = nil
    }

    func preview(named fileName: String) {
        stop()
        let base = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension
        guard let url = Bundle.main.url(forResource: base, withExtension: ext.isEmpty ? "caf" : ext) else { return }
        player = try? AVAudioPlayer(contentsOf: url)
        player?.numberOfLoops = 0
        player?.volume = 1
        player?.play()
    }
}
