import AVFoundation
import SwiftUI

/// Spuk-Sounds: ein eigener Sound je Fratze beim Wechseln, dazu kurze Effekte für Schritte und Foto.
/// Die Figuren-Sounds erzeugt `tools/make_character_sounds.py`.
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
        play(file: effect.rawValue, ext: "wav", volume: volume)
    }

    /// Der Sound der Figur, in die man sich gerade verwandelt (z. B. Miauen, Heulen, Orgelakkord).
    func playCharacter(_ design: DesignID, volume: Float = 0.85) {
        if Bundle.main.url(forResource: "fx_\(design.rawValue)", withExtension: "m4a") != nil {
            for other in players.values where other.isPlaying { other.stop() }
            play(file: "fx_\(design.rawValue)", ext: "m4a", volume: volume)
        } else {
            play(.whoosh, volume: 0.55)
        }
    }

    /// Spielt einen Sound aus `Sounds/` (m4a), z. B. die Krokodilspiel-Effekte.
    func play(sound name: String, volume: Float = 0.85) {
        play(file: name, ext: "m4a", volume: volume)
    }

    private func play(file: String, ext: String, volume: Float) {
        guard enabled else { return }
        let player: AVAudioPlayer
        if let cached = players[file] {
            player = cached
        } else {
            guard let url = Bundle.main.url(forResource: file, withExtension: ext),
                  let created = try? AVAudioPlayer(contentsOf: url) else { return }
            players[file] = created
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

    init(size: CGFloat = 44) { self.size = size }

    var body: some View {
        RoundIconButton(systemName: soundOn ? "speaker.wave.2.fill" : "speaker.slash.fill", size: size) {
            soundOn.toggle()
        }
        .accessibilityLabel(soundOn ? "Spuk-Sounds aus" : "Spuk-Sounds an")
    }
}
