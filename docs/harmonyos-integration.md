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

The HarmonyOS implementation is intentionally renderer-neutral. If you use ArkGraphics 3D, map the result into `CustomGeometry`:

```ts
const geometry = new CustomGeometry();
geometry.topology = PrimitiveTopology.TRIANGLE_LIST;
geometry.vertices = mesh.vertices;
geometry.indices = mesh.indices;
geometry.normals = mesh.normals;
geometry.colors = mesh.colors;
```

For larger files, run feature extraction on a Worker or TaskPool task. The included `MelTensor.compute()` cooperatively yields during processing, but a background thread is still recommended for production apps.
