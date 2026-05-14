# Feature Format

## Spectrogram

The STFT spectrogram is normalized to `[0, 1]`.

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

```json
{
  "timeBins": 154,
  "freqBins": 123,
  "matrix": [[0.0, 0.1]],
  "maxFreq": 2000,
  "maxTime": 5.0
}
```

## Mel Tensor

The model-ready tensor uses three log-mel views:

| Channel | Mels | Hop |
|---|---:|---:|
| 0 | 64 | 256 |
| 1 | 128 | 256 |
| 2 | 64 | 512 |

Each channel is resized to `128 x 128` and min-max normalized independently.

Python shape is `3 x 128 x 128` (`CHW`). For most edge runtimes, add a batch dimension to get `1 x 3 x 128 x 128`.

## 3D Mesh

The mesh is a regular height map sampled from the spectrogram:

```text
default grid: 72 x 44
plot width: 7.6
plot depth: 5.0
height scale: 2.0
topology: triangle list
```

`indices` are emitted as a flat triangle-list index array.
