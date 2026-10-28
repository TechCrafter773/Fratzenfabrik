"""Erzeugt die Sounds fürs Krokodilspiel (WAV). Aufruf: python3 tools/make_croc_sounds.py <ordner>

Danach nach AAC wandeln, z. B.:
  for f in <ordner>/fx_croc_*.wav; do ffmpeg -y -i "$f" -c:a aac -b:a 96k "${f%.wav}.m4a"; done
"""
import sys

import numpy as np

import make_character_sounds as fx
from make_character_sounds import SR, T, biquad, bell, chirp, env_ad, noise, place, reverb


def clack(d=0.05, f=2200):
    return biquad(noise(d), "bp", f, 1.5) * env_ad(int(SR * d), 0.001, 0.012) * 3


def thump(base=60, d=0.25):
    t = T(d)
    return np.sin(2 * np.pi * (base + 90 * np.exp(-t / 0.025)) * t) * np.exp(-t / 0.08)


def growl(d, pitch=70):
    t = T(d)
    f0 = pitch * (1 + 0.15 * np.sin(2 * np.pi * 9 * t))
    x = fx.osc(f0, "saw") * (0.6 + 0.4 * np.sin(2 * np.pi * 23 * t))
    return biquad(x, "lp", 500, 0.9) * fx.env_shape(len(x), [(0, 0), (0.04, 1), (d * 0.7, 0.8), (d, 0)])


def croc_snap():
    """Großes Zuschnappen: Rumpeln, dann Zähne-Klack mit Wumms."""
    rumble = growl(0.22, 62) * 0.7
    whoosh = biquad(noise(0.16), "bp", np.linspace(500, 2400, int(SR * 0.16)), 1.2) * env_ad(int(SR * 0.16), 0.12, 0.03)
    return place(0.75, (0, rumble), (0.05, whoosh * 0.8), (0.2, clack(0.07, 1800) * 1.6), (0.2, thump(55) * 1.6),
                 (0.24, clack(0.05, 3200) * 0.6))


def croc_twitch():
    """Zucken: kurzes Knurren und ein leises Zähne-Klappern."""
    return place(0.45, (0, growl(0.25, 80) * 0.8), (0.12, clack(0.03, 2600) * 0.7), (0.19, clack(0.03, 2400) * 0.5))


def croc_escape():
    """Entwischt: schneller Schwupp nach oben und ein Glitzer-Pling."""
    sw = chirp(300, 1600, 0.22, "tri", 2.0) * env_ad(int(SR * 0.22), 0.02, 0.12) * 0.7
    air = biquad(noise(0.25), "hp", 2500, 0.7) * env_ad(int(SR * 0.25), 0.05, 0.08) * 0.4
    plings = [(0.18 + i * 0.07, bell(f, 0.6, 0.25) * 0.5) for i, f in enumerate([1568, 2093, 2637])]
    return reverb(place(1.0, (0, sw), (0, air), *plings), 0.25)


def croc_caught():
    """Geschnappt: Mampf, dann lustiges Wah-wah-waaah."""
    chomp = place(0.3, (0, clack(0.06, 1800) * 1.4), (0, thump(58) * 1.4))
    notes = [(0.35, 392.0, 0.22), (0.6, 370.0, 0.22), (0.85, 349.2, 0.22), (1.1, 329.6, 0.6)]
    horn = []
    for start, f, d in notes:
        t = T(d)
        vib = 1 + (0.02 if d > 0.3 else 0.0) * np.sin(2 * np.pi * 6 * t)
        tone = fx.osc(f * vib, "saw")
        tone = biquad(tone, "lp", 900 + 600 * np.exp(-t / 0.1), 2.0)
        horn.append((start, tone * fx.env_shape(len(t), [(0, 0), (0.03, 1), (d * 0.8, 0.8), (d, 0)]) * 0.5))
    return reverb(place(1.9, (0, chomp), *horn), 0.18)


def croc_early():
    """Zu früh gezuckt: Boing-Feder."""
    t = T(0.6)
    f = 180 + 260 * np.exp(-t / 0.15) * (1 + 0.3 * np.sin(2 * np.pi * 14 * t))
    boing = fx.osc(f, "sine") * np.exp(-t / 0.22)
    return place(0.7, (0, boing), (0, clack(0.03, 2000) * 0.5))


def croc_slow():
    """Krokodil zu langsam: gähnendes Abwärts-Brummen."""
    t = T(0.9)
    yawn = fx.osc(160 * np.exp(-t / 1.4), "saw")
    yawn = biquad(yawn, "lp", 700 * np.exp(-t / 0.8) + 200, 1.5) * fx.env_shape(len(t), [(0, 0), (0.1, 1), (0.7, 0.7), (0.9, 0)])
    return reverb(yawn * 0.7, 0.2)


def croc_win():
    """Sieg-Fanfare in Glitzer-Gold."""
    arp = [523.3, 659.3, 784.0, 1046.5]
    parts = []
    for i, f in enumerate(arp):
        d = 0.5 if i < 3 else 1.1
        t = T(d)
        tone = (fx.osc(f, "tri") + 0.3 * fx.osc(f * 2, "sine")) * np.exp(-t / (0.25 if i < 3 else 0.6))
        parts.append((i * 0.12, tone * 0.5))
    sparkle = [(0.4 + i * 0.05, bell(np.random.default_rng(i).uniform(2500, 4500), 0.3, 0.12) * 0.25) for i in range(10)]
    return reverb(place(1.8, *parts, *sparkle), 0.3)


def croc_hello():
    """Verbunden: zwei freundliche Glöckchen."""
    return reverb(place(0.9, (0, bell(1046.5, 0.6, 0.25) * 0.6), (0.14, bell(1568, 0.7, 0.3) * 0.6)), 0.3)


ALL = [croc_snap, croc_twitch, croc_escape, croc_caught, croc_early, croc_slow, croc_win, croc_hello]

if __name__ == "__main__":
    fx.OUT = sys.argv[1] if len(sys.argv) > 1 else "."
    for fn in ALL:
        fx.finish(fn.__name__, fn())
