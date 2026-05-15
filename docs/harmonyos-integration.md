# HarmonyOS Integration

Copy this directory into your app module:

```text
packages/harmonyos/src/main/ets/audio_spectrum_3d
```

Then import:

```ts
import { Spectrogram, MelTensor, SpectrumMeshBuilder } from './audio_spectrum_3d';
```

Example:

```ts
const spec = Spectrogram.compute(pcmData, 16000);
const tensor = await MelTensor.compute(pcmData, 16000);
const mesh = SpectrumMeshBuilder.build(spec);
```

## ArkGraphics 3D

Map `SpectrumMesh` into `CustomGeometry`:

```ts
const geometry = new CustomGeometry();
geometry.topology = PrimitiveTopology.TRIANGLE_LIST;
geometry.vertices = mesh.vertices;
geometry.indices = mesh.indices;
geometry.normals = mesh.normals;
geometry.colors = mesh.colors;
```

## Threading

For larger files, run feature extraction on a Worker or TaskPool task. The included `MelTensor.compute()` cooperatively yields during processing, but background execution is still recommended for production apps.

## PCM Input

The package expects mono PCM samples normalized to `[-1, 1]`:

```ts
const pcmData: number[] = [-0.12, 0.03, 0.18];
```

If your app records 16-bit PCM, convert each sample with:

```ts
const normalized = int16Sample / 32768.0;
```
