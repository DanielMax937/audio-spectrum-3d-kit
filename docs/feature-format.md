# HarmonyOS 特征格式

本文说明本包的输入归一化、声谱图、Mel 特征张量和 3D 网格格式。

## 音频输入归一化

推荐使用 `AudioInput` 入口，它会根据声明的格式自动归一化：

```ts
const pcm = AudioInput.normalize(rawSamples, 'pcm16');
const spec = AudioInput.spectrogram(rawSamples, { format: 'pcm16', sampleRate: 16000 });
const tensor = await AudioInput.melTensor(rawSamples, { format: 'pcm16', sampleRate: 16000 });
```

支持格式：

```text
pcm16   Int16Array 或 number[]，有符号 16-bit PCM
uint8   Uint8Array 或 number[]，无符号 8-bit PCM
float32 Float32Array 或 number[]，数值已接近 [-1, 1]
```

归一化规则：

```text
pcm16:   sample / 32768.0
uint8:   (sample - 128.0) / 128.0
float32: clamp(sample, -1, 1)
```

归一化后的信号始终会被限制在 `[-1, 1]`。

## 声谱图

`Spectrogram.compute()` 返回归一化后的 STFT 声谱图。

默认参数：

```text
sample_rate = 16000
fft_size = 1024
hop_size = 512
min_freq = 80 Hz
max_freq = 2000 Hz
db range = [-80, 0]
```

返回结构：

```ts
interface SpectrogramData {
  timeBins: number;
  freqBins: number;
  matrix: number[][];
  maxFreq: number;
  maxTime: number;
}
```

其中 `matrix` 已归一化到 `[0, 1]`。

## Mel 特征张量

`MelTensor.compute()` 返回三个 log-mel 视角：

| 通道 | Mel 数量 | Hop |
|---|---:|---:|
| 0 | 64 | 256 |
| 1 | 128 | 256 |
| 2 | 64 | 512 |

每个通道会 resize 到 `128 x 128`，并按通道单独做 min-max 归一化。

返回形状：

```text
3 x 128 x 128
```

底层是 `Float32Array`，布局是 channel-first，也就是 `CHW`。用于 MindSpore Lite 推理时，通常按以下形状喂入：

```text
1 x 3 x 128 x 128
```

## 3D 网格

`SpectrumMeshBuilder.build()` 会从声谱图采样并生成规则高度图网格。

默认网格：

```text
time bins: 72
freq bins: 44
plot width: 7.6
plot depth: 5.0
height scale: 2.0
topology: triangle list
```

返回结构：

```ts
interface SpectrumMesh {
  vertices: Vec3[];
  normals: Vec3[];
  colors: ColorRGBA[];
  indices: number[];
  stats: MeshStats;
}
```
