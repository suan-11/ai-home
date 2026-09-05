#!/usr/bin/env python3
## AIHome 房间 BGM 生成器：一段 16 秒的暖色像素风循环（C 大调五声音阶旋律 + 和弦垫音 + 低音）。
## 输出：assets/sfx/bgm_room.wav（22050Hz / mono / 16bit）。可重复运行以重新生成。

import math
import struct
import wave

SR = 22050
DUR = 16.0
N = int(SR * DUR)
TWO_PI = 2.0 * math.pi

# 旋律：C4 E4 G4 A4 G4 E4 D4 C4 / G4 C5 A4 G4 E4 D4 C4 G3（约 1 秒一个音）
MELODY = [
    (261.63, 1.0), (329.63, 1.0), (392.00, 1.0), (440.00, 1.0),
    (392.00, 1.0), (329.63, 1.0), (293.66, 1.0), (261.63, 1.0),
    (392.00, 1.0), (523.25, 1.0), (440.00, 1.0), (392.00, 1.0),
    (329.63, 1.0), (293.66, 1.0), (261.63, 1.0), (196.00, 1.0),
]
PAD_CHORDS = [
    (130.81, 164.81, 196.00),   # C3 E3 G3
    (130.81, 164.81, 196.00),
    (146.83, 174.61, 220.00),   # D3 F3 A3
    (146.83, 174.61, 220.00),
]
BASS_LINE = [
    (65.41, 2.0), (65.41, 2.0), (73.42, 2.0), (73.42, 2.0),
    (65.41, 2.0), (65.41, 2.0),
    (87.31, 2.0), (87.31, 2.0),
    (65.41, 2.0), (65.41, 2.0),
    (73.42, 2.0), (73.42, 2.0),
    (65.41, 2.0), (65.41, 2.0),
    (58.27, 2.0), (58.27, 2.0),
]

def env(t_in_sec, attack=0.05, release=0.15):
    if t_in_sec < attack:
        return t_in_sec / attack
    return 1.0

def note_sample(freq, t, t_start, t_dur):
    dt = t - t_start
    if dt < 0.0 or dt > t_dur:
        return 0.0
    e = env(dt)
    if dt > t_dur - 0.15:
        e *= max(0.0, (t_dur - dt) / 0.15)
    vib = 1.0 + 0.003 * math.sin(TWO_PI * 5.2 * t)
    return math.sin(TWO_PI * freq * vib * t) * e

samples = []
for i in range(N):
    t = i / SR
    # 和弦垫音（缓慢呼吸）
    chord_idx = int(t // 4.0) % len(PAD_CHORDS)
    pad = 0.0
    for f in PAD_CHORDS[chord_idx]:
        pad += math.sin(TWO_PI * f * t) + 0.25 * math.sin(TWO_PI * f * 2.0 * t)
    pad_amp = 0.10 * (0.75 + 0.25 * math.sin(TWO_PI * t / 8.0))

    # 旋律
    mel = 0.0
    acc = 0.0
    for freq, dur in MELODY:
        if t < acc:
            break
        if t < acc + dur:
            mel = note_sample(freq, t, acc, dur)
            break
        acc += dur

    # 低音
    bass = 0.0
    acc = 0.0
    for freq, dur in BASS_LINE:
        if t < acc:
            break
        if t < acc + dur:
            bass = note_sample(freq, t, acc, dur) * 0.5
            break
        acc += dur

    v = pad * pad_amp + mel * 0.16 + bass * 0.10
    # 首尾淡入淡出防爆音（2.0 秒）
    if t < 2.0:
        v *= t / 2.0
    elif t > DUR - 2.0:
        v *= (DUR - t) / 2.0
    v = max(-1.0, min(1.0, v))
    samples.append(int(v * 32000))

with wave.open(r"assets/sfx/bgm_room.wav", "wb") as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes(struct.pack("<%dh" % len(samples), *samples))

print("bgm_room.wav generated:", len(samples), "samples,", DUR, "seconds")
