import AVFoundation
import SwiftUI

/// Spuk-Sounds: kurze Effekte und gesprochene Fratzen-Rufe („Buuuh!“, „Miau!“, „Auuuuh!“).
@MainActor
final class SpookAudio {
    static let shared = SpookAudio()
    static let enabledKey = "spookSoundsOn"

    private let synthesizer = AVSpeechSynthesizer()
    private var players: [String: AVAudioPlayer] = [:]
    private var lastPhrase = Date.distantPast

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

    /// Spricht den Ruf der Fratze. Mit kurzer Pause, damit es nicht durcheinanderplappert.
    func say(_ sound: SpookSound, force: Bool = false) {
        guard enabled else { return }
        guard force || Date().timeIntervalSince(lastPhrase) > 2.2 else { return }
        lastPhrase = Date()
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
        let utterance = AVSpeechUtterance(string: sound.phrase)
        utterance.voice = AVSpeechSynthesisVoice(language: "de-DE")
        utterance.pitchMultiplier = min(max(sound.pitch, 0.5), 2.0)
        utterance.rate = min(max(sound.rate, AVSpeechUtteranceMinimumSpeechRate), AVSpeechUtteranceMaximumSpeechRate)
        utterance.volume = 1
        synthesizer.speak(utterance)
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
