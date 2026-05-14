from __future__ import annotations

import math
import wave
from pathlib import Path

import numpy as np

sample_rate = 16_000
seconds = 5
t = np.arange(sample_rate * seconds, dtype=np.float32) / sample_rate
tone = 0.22 * np.sin(2 * math.pi * 180 * t)
chirp = 0.08 * np.sin(2 * math.pi * (220 + 520 * t / seconds) * t)
envelope = 0.5 + 0.5 * np.sin(2 * math.pi * 0.35 * t)
audio = np.clip((tone + chirp) * envelope, -1.0, 1.0)
pcm = (audio * 32767).astype("<i2")

out = Path(__file__).with_name("demo.wav")
with wave.open(str(out), "wb") as writer:
    writer.setnchannels(1)
    writer.setsampwidth(2)
    writer.setframerate(sample_rate)
    writer.writeframes(pcm.tobytes())

print(out)
