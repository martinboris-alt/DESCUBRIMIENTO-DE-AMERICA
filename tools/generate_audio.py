"""Genera los efectos de sonido del juego como WAV 22050Hz mono 16-bit.
Solo usa la libreria estandar. Uso: python tools/generate_audio.py
"""
import wave
import math
import random
import struct
import os

SR = 22050
OUT = r"C:\Users\Martin\Documents\GitHub\JUEGO CONQUISTA DE AMERICA\nuevo-proyecto-de-juego\assets\audio"
os.makedirs(OUT, exist_ok=True)
random.seed(1519)


def save(name, samples, volume=0.8):
    peak = max(1e-9, max(abs(s) for s in samples))
    norm = volume / peak
    with wave.open(os.path.join(OUT, name), "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        frames = b"".join(
            struct.pack("<h", int(max(-1.0, min(1.0, s * norm)) * 32767))
            for s in samples
        )
        w.writeframes(frames)
    print(f"  {name}: {len(samples)/SR:.2f}s")


def silence(dur):
    return [0.0] * int(SR * dur)


def mix(base, add, at=0.0):
    i0 = int(at * SR)
    need = i0 + len(add) - len(base)
    if need > 0:
        base.extend([0.0] * need)
    for i, s in enumerate(add):
        base[i0 + i] += s
    return base


def tone(freq, dur, vol=1.0, decay=6.0, wave_fn=math.sin, sweep=1.0, vib=0.0):
    n = int(SR * dur)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / n
        f = freq * (sweep ** t)
        if vib:
            f *= 1.0 + 0.02 * math.sin(2 * math.pi * vib * i / SR)
        phase += 2 * math.pi * f / SR
        env = math.exp(-decay * t) * min(1.0, i / (SR * 0.004))
        out.append(wave_fn(phase) * env * vol)
    return out


def noise_burst(dur, vol=1.0, decay=8.0, lowpass=0.3):
    n = int(SR * dur)
    out = []
    prev = 0.0
    for i in range(n):
        t = i / n
        s = random.uniform(-1, 1)
        prev += lowpass * (s - prev)
        env = math.exp(-decay * t)
        out.append(prev * env * vol)
    return out


def square(p):
    return 1.0 if math.sin(p) > 0 else -1.0


# ── SFX ───────────────────────────────────────────────────────────────
save("coin.wav", mix(tone(1318, 0.05, 0.7, 4), tone(1760, 0.16, 0.8, 9), 0.045), 0.55)

crate = noise_burst(0.16, 1.0, 14, 0.45)
mix(crate, tone(170, 0.1, 0.9, 18), 0.0)
mix(crate, noise_burst(0.05, 0.6, 20, 0.7), 0.03)
save("crate.wav", crate, 0.7)

save("jump.wav", tone(330, 0.17, 0.8, 7, sweep=2.4), 0.5)
save("bounce.wav", tone(220, 0.28, 0.9, 5, sweep=4.0, vib=9), 0.6)
save("land.wav", mix(noise_burst(0.08, 0.5, 18, 0.35), tone(120, 0.07, 0.8, 20)), 0.45)

spin = []
n = int(SR * 0.30)
prev = 0.0
for i in range(n):
    t = i / n
    s = random.uniform(-1, 1)
    prev += (0.12 + 0.5 * t) * (s - prev)
    env = math.sin(math.pi * min(1.0, t * 1.15)) ** 2
    spin.append(prev * env)
save("spin.wav", spin, 0.5)

save("hurt.wav", tone(160, 0.3, 1.0, 7, wave_fn=square, sweep=0.5), 0.4)

edie = mix(noise_burst(0.12, 0.8, 12, 0.4), tone(300, 0.4, 0.9, 6, sweep=0.25), 0.02)
save("enemy_die.wav", edie, 0.6)

chk = []
for k, f in enumerate([523, 659, 784]):
    mix(chk, tone(f, 0.22, 0.8, 6), k * 0.09)
save("checkpoint.wav", chk, 0.6)

idol = []
for k, f in enumerate([523, 659, 784, 1047, 1319]):
    mix(idol, tone(f, 0.45, 0.7, 4), k * 0.08)
mix(idol, tone(2093, 0.5, 0.25, 3), 0.35)
save("idol.wav", idol, 0.65)

win = []
for k, (f, d) in enumerate([(392, 0.18), (392, 0.12), (392, 0.12), (523, 0.5), (659, 0.6)]):
    at = sum(x for x in [0.0, 0.2, 0.34, 0.48, 0.8][: k + 1]) if k else 0.0
    mix(win, tone(f, d, 0.8, 3), at)
    mix(win, tone(f * 2, d, 0.25, 4), at)
save("win.wav", win, 0.65)

lose = []
for k, f in enumerate([392, 330, 262]):
    mix(lose, tone(f, 0.5, 0.8, 4, wave_fn=square), k * 0.3)
save("lose.wav", lose, 0.4)

save("tnt_tick.wav", tone(1100, 0.07, 0.8, 12), 0.5)

boom = noise_burst(0.9, 1.0, 5, 0.12)
mix(boom, tone(55, 0.7, 1.2, 5), 0.0)
mix(boom, tone(80, 0.4, 0.8, 8, sweep=0.5), 0.0)
save("tnt_boom.wav", boom, 0.85)

save("step.wav", noise_burst(0.05, 0.5, 25, 0.3), 0.25)

# ── Retumbo de la bola (loop 4s) ──────────────────────────────────────
rum_n = SR * 4
rum = [0.0] * rum_n
prev = 0.0
prev2 = 0.0
for i in range(rum_n):
    s = random.uniform(-1, 1)
    prev += 0.02 * (s - prev)
    prev2 += 0.08 * (prev - prev2)
    rum[i] = prev2 * 3.0
for k in range(8):
    mix(rum, tone(40 + random.uniform(-5, 5), 0.35, 0.8, 6), k * 0.5 + random.uniform(0, 0.1))
fade = SR // 2
for i in range(fade):
    k = i / fade
    rum[i] = rum[i] * k + rum[rum_n - fade + i] * (1 - k)
save("rumble.wav", rum[: rum_n - fade], 0.8)

# ── Ambiente jungla (loop 12s) ────────────────────────────────────────
amb_n = SR * 12
amb = [0.0] * amb_n
prev = 0.0
for i in range(amb_n):
    s = random.uniform(-1, 1)
    prev += 0.045 * (s - prev)
    amb[i] = prev * 0.30
# pajaros: chirridos aleatorios
for _ in range(26):
    at = random.uniform(0, 11.0)
    f0 = random.uniform(1400, 3200)
    chirp = tone(f0, random.uniform(0.06, 0.16), random.uniform(0.05, 0.12),
                 8, sweep=random.choice([1.6, 0.6, 2.2]))
    mix(amb, chirp, at)
# grillos: trino periodico
for burst in range(40):
    at = burst * 0.3 + random.uniform(0, 0.06)
    if at < 11.5:
        mix(amb, tone(4200, 0.05, 0.025, 10), at)
# crossfade para loop perfecto
fade = SR // 2
for i in range(fade):
    k = i / fade
    amb[i] = amb[i] * k + amb[amb_n - fade + i] * (1 - k)
save("ambient.wav", amb[: amb_n - fade], 0.5)

print("AUDIO_OK")
