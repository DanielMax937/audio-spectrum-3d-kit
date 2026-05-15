# HarmonyOS Integration

Copy this directory into your app module:

```text
packages/harmonyos/src/main/ets/audio_spectrum_3d
```

Then import:

```ts
import { AudioInput, SpectrumMeshBuilder } from './audio_spectrum_3d';
```

Example:

```ts
const spec = AudioInput.spectrogram(int16Pcm, {
  format: 'pcm16',
  sampleRate: 16000
});
const tensor = await AudioInput.melTensor(int16Pcm, {
  format: 'pcm16',
  sampleRate: 16000
});
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

## Audio Input

Use `AudioInput` when your audio is not normalized yet:

```ts
const normalized = AudioInput.normalize(int16Pcm, 'pcm16');
```

Supported formats:

```text
pcm16   Int16Array or number[] with signed 16-bit PCM values
uint8   Uint8Array or number[] with unsigned 8-bit PCM values
float32 Float32Array or number[] already near [-1, 1]
```

Normalization rules:

```text
pcm16:   sample / 32768.0
uint8:   (sample - 128.0) / 128.0
float32: clamp(sample, -1, 1)
```

If your app already stores mono PCM samples normalized to `[-1, 1]`, you can call `Spectrogram.compute()` and `MelTensor.compute()` directly.
