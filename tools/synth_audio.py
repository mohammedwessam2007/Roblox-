#!/usr/bin/env python3
"""Deterministic original SFX synthesis. numpy + stdlib wave only.
Output: assets/audio/*.wav, mono, 44.1 kHz, 16-bit, peak -3 dBFS."""
import os
import wave
import numpy as np

SR = 44100
PEAK = 10 ** (-3 / 20)
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio")
RNG_SEED = 1337


def t_(d):
    return np.arange(int(SR * d)) / SR


def rng(tag):
    return np.random.default_rng(RNG_SEED + sum(ord(c) for c in tag))


def sweep(f0, f1, d, exp=True):
    t = t_(d)
    if exp:
        k = (f1 / f0) ** (1 / d)
        ph = 2 * np.pi * f0 * (k ** t - 1) / np.log(k)
    else:
        ph = 2 * np.pi * (f0 * t + (f1 - f0) * t ** 2 / (2 * d))
    return np.sin(ph)


def env(n, a=0.005, r=0.05, decay=None):
    t = np.arange(n) / SR
    e = np.ones(n)
    a_n = max(1, int(a * SR))
    e[:a_n] = np.linspace(0, 1, a_n)
    if decay:
        e *= np.exp(-t / decay)
    r_n = max(1, int(r * SR))
    e[-r_n:] *= np.linspace(1, 0, r_n)
    return e


def lowpass(x, k):
    y = np.zeros_like(x)
    a = k
    acc = 0.0
    for i, v in enumerate(x):
        acc += a * (v - acc)
        y[i] = acc
    return y


def noise(tag, d):
    return rng(tag).standard_normal(int(SR * d))


def place(buf, x, at):
    i = int(at * SR)
    n = min(len(x), len(buf) - i)
    buf[i:i + n] += x[:n]


def tone(f, d, decay=None, a=0.004, r=0.03, h=(1.0,)):
    t = t_(d)
    s = sum(w * np.sin(2 * np.pi * f * (i + 1) * t) for i, w in enumerate(h))
    return s * env(len(t), a, r, decay)


def steal_suction():
    d = 0.7
    n = lowpass(noise("suc", d), 0.15)
    s = sweep(180, 1100, d) * 0.6 + sweep(90, 550, d) * 0.4
    t = t_(d)
    trem = 1 + 0.3 * np.sin(2 * np.pi * 18 * t)
    return (s + 0.5 * n) * trem * env(len(t), 0.03, 0.12) * (0.3 + 0.7 * t / d)


def lawball_throw_whoosh():
    d = 0.45
    n = noise("wh", d)
    t = t_(d)
    lp = lowpass(n, 0.05) * 0.5 + (n - lowpass(n, 0.3)) * 0.3
    sw = np.sin(np.pi * t / d) ** 1.5
    return lp * sw + 0.2 * sweep(900, 250, d) * env(len(t), 0.01, 0.1)


def gravity_well_hum():
    d = 2.0  # integer cycles of all components over 2s -> seamless loop
    t = t_(d)
    x = (np.sin(2 * np.pi * 55 * t) + 0.5 * np.sin(2 * np.pi * 110.5 * t + 1)
         + 0.25 * np.sin(2 * np.pi * 165.5 * t))
    x *= 1 + 0.25 * np.sin(2 * np.pi * 3 * t)
    return x  # no fades: loop-safe (all freqs are multiples of 0.5 Hz)


def bank_boing():
    d = 0.55
    t = t_(d)
    f = 220 + 260 * np.exp(-t / 0.05) * np.sin(2 * np.pi * 9 * t) + 180 * np.exp(-t / 0.12)
    ph = 2 * np.pi * np.cumsum(f) / SR
    return (np.sin(ph) + 0.3 * np.sin(2 * ph)) * env(len(t), 0.002, 0.08, 0.18)


def bot_telegraph_alert():
    d = 1.1  # matches botTelegraphSeconds
    out = np.zeros(int(SR * d))
    for i in range(4):  # rising pulses
        place(out, tone(440 * 2 ** (i / 6), 0.12, 0.08, h=(1, 0.5, 0.25)), i * 0.27)
    place(out, tone(990, 0.1, 0.06, h=(1, 0.4)), 1.0 - 0.02)
    return out


def rubberband_recover():
    d = 0.6
    t = t_(d)
    f = 700 * np.exp(-t / 0.2) + 160
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(ph) * (1 + 0.5 * np.sin(2 * np.pi * 22 * t)) * env(len(t), 0.01, 0.1, 0.35)


def vault_swallow_victory():
    d = 0.8
    out = np.zeros(int(SR * d))
    place(out, sweep(500, 90, 0.3) * env(int(SR * 0.3), 0.01, 0.05), 0)
    for i, f in enumerate((523.25, 659.25, 783.99, 1046.5)):
        place(out, tone(f, 0.45, 0.2, h=(1, 0.4, 0.15)) * 0.7, 0.3 + i * 0.07)
    return out


def miss_squeak():
    d = 0.3
    t = t_(d)
    f = 1400 + 900 * np.sin(np.pi * t / d) + 60 * np.sin(2 * np.pi * 30 * t)
    ph = 2 * np.pi * np.cumsum(f) / SR
    return (np.sin(ph) + 0.2 * np.sin(2 * ph)) * env(len(t), 0.01, 0.06)


def ui_press():
    d = 0.09
    return (tone(880, d, 0.03, 0.001, 0.02, h=(1, 0.3)) * 0.8
            + lowpass(noise("ui", d), 0.4) * env(int(SR * d), 0.001, 0.02, 0.01) * 0.3)


def blackout_powerdown():
    d = 1.4
    t = t_(d)
    f = 600 * np.exp(-t / 0.35) + 40
    ph = 2 * np.pi * np.cumsum(f) / SR
    x = np.sign(np.sin(ph)) * 0.3 + np.sin(ph) * 0.7
    return x * env(len(t), 0.005, 0.15, 0.7)


def drone_alarm():
    d = 1.0
    t = t_(d)
    f = np.where(np.sin(2 * np.pi * 4 * t) > 0, 880, 660).astype(float)
    ph = 2 * np.pi * np.cumsum(f) / SR
    return (np.sin(ph) + 0.35 * np.sin(3 * ph)) * env(len(t), 0.01, 0.05)


def heist_escape_sting():
    d = 1.0
    out = np.zeros(int(SR * d))
    for i, f in enumerate((392.0, 493.88, 587.33, 783.99, 987.77)):
        place(out, tone(f, 0.3, 0.12, h=(1, 0.5, 0.2)), i * 0.09)
    place(out, tone(783.99, 0.5, 0.25, h=(1, 0.5)) * 0.6, 0.5)
    return out


SOUNDS = [
    steal_suction, lawball_throw_whoosh, gravity_well_hum, bank_boing,
    bot_telegraph_alert, rubberband_recover, vault_swallow_victory, miss_squeak,
    ui_press, blackout_powerdown, drone_alarm, heist_escape_sting,
]
NO_FADE = {"gravity_well_hum"}


def finish(name, x):
    x = np.asarray(x, dtype=np.float64)
    if name not in NO_FADE:
        n = int(0.004 * SR)
        x[:n] *= np.linspace(0, 1, n)
        x[-n:] *= np.linspace(1, 0, n)
    else:  # remove DC only; keep seamless loop
        x = x - x.mean()
    x = x / np.max(np.abs(x)) * PEAK
    return (np.round(x * 32767)).astype(np.int16)


def main():
    os.makedirs(OUT, exist_ok=True)
    for fn in SOUNDS:
        name = fn.__name__
        pcm = finish(name, fn())
        path = os.path.join(OUT, name + ".wav")
        with wave.open(path, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(pcm.tobytes())
        print(f"wrote {name}.wav  {len(pcm)/SR:.2f}s  peak={np.abs(pcm).max()/32767:.3f}")


if __name__ == "__main__":
    main()
