# HarmonyOS Feature Format

## Spectrogram

`Spectrogram.compute()` returns a normalized STFT spectrogram.

Defaults:

```text
sample_rate = 16000
fft_size = 1024
hop_size = 512
min_freq = 80 Hz
max_freq = 2000 Hz
db range = [-80, 0]
```

Returned fields:

```ts
interface SpectrogramData {
  timeBins: number;
  freqBins: number;
  matrix: number[][];
  maxFreq: number;
  maxTime: number;
}
```

## Mel Tensor

`MelTensor.compute()` returns three log-mel views:

| Channel | Mels | Hop |
|---|---:|---:|
| 0 | 64 | 256 |
| 1 | 128 | 256 |
| 2 | 64 | 512 |

Each channel is resized to `128 x 128` and min-max normalized independently.

Returned shape:

```text
3 x 128 x 128
```

The `Float32Array` is channel-first (`CHW`). For MindSpore Lite inference, add a batch dimension conceptually and feed the buffer as:

```text
1 x 3 x 128 x 128
```

## 3D Mesh

`SpectrumMeshBuilder.build()` emits a regular height map sampled from the spectrogram:

```text
default grid: 72 x 44
plot width: 7.6
plot depth: 5.0
height scale: 2.0
topology: triangle list
```

Returned fields:

```ts
interface SpectrumMesh {
  vertices: Vec3[];
  normals: Vec3[];
  colors: ColorRGBA[];
  indices: number[];
  stats: MeshStats;
}
```
