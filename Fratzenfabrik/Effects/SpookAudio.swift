import AVFoundation
import SwiftUI

/// Spuk-Sounds: kurze Effekte beim Fratzen-Wechsel, bei geschafften Schritten und beim Foto.
@MainActor
final class SpookAudio {
    static let shared = SpookAudio()
    static let enabledKey = "spookSoundsOn"

    private var players: [String: AVAudioPlayer] = [:]

    private var enabled: Bool { UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true }

    private init() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    enum Effect: String { case whoosh, creak, sparkle }

    func play(_ effect: Effect, volume: Float = 0.8) {
        guard enabled else { return }
        let player: AVAudioPlayer
        if let cached = players[effect.rawValue] {
            player = cached
        } else {
            guard let url = Bundle.main.url(forResource: effect.rawValue, withExtension: "wav"),
                  let created = try? AVAudioPlayer(contentsOf: url) else { return }
            players[effect.rawValue] = created
            player = created
        }
        player.volume = volume
        player.currentTime = 0
        player.play()
    }
}

/// Lautsprecher-Knopf zum An- und Ausschalten der Spuk-Sounds.
struct SoundToggle: View {
    @AppStorage(SpookAudio.enabledKey) private var soundOn = true
    var size: CGFloat = 44

    var body: some View {
        RoundIconButton(systemName: soundOn ? "speaker.wave.2.fill" : "speaker.slash.fill", size: size) {
            soundOn.toggle()
        }
        .accessibilityLabel(soundOn ? "Spuk-Sounds aus" : "Spuk-Sounds an")
    }
}
