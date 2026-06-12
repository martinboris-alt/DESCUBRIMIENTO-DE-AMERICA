"""Genera pistas de música en loop (WAV 22050 mono) con beat fuerte para
sincronizar visuales tipo Geometry Dash. Solo stdlib.
Cada pista dura un número entero de compases => loop perfecto sin costura.

Salida: assets/audio/music_*.wav  +  un .json con BPM por pista.
"""
import wave
import math
import struct
import os
import json
import random

SR = 22050
OUT = r"C:\Users\Martin\Documents\GitHub\JUEGO CONQUISTA DE AMERICA\nuevo-proyecto-de-juego\assets\audio"
os.makedirs(OUT, exist_ok=True)


def midi(n):
    return 440.0 * (2 ** ((n - 69) / 12.0))


def adsr(i, n, a, d, s, r):
    if i < a:
        return i / max(1, a)
    if i < a + d:
        return 1.0 - (1.0 - s) * (i - a) / max(1, d)
    if i < n - r:
        return s
    return s * (1.0 - (i - (n - r)) / max(1, r))


def osc(phase, kind):
    if kind == "sine":
        return math.sin(phase)
    if kind == "square":
        return 1.0 if math.sin(phase) > 0 else -1.0
    if kind == "saw":
        return (phase / math.pi) % 2.0 - 1.0
    if kind == "tri":
        x = (phase / (2 * math.pi)) % 1.0
        return 4.0 * abs(x - 0.5) - 1.0
    return math.sin(phase)


def synth(buf, start_t, dur, freq, vol, kind="saw", a=0.005, d=0.05, s=0.7, r=0.05, detune=0.0):
    n = int(dur * SR)
    i0 = int(start_t * SR)
    aa, dd, rr = int(a * SR), int(d * SR), int(r * SR)
    ph = 0.0
    ph2 = 0.0
    for i in range(n):
        idx = i0 + i
        if idx >= len(buf):
            break
        ph += 2 * math.pi * freq / SR
        env = adsr(i, n, aa, dd, s, rr) * vol
        val = osc(ph, kind)
        if detune:
            ph2 += 2 * math.pi * freq * (1 + detune) / SR
            val = 0.6 * val + 0.4 * osc(ph2, kind)
        buf[idx] += val * env


def kick(buf, start_t, vol=1.0):
    n = int(0.18 * SR)
    i0 = int(start_t * SR)
    for i in range(n):
        idx = i0 + i
        if idx >= len(buf):
            break
        t = i / n
        f = 130 * (1 - t) + 45
        env = math.exp(-7 * t)
        buf[idx] += math.sin(2 * math.pi * f * i / SR) * env * vol


def snare(buf, start_t, vol=0.7):
    n = int(0.14 * SR)
    i0 = int(start_t * SR)
    prev = 0.0
    for i in range(n):
        idx = i0 + i
        if idx >= len(buf):
            break
        t = i / n
        s = random.uniform(-1, 1)
        prev += 0.5 * (s - prev)
        tone = math.sin(2 * math.pi * 190 * i / SR) * 0.4
        env = math.exp(-12 * t)
        buf[idx] += (prev * 0.7 + tone) * env * vol


def hat(buf, start_t, vol=0.3, dur=0.04):
    n = int(dur * SR)
    i0 = int(start_t * SR)
    for i in range(n):
        idx = i0 + i
        if idx >= len(buf):
            break
        t = i / n
        buf[idx] += random.uniform(-1, 1) * math.exp(-30 * t) * vol


def save(name, buf, bpm, peak=0.85):
    mx = max(1e-9, max(abs(x) for x in buf))
    g = peak / mx
    with wave.open(os.path.join(OUT, name), "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(
            struct.pack("<h", int(max(-1, min(1, x * g)) * 32767)) for x in buf))
    dur = len(buf) / SR
    print(f"  {name}: {dur:.1f}s  {bpm}bpm")
    return {"bpm": bpm, "dur": round(dur, 4)}


# Progresiones (MIDI root del acorde por compás) y escalas pentatónicas
def build(name, bpm, bars, chords, scale_root, lead_kind, energy):
    random.seed(hash(name) & 0xffff)
    beat = 60.0 / bpm
    bar = beat * 4
    total = bars * bar
    buf = [0.0] * int(total * SR + SR * 0.2)

    # pentatónica menor para el lead (grados)
    penta = [0, 3, 5, 7, 10]

    for b in range(bars):
        t0 = b * bar
        root = chords[b % len(chords)]
        # bajo: patrón de corcheas sobre la fundamental
        for j in range(8):
            bt = t0 + j * beat / 2
            note = root - 12 + (7 if j % 4 == 2 else 0)
            synth(buf, bt, beat / 2 * 0.9, midi(note), 0.55, "saw",
                  a=0.004, d=0.03, s=0.8, r=0.03, detune=0.004)
        # acorde pad (tríada menor sostenida)
        for off in (0, 3, 7):
            synth(buf, t0, bar * 0.98, midi(root + off), 0.12, "tri",
                  a=0.04, d=0.2, s=0.7, r=0.2)
        # percusión
        for k in range(4):
            kick(buf, t0 + k * beat, 1.0)
            if k in (1, 3):
                snare(buf, t0 + k * beat, 0.6)
        hats = 8 if energy < 2 else 16
        for k in range(hats):
            hat(buf, t0 + k * bar / hats, 0.22 if k % 2 else 0.32)
        # lead: riff pentatónico (sólo si energía media/alta)
        if energy >= 1:
            steps = 8 if energy == 1 else 8
            for j in range(steps):
                if random.random() < (0.55 + 0.1 * energy):
                    deg = penta[random.randint(0, 4)]
                    octv = 12 * random.choice([1, 1, 2])
                    lt = t0 + j * beat / 2
                    synth(buf, lt, beat / 2 * 0.85,
                          midi(scale_root + deg + octv), 0.3, lead_kind,
                          a=0.004, d=0.04, s=0.6, r=0.05, detune=0.006)
    return save(name, buf, bpm)


def main():
    meta = {}
    # Nivel 1: aventura tropical, Am-F-C-G, alegre, energía media
    meta["music_level1"] = build("music_level1.wav", 122, 8,
        [57, 53, 60, 55], 57, "square", 1)
    # Nivel 2: persecución tensa, Dm-Bb-F-C rápido, energía alta
    meta["music_level2"] = build("music_level2.wav", 138, 8,
        [50, 46, 53, 48], 50, "saw", 2)
    # Nivel 3: épico oscuro, Em-C-G-D, energía alta
    meta["music_level3"] = build("music_level3.wav", 128, 8,
        [52, 48, 55, 50], 52, "square", 2)
    # Jefe: intenso, Am-Am-G-G, energía máxima
    meta["music_boss"] = build("music_boss.wav", 144, 8,
        [57, 57, 55, 55], 57, "saw", 2)
    with open(os.path.join(OUT, "music_meta.json"), "w") as f:
        json.dump(meta, f, indent=1)
    print("MUSIC_OK")


if __name__ == "__main__":
    main()
