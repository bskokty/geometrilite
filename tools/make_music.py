"""Neon Pulse için özgün, basit müzik döngüsü üretir (assets/audio/loop.wav).
Telif sorunu yok: tüm sesler bu betikte sentezlenir. 128 BPM, la minör, 8 ölçü."""
import wave, numpy as np

SR = 22050
BPM = 128
BEAT = 60 / BPM
BARS = 8
N = int(SR * BEAT * 4 * BARS)
t_beat = lambda b: int(b * BEAT * SR)
out = np.zeros(N + SR)


def add(start, sig, vol):
    s = t_beat(start)
    e = min(len(out), s + len(sig))
    out[s:e] += sig[: e - s] * vol


def kick():
    t = np.arange(int(0.22 * SR)) / SR
    f = 50 + 110 * np.exp(-t * 28)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 14)


def hat():
    t = np.arange(int(0.05 * SR)) / SR
    rng = np.random.default_rng(1)
    return rng.uniform(-1, 1, len(t)) * np.exp(-t * 90)


def tone(freq, dur, kind="saw", decay=6.0):
    t = np.arange(int(dur * SR)) / SR
    ph = (freq * t) % 1.0
    w = (2 * ph - 1) if kind == "saw" else np.where(ph < 0.5, 1.0, -1.0)
    return w * np.exp(-t * decay) * np.minimum(1, t * 400)


hz = lambda m: 440 * 2 ** ((m - 69) / 12)
K, H = kick(), hat()
# la minör: Am - F - C - G (ölçü başına bas kökü)
roots = [45, 41, 48, 43]
chords = [[57, 60, 64], [53, 57, 60], [60, 64, 67], [55, 59, 62]]
for bar in range(BARS):
    b0 = bar * 4
    r = roots[(bar // 2) % 4]
    for beat in range(4):
        add(b0 + beat, K, 0.9)
        add(b0 + beat + 0.5, H, 0.18)
        add(b0 + beat, tone(hz(r), BEAT * 0.5, "saw", 7), 0.28)
        add(b0 + beat + 0.5, tone(hz(r + (12 if beat % 2 else 0)), BEAT * 0.45, "saw", 8), 0.2)
    ch = chords[(bar // 2) % 4]
    for i in range(8):  # sekizlik arpej
        add(b0 + i * 0.5, tone(hz(ch[i % 3] + 12), BEAT * 0.5, "sq", 5), 0.11)
    if bar % 2 == 1:  # melodi vurgusu
        for i, n in enumerate([ch[2] + 24, ch[1] + 24, ch[0] + 24, ch[1] + 24]):
            add(b0 + 2 + i * 0.5, tone(hz(n), BEAT * 0.5, "sq", 4), 0.1)

# döngü: kuyruğu başa ekle
tail = out[N:]
out[: len(tail)] += tail
out = out[:N]
out = np.tanh(out * 1.3) * 0.8
pcm = (out * 32767).astype("<i2")
with wave.open("assets/audio/loop.wav", "wb") as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(pcm.tobytes())
print("ok", N / SR, "sn")
