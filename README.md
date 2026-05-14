# audio-spectrum-3d-kit

Audio feature extraction and portable 3D spectrogram mesh generation.

This repository packages the reusable audio pipeline extracted from LungListener into a general-purpose toolkit. It takes a WAV or PCM stream, computes normalized spectrogram data, builds a 3-channel `3 x 128 x 128` log-mel tensor, and emits a 3D height-map mesh that can be rendered by HarmonyOS ArkGraphics 3D, Three.js, Unity, or any mesh renderer.

It does not include patient management, medical workflow UI, private signing material, or clinical datasets.

## What It Provides

- Python package and CLI for WAV to spectrogram, mel tensor, and mesh JSON.
- HarmonyOS ArkTS core algorithms for STFT, mel tensor extraction, and mesh construction.
- A model hook format for plugging in your own ONNX or MindSpore Lite classifier.
- MindSpore Lite conversion notes for fixed-shape `1 x 3 x 128 x 128` NCHW models.

## Feature Format

The default model-ready feature tensor uses:

```text
shape: 3 x 128 x 128
layout: CHW
dtype: float32
range: [0, 1]
sample rate: 16000 Hz
duration: first 5 seconds
channels:
  0: 64-mel, hop 256
  1: 128-mel, hop 256
  2: 64-mel, hop 512
```

The 3D mesh output contains:

```text
vertices: [[x, y, z], ...]
normals: [[x, y, z], ...]
colors: [[r, g, b, a], ...]
indices: triangle-list indices
stats: time/frequency bin counts and triangle count
```

## Python Quick Start

```bash
cd packages/python
python3 -m venv .venv
source .venv/bin/activate
pip install -e .

audio-spectrum3d input.wav --out output.json --tensor-out mel.npy
```

Use the API directly:

```python
from audio_spectrum_3d import load_wav_mono, spectrogram, mel_tensor, build_spectrum_mesh

pcm, sr = load_wav_mono("input.wav")
spec = spectrogram(pcm)
tensor = mel_tensor(pcm)       # (3, 128, 128), float32
mesh = build_spectrum_mesh(spec)
```

## HarmonyOS Quick Start

Copy `packages/harmonyos/src/main/ets/audio_spectrum_3d` into your HarmonyOS module, then:

```ts
import { Spectrogram, MelTensor, SpectrumMeshBuilder } from './audio_spectrum_3d';

const spec = Spectrogram.compute(pcmData, 16000);
const tensor = await MelTensor.compute(pcmData, 16000);
const mesh = SpectrumMeshBuilder.build(spec);
```

`mesh.vertices`, `mesh.indices`, `mesh.normals`, and `mesh.colors` can be adapted to `CustomGeometry`, WebGL, or another rendering target.

## Model Hook

This package intentionally keeps model inference optional. A classifier can consume the mel tensor as `1 x 3 x 128 x 128` NCHW:

```text
input name: input
input shape: 1,3,128,128
output shape: 1,N
```

For the LungListener v8 lung-sound classifier, `N=4` with labels:

```text
normal, crackle, wheeze, both
```

That model is a domain-specific example, not required by this package.

## Repository Layout

```text
packages/python/      Python package and CLI
packages/harmonyos/   HarmonyOS ArkTS core algorithms
examples/python-cli/  Minimal example script
docs/                 Integration and format notes
scripts/              Optional model conversion helper
```

## Safety

This toolkit is for signal processing, visualization, prototyping, and research workflows. It is not a medical device and does not provide diagnosis.

## License

MIT
