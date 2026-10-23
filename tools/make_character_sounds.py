"""Erzeugt für jede Fratze einen eigenen, passenden Effekt-Sound (WAV, mono, 44,1 kHz)."""
import math
import os
import sys
import wave

import numpy as np

SR = 44100
OUT = sys.argv[1]
rng = np.random.default_rng(7)


# ---------- Bausteine ----------

def T(d):
    return np.arange(int(SR * d)) / SR


def osc(freq, kind="sine"):
    freq = np.asarray(freq, dtype=float)
    ph = 2 * np.pi * np.cumsum(freq) / SR
    if kind == "sine":
        return np.sin(ph)
    frac = (ph / (2 * np.pi)) % 1.0
    if kind == "saw":
        return 2 * frac - 1
    if kind == "square":
        return np.where(frac < 0.5, 1.0, -1.0)
    if kind == "tri":
        return 2 * np.abs(2 * frac - 1) - 1
    raise ValueError(kind)


def noise(d):
    return rng.standard_normal(int(SR * d))


def env_ad(n, attack, decay_tau):
    t = np.arange(n) / SR
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    return a * np.exp(-np.maximum(t - attack, 0) / decay_tau)


def env_shape(n, points):
    """Hüllkurve aus (Zeit, Pegel)-Punkten."""
    t = np.arange(n) / SR
    ts, vs = zip(*points)
    return np.interp(t, ts, vs)


def biquad_coeffs(kind, f0, q, gain_db=0.0):
    w0 = 2 * math.pi * min(max(f0, 20), SR * 0.45) / SR
    alpha = math.sin(w0) / (2 * q)
    cw = math.cos(w0)
    if kind == "lp":
        b = [(1 - cw) / 2, 1 - cw, (1 - cw) / 2]
        a = [1 + alpha, -2 * cw, 1 - alpha]
    elif kind == "hp":
        b = [(1 + cw) / 2, -(1 + cw), (1 + cw) / 2]
        a = [1 + alpha, -2 * cw, 1 - alpha]
    elif kind == "bp":
        b = [alpha, 0, -alpha]
        a = [1 + alpha, -2 * cw, 1 - alpha]
    else:
        raise ValueError(kind)
    return [x / a[0] for x in b], [1, a[1] / a[0], a[2] / a[0]]


def biquad(x, kind, f0, q=0.707, block=64):
    """Biquad-Filter; f0 darf ein Array sein (zeitvariabel, blockweise)."""
    x = np.asarray(x, dtype=float)
    y = np.zeros_like(x)
    f0s = np.broadcast_to(np.asarray(f0, dtype=float), x.shape)
    x1 = x2 = y1 = y2 = 0.0
    for start in range(0, len(x), block):
        b, a = biquad_coeffs(kind, float(f0s[start]), q)
        b0, b1, b2 = b
        _, a1, a2 = a
        for i in range(start, min(start + block, len(x))):
            xi = x[i]
            yi = b0 * xi + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
            x2, x1, y2, y1 = x1, xi, y1, yi
            y[i] = yi
    return y


def formants(x, f1, f2, f3=2600, q=6):
    return biquad(x, "bp", f1, q) * 1.0 + biquad(x, "bp", f2, q) * 0.6 + biquad(x, "bp", f3, q) * 0.25


def comb(x, delay, fb):
    y = np.copy(x)
    for i in range(delay, len(y)):
        y[i] += fb * y[i - delay]
    return y


def allpass(x, delay, g=0.5):
    y = np.zeros_like(x)
    buf = np.zeros(len(x) + delay)
    for i in range(len(x)):
        d = buf[i]
        v = x[i] + g * d
        buf[i + delay] = v
        y[i] = d - g * v
    return y


def reverb(x, wet=0.3, size=1.0, tail=0.8):
    x = np.concatenate([x, np.zeros(int(SR * tail))])
    combs = [int(SR * s * size) for s in (0.0297, 0.0371, 0.0411, 0.0437)]
    r = sum(comb(x, d, 0.78) for d in combs) / 4
    r = allpass(allpass(r, int(SR * 0.005)), int(SR * 0.0017))
    return (1 - wet) * x + wet * r


def pluck(freq, d, damp=0.996):
    """Karplus-Strong-Saite."""
    n = int(SR * d)
    period = max(2, int(SR / freq))
    buf = rng.uniform(-1, 1, period)
    out = np.zeros(n)
    for i in range(n):
        out[i] = buf[i % period]
        buf[i % period] = damp * 0.5 * (buf[i % period] + buf[(i + 1) % period])
    return out


def bell(freq, d, decay=0.6):
    t = T(d)
    partials = [(1, 1.0), (2.76, 0.5), (5.4, 0.25), (8.9, 0.12)]
    return sum(a * np.sin(2 * np.pi * freq * r * t) * np.exp(-t / (decay / r ** 0.6)) for r, a in partials)


def place(total, *parts):
    """Legt (Startzeit, Signal)-Teile auf eine Spur."""
    out = np.zeros(int(SR * total))
    for start, sig in parts:
        s = int(SR * start)
        e = min(len(out), s + len(sig))
        out[s:e] += sig[: e - s]
    return out


def chirp(f_from, f_to, d, kind="sine", curve=1.0):
    t = np.linspace(0, 1, int(SR * d))
    return osc(f_from + (f_to - f_from) * t ** curve, kind)


def contour(d, points):
    t = np.linspace(0, d, int(SR * d))
    ts, fs = zip(*points)
    return np.interp(t, ts, fs)


def finish(name, x, target_rms=0.16):
    x = np.asarray(x, dtype=float)
    x = x - np.mean(x)
    # Leise Ausklingzeit abschneiden
    blk = int(SR * 0.02)
    levels = [np.sqrt(np.mean(x[i:i + blk] ** 2)) for i in range(0, len(x), blk)]
    peak_level = max(levels)
    active = [i for i, v in enumerate(levels) if v > peak_level * 0.02]
    end = min(len(x), (active[-1] + 1) * blk + int(SR * 0.12))
    x = x[:end]
    rms = np.sqrt(np.mean(x ** 2)) + 1e-9
    gain = min(target_rms / rms, 1.8 / (np.max(np.abs(x)) + 1e-9))
    x = x * gain
    # Sanfter Limiter: nur Spitzen über 0,8 werden weich abgerundet
    over = np.abs(x) > 0.8
    x[over] = np.sign(x[over]) * (0.8 + 0.18 * np.tanh((np.abs(x[over]) - 0.8) / 0.18))
    fade = int(SR * 0.006)
    x[:fade] *= np.linspace(0, 1, fade)
    tail = int(SR * 0.08)
    x[-tail:] *= np.linspace(1, 0, tail)
    with wave.open(os.path.join(OUT, f"fx_{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())
    print("ok", name, round(len(x) / SR, 2), "s", "rms", round(float(np.sqrt(np.mean(x ** 2))), 3))


# ---------- Figuren ----------

def voice(d, pitch_points, f1_points, f2_points, breath=0.05, kind="saw", vibrato=(5.5, 0.012)):
    f0 = contour(d, pitch_points)
    t = T(d)[: len(f0)]
    f0 = f0 * (1 + vibrato[1] * np.sin(2 * np.pi * vibrato[0] * t))
    src = osc(f0, kind) + breath * rng.standard_normal(len(f0))
    return formants(src, contour(d, f1_points), contour(d, f2_points))


def ghostCute():
    d = 1.1
    f = contour(d, [(0, 620), (0.35, 880), (0.8, 760), (1.1, 700)]) * (1 + 0.02 * np.sin(2 * np.pi * 6 * T(d)))
    oo = osc(f) * env_shape(len(f), [(0, 0), (0.15, 1), (0.8, 0.8), (1.1, 0)])
    sparkle = place(d, (0.55, 0.3 * bell(2093, 0.5, 0.3)), (0.7, 0.25 * bell(2637, 0.4, 0.25)), (0.82, 0.2 * bell(3136, 0.3, 0.2)))
    return reverb(oo * 0.7 + sparkle, 0.35)


def ghostFunny():
    boing = chirp(900, 160, 0.35, curve=0.4) * (1 + 0.6 * np.sin(2 * np.pi * 28 * T(0.35))) * env_ad(int(SR * 0.35), 0.005, 0.18)
    woo = osc(contour(0.7, [(0, 300), (0.3, 750), (0.45, 600), (0.7, 950)]), "tri") * env_shape(int(SR * 0.7), [(0, 0), (0.05, 1), (0.6, 0.9), (0.7, 0)])
    return reverb(place(1.15, (0, boing), (0.4, woo * 0.8)), 0.2)


def ghostScary():
    d = 2.0
    moan = voice(d, [(0, 120), (0.6, 150), (1.4, 110), (2.0, 95)], [(0, 380), (2, 420)], [(0, 760), (2, 700)], breath=0.3)
    moan *= env_shape(len(moan), [(0, 0), (0.4, 1), (1.5, 0.8), (2.0, 0)]) * (1 + 0.3 * np.sin(2 * np.pi * 3 * T(d)[: len(moan)]))
    wind = biquad(noise(d), "bp", contour(d, [(0, 500), (1, 1200), (2, 400)]), 3) * 0.6
    return reverb(moan + wind, 0.5, 1.4, 1.2)


def cat():
    d = 0.75
    return voice(d, [(0, 480), (0.2, 720), (0.5, 640), (0.75, 430)], [(0, 320), (0.25, 820), (0.75, 420)],
                 [(0, 2300), (0.25, 1500), (0.75, 900)], breath=0.08, vibrato=(7, 0.02)) * env_shape(int(SR * d), [(0, 0), (0.06, 1), (0.6, 0.8), (0.75, 0)])


def cyclops():
    d = 1.0
    t = T(d)
    warble = np.sin(2 * np.pi * np.cumsum(320 + 160 * np.sin(2 * np.pi * 7 * t)) / SR) * np.sin(2 * np.pi * 47 * t)
    blink = chirp(200, 1200, 0.08) * env_ad(int(SR * 0.08), 0.002, 0.03)
    return reverb(place(1.1, (0, blink), (0.12, warble * env_shape(len(t), [(0, 0), (0.1, 1), (0.8, 0.7), (1.0, 0)]))), 0.25)


def pumpkin():
    pop = chirp(180, 60, 0.12) * env_ad(int(SR * 0.12), 0.001, 0.05)
    notes = [261.6, 329.6, 392.0, 523.3]
    arp = [(0.12 + i * 0.09, pluck(f, 0.6)) for i, f in enumerate(notes)]
    return reverb(place(1.1, (0, pop * 1.5), *arp), 0.2)


def witch():
    parts = []
    for i in range(7):
        f0 = 980 - i * 55
        d = 0.085
        burst = voice(d, [(0, f0 * 1.1), (d, f0)], [(0, 850), (d, 800)], [(0, 1350), (d, 1250)], breath=0.2)
        parts.append((i * 0.125, burst * env_ad(len(burst), 0.005, 0.04)))
    sparkle = (0.95, 0.4 * bell(2793, 0.45, 0.25))
    return reverb(place(1.45, *parts, sparkle), 0.25)


def devil():
    parts = []
    for i in range(5):
        d = 0.16
        burst = voice(d, [(0, 140 - i * 6), (d, 118 - i * 6)], [(0, 720), (d, 650)], [(0, 1150), (d, 1050)], breath=0.25)
        parts.append((i * 0.2, np.tanh(burst * 3) * env_ad(len(burst), 0.01, 0.07)))
    fire = biquad(noise(0.9), "lp", contour(0.9, [(0, 300), (0.4, 2500), (0.9, 600)]), 0.9) * env_shape(int(SR * 0.9), [(0, 0), (0.3, 0.7), (0.9, 0)])
    return reverb(place(1.6, *parts, (0.55, fire * 0.6)), 0.3, 1.2)


def mummy():
    d = 1.7
    groan = voice(d, [(0, 95), (0.8, 105), (1.7, 82)], [(0, 300), (1.7, 340)], [(0, 700), (1.7, 650)], breath=0.4)
    groan *= env_shape(len(groan), [(0, 0), (0.5, 1), (1.3, 0.8), (1.7, 0)]) * (1 + 0.25 * np.sin(2 * np.pi * 2.2 * T(d)[: len(groan)]))
    dust = biquad(noise(d), "hp", 3000, 0.7) * 0.05 * env_shape(int(SR * d), [(0, 0.2), (1.7, 1)])
    return reverb(groan + dust, 0.35, 1.3)


def spiderweb():
    total = 1.2
    clicks = []
    for _ in range(26):
        c = biquad(noise(0.004), "hp", 2500, 0.8) * np.hanning(int(SR * 0.004))
        clicks.append((rng.uniform(0.05, 0.9), c * rng.uniform(0.4, 1)))
    string = pluck(82.4, 1.0, 0.998) * 0.8
    return place(total, (0, string), *clicks)


def bat_sound(total, squeaks, flaps):
    parts = []
    for _ in range(squeaks):
        s = chirp(rng.uniform(2800, 3400), rng.uniform(4200, 5200), 0.06, curve=0.7) * env_ad(int(SR * 0.06), 0.003, 0.02)
        parts.append((rng.uniform(0.0, total - 0.15), s * 0.6))
    for i in range(flaps):
        f = biquad(noise(0.06), "lp", 700, 0.8) * np.hanning(int(SR * 0.06))
        parts.append((0.05 + i * 0.11, f * 1.6))
    return reverb(place(total, *parts), 0.2)


def bat():
    return bat_sound(1.0, 4, 8)


def batSwarm():
    return bat_sound(1.4, 14, 12)


def organ(freq, d):
    t = T(d)
    return sum(a * np.sin(2 * np.pi * freq * h * t) for h, a in [(1, 1), (2, 0.6), (3, 0.4), (4, 0.25), (6, 0.12)])


def vampire():
    d = 1.6
    chord = sum(organ(f, d) for f in [146.8, 174.6, 220.0, 293.7]) * env_shape(int(SR * d), [(0, 0), (0.08, 1), (1.2, 0.9), (1.6, 0)])
    return reverb(chord, 0.45, 1.5, 1.3)


def werewolf():
    d = 1.9
    howl = voice(d, [(0, 280), (0.35, 540), (1.3, 520), (1.9, 360)], [(0, 350), (0.4, 520), (1.9, 380)],
                 [(0, 800), (0.4, 950), (1.9, 700)], breath=0.15, kind="saw", vibrato=(5, 0.015))
    howl *= env_shape(len(howl), [(0, 0), (0.3, 1), (1.4, 0.9), (1.9, 0)])
    return reverb(howl, 0.45, 1.4, 1.2)


def marimba(freq, d=0.35):
    t = T(d)
    return (np.sin(2 * np.pi * freq * t) + 0.3 * np.sin(2 * np.pi * freq * 4 * t) * np.exp(-t / 0.03)) * np.exp(-t / 0.09)


def skeleton():
    notes = [1046.5, 880.0, 784.0, 659.3, 587.3, 523.3, 440.0, 392.0]
    parts = [(i * 0.07, marimba(f)) for i, f in enumerate(notes)]
    rattle = [(0.65 + i * 0.05, biquad(noise(0.02), "bp", 1800, 2) * np.hanning(int(SR * 0.02)) * 2) for i in range(8)]
    return place(1.2, *parts, *rattle)


def sugarSkull():
    shakes = [(i * 0.14, biquad(noise(0.07), "hp", 4000, 0.7) * env_ad(int(SR * 0.07), 0.01, 0.025) * 1.5) for i in range(6)]
    brass = [(0.2 + i * 0.15, biquad(osc(np.full(int(SR * 0.3), f), "saw"), "lp", 2200, 0.9) * env_shape(int(SR * 0.3), [(0, 0), (0.03, 1), (0.25, 0.7), (0.3, 0)]))
             for i, f in enumerate([392.0, 493.9, 587.3, 784.0])]
    return reverb(place(1.2, *shakes, *brass), 0.25)


def frankenstein():
    d = 1.2
    buzz = biquad(osc(np.full(int(SR * d), 60), "square"), "lp", 1800, 0.8) * 0.4
    crackle = np.zeros(int(SR * d))
    for _ in range(40):
        s = rng.integers(0, len(crackle) - 400)
        crackle[s:s + 300] += rng.standard_normal(300) * np.hanning(300) * rng.uniform(0.5, 1.5)
    whine = chirp(400, 2200, d, curve=1.5) * 0.25
    return (buzz + crackle * 0.5 + whine) * env_shape(int(SR * d), [(0, 0), (0.05, 1), (0.9, 1), (1.2, 0)])


def zombie():
    d = 1.5
    groan = voice(d, [(0, 85), (0.5, 95), (1.5, 75)], [(0, 520), (1.5, 480)], [(0, 1450), (1.5, 1300)], breath=0.35)
    rasp = 1 + 0.5 * np.sin(2 * np.pi * 31 * T(d)[: len(groan)])
    return reverb(groan * rasp * env_shape(len(groan), [(0, 0), (0.3, 1), (1.1, 0.8), (1.5, 0)]), 0.3)


def dragon():
    d = 1.6
    roar_src = osc(contour(d, [(0, 70), (0.4, 95), (1.6, 60)]), "saw") + 0.8 * noise(d)[: int(SR * d)]
    roar = np.tanh(formants(roar_src, contour(d, [(0, 500), (1.6, 650)]), contour(d, [(0, 1100), (1.6, 900)]), q=2.5) * 4)
    roar *= env_shape(len(roar), [(0, 0), (0.25, 1), (1.0, 0.8), (1.6, 0)])
    fire = biquad(noise(0.9), "lp", contour(0.9, [(0, 400), (0.5, 3500), (0.9, 800)]), 0.8) * env_shape(int(SR * 0.9), [(0, 0), (0.3, 1), (0.9, 0)])
    return reverb(place(1.8, (0, roar), (0.7, fire * 0.7)), 0.3, 1.3)


def unicorn():
    scale = [523.3, 587.3, 659.3, 784.0, 880.0, 1046.5, 1174.7, 1318.5, 1568.0]
    harp = [(i * 0.055, pluck(f, 0.8, 0.997) * 0.6) for i, f in enumerate(scale)]
    shimmer = [(0.55 + i * 0.07, 0.25 * bell(f, 0.5, 0.3)) for i, f in enumerate([2093, 2637, 3136, 4186])]
    return reverb(place(1.4, *harp, *shimmer), 0.35)


def mushroom():
    drops = [(i * 0.16, chirp(300 + i * 90, 900 + i * 180, 0.07, curve=0.5) * env_ad(int(SR * 0.07), 0.002, 0.03)) for i in range(4)]
    boing = (0.7, chirp(500, 1100, 0.25) * (1 + 0.5 * np.sin(2 * np.pi * 20 * T(0.25))) * env_ad(int(SR * 0.25), 0.003, 0.1))
    return reverb(place(1.1, *drops, boing), 0.2)


def pumpkinPrincess():
    notes = [523.3, 659.3, 784.0, 1046.5]
    chimes = [(i * 0.13, bell(f, 0.9, 0.5)) for i, f in enumerate(notes)]
    sparkle = [(0.6 + i * 0.05, 0.2 * bell(f, 0.3, 0.15)) for i, f in enumerate([3136, 3520, 4186, 4699])]
    return reverb(place(1.5, *chimes, *sparkle), 0.35)


def clown():
    def honk(d=0.16):
        src = osc(np.full(int(SR * d), 410), "square") + 0.6 * osc(np.full(int(SR * d), 415), "saw")
        return biquad(src, "bp", 1100, 1.5) * env_shape(int(SR * d), [(0, 0), (0.01, 1), (d - 0.03, 0.9), (d, 0)])
    slide = osc(contour(0.45, [(0, 600), (0.45, 1700)]) * (1 + 0.01 * np.sin(2 * np.pi * 7 * T(0.45))), "sine") * env_shape(int(SR * 0.45), [(0, 0), (0.05, 1), (0.4, 1), (0.45, 0)])
    return place(1.1, (0, honk() * 1.4), (0.22, honk() * 1.4), (0.55, slide * 0.7))


def clawMarks():
    parts = []
    for i in range(3):
        d = 0.14
        sw = biquad(noise(d), "bp", contour(d, [(0, 6000), (d, 1500)]), 2.5) * env_shape(int(SR * d), [(0, 0), (0.03, 1), (d, 0)])
        scratch = biquad(noise(d), "hp", 3500, 0.7) * (np.abs(np.sin(2 * np.pi * 90 * T(d))) > 0.7) * 0.4
        parts.append((i * 0.17, (sw + scratch) * 2))
    return reverb(place(0.9, *parts), 0.15)


def bloodTears():
    times = [0.0, 0.32, 0.55, 0.9]
    drops = [(t, chirp(520 + i * 40, 1500 + i * 120, 0.045, curve=0.4) * env_ad(int(SR * 0.045), 0.001, 0.015)) for i, t in enumerate(times)]
    return reverb(place(1.2, *drops), 0.45, 1.2)


def vampireBite():
    crunch = biquad(noise(0.09), "bp", 1600, 1.2) * env_ad(int(SR * 0.09), 0.002, 0.03) * 2

    def thump(d=0.13):
        t = T(d)
        return np.sin(2 * np.pi * (55 + 30 * np.exp(-t / 0.02)) * t) * np.exp(-t / 0.05)
    beats = [(0.25, thump()), (0.42, thump() * 0.7), (0.85, thump()), (1.02, thump() * 0.7)]
    return place(1.3, (0, crunch), *[(s, b * 2) for s, b in beats])


def brokenDoll():
    melody = [659.3, 784.0, 659.3, 587.3, 523.3, 493.9]
    box = []
    for i, f in enumerate(melody):
        detune = 1 + rng.uniform(-0.012, 0.012)
        t = T(0.5)
        tone = (np.sin(2 * np.pi * f * detune * t) + 0.4 * np.sin(2 * np.pi * f * 3.01 * t)) * np.exp(-t / 0.18)
        box.append((i * 0.16, tone * 0.6))
    crack = biquad(noise(0.05), "hp", 3000, 0.7) * env_ad(int(SR * 0.05), 0.001, 0.012) * 2.5
    tinkles = [(1.02 + i * 0.05, 0.3 * bell(rng.uniform(3000, 5000), 0.2, 0.08)) for i in range(4)]
    return reverb(place(1.5, *box, (1.0, crack), *tinkles), 0.3)


def spiderLashes():
    notes = [329.6, 311.1, 293.7, 277.2]
    plucks = [(i * 0.18, pluck(f, 0.5, 0.993)) for i, f in enumerate(notes)]
    clicks = [(0.75 + rng.uniform(0, 0.3), biquad(noise(0.004), "hp", 2500, 0.8) * np.hanning(int(SR * 0.004)))
              for _ in range(14)]
    return reverb(place(1.25, *plucks, *clicks), 0.2)


ALL = [ghostCute, ghostFunny, ghostScary, cat, cyclops, pumpkin, witch, devil, mummy, spiderweb, bat, batSwarm,
       vampire, werewolf, skeleton, sugarSkull, frankenstein, zombie, dragon, unicorn, mushroom, pumpkinPrincess,
       clown, clawMarks, bloodTears, vampireBite, brokenDoll, spiderLashes]

only = sys.argv[2:]
for fn in ALL:
    if only and fn.__name__ not in only:
        continue
    finish(fn.__name__, fn())
