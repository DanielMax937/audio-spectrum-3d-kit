from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np

from .features import load_wav_mono, mel_tensor, spectrogram
from .mesh import build_spectrum_mesh


def main() -> None:
    parser = argparse.ArgumentParser(description="Extract audio features and build a portable 3D spectrogram mesh.")
    parser.add_argument("audio", help="Input PCM WAV file.")
    parser.add_argument("--out", default="spectrum3d.json", help="Output JSON path.")
    parser.add_argument("--tensor-out", default="", help="Optional .npy path for the 3x128x128 mel tensor.")
    args = parser.parse_args()

    pcm, sample_rate = load_wav_mono(args.audio)
    spec = spectrogram(pcm)
    mesh = build_spectrum_mesh(spec)
    tensor = mel_tensor(pcm)

    payload = {
        "source": str(Path(args.audio)),
        "sampleRate": sample_rate,
        "duration": float(pcm.size / sample_rate),
        "spectrogram": {
            "timeBins": spec["timeBins"],
            "freqBins": spec["freqBins"],
            "maxFreq": spec["maxFreq"],
            "maxTime": spec["maxTime"],
            "matrix": np.asarray(spec["matrix"]).round(6).tolist(),
        },
        "melTensor": {
            "shape": list(tensor.shape),
            "layout": "CHW",
            "dtype": "float32",
            "range": [float(tensor.min()), float(tensor.max())],
        },
        "mesh": mesh,
    }
    Path(args.out).write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    if args.tensor_out:
        np.save(args.tensor_out, tensor)
    print(f"wrote {args.out}")


if __name__ == "__main__":
    main()
