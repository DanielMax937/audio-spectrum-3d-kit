# HarmonyOS Audio Spectrum 3D Kit

HarmonyOS ArkTS toolkit for audio feature extraction and 3D spectrogram mesh generation.

This repository packages the reusable audio pipeline extracted from LungListener into a HarmonyOS-focused component. It takes PCM audio samples, computes normalized spectrogram data, builds a 3-channel `3 x 128 x 128` log-mel tensor, and emits a 3D height-map mesh that can be adapted to ArkGraphics 3D `CustomGeometry`.

It does not include patient management, medical workflow UI, private signing material, clinical datasets, or non-HarmonyOS runtime packages.

## What It Provides

- HarmonyOS ArkTS core algorithms for STFT spectrogram extraction.
- HarmonyOS ArkTS log-mel tensor extraction compatible with `1 x 3 x 128 x 128` NCHW model input.
- HarmonyOS ArkTS 3D mesh construction for ArkGraphics 3D.
- MindSpore Lite conversion notes for fixed-shape HarmonyOS edge models.

## Repository Layout

```text
packages/harmonyos/src/main/ets/audio_spectrum_3d/
  Constants.ets
  MelTensor.ets
  Spectrogram.ets
  SpectrumMeshBuilder.ets
  Types.ets
  index.ets
docs/
  feature-format.md
  harmonyos-integration.md
  mindspore-lite-model-hook.md
scripts/
  convert_mindspore_lite.sh
```

## HarmonyOS Quick Start

Copy the ArkTS package into your HarmonyOS module:

```text
packages/harmonyos/src/main/ets/audio_spectrum_3d
```

Then import:

```ts
import { Spectrogram, MelTensor, SpectrumMeshBuilder } from './audio_spectrum_3d';

const spec = Spectrogram.compute(pcmData, 16000);
const tensor = await MelTensor.compute(pcmData, 16000);
const mesh = SpectrumMeshBuilder.build(spec);
```

Map the mesh into ArkGraphics 3D:

```ts
const geometry = new CustomGeometry();
geometry.topology = PrimitiveTopology.TRIANGLE_LIST;
geometry.vertices = mesh.vertices;
geometry.indices = mesh.indices;
geometry.normals = mesh.normals;
geometry.colors = mesh.colors;
```

For production apps, run feature extraction on a Worker or TaskPool task. `MelTensor.compute()` cooperatively yields while processing, but background execution is still recommended for long recordings.

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

Add a batch dimension before model inference:

```text
1 x 3 x 128 x 128
```

The 3D mesh output contains:

```text
vertices: Vec3[]
normals: Vec3[]
colors: ColorRGBA[]
indices: triangle-list indices
stats: time/frequency bin counts and triangle count
```

## Model Hook

This package keeps inference optional. A HarmonyOS classifier can consume the mel tensor through `@kit.MindSporeLiteKit` after converting an ONNX model to `.ms`:

```text
input name: input
input shape: 1,3,128,128
input layout: NCHW
output shape: 1,N
```

The conversion helper is in `scripts/convert_mindspore_lite.sh`.

## Safety

This toolkit is for signal processing, visualization, prototyping, and research workflows. It is not a medical device and does not provide diagnosis.

## License

MIT
