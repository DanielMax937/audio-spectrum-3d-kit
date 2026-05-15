# HarmonyOS 集成指南

## 安装方式

把这个目录复制到你的 HarmonyOS 应用模块：

```text
packages/harmonyos/src/main/ets/audio_spectrum_3d
```

例如：

```text
entry/src/main/ets/audio_spectrum_3d
```

## 基本使用

```ts
import { AudioInput, SpectrumMeshBuilder } from './audio_spectrum_3d';

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

## 音频输入

如果你的音频还没有归一化，使用 `AudioInput`：

```ts
const normalized = AudioInput.normalize(int16Pcm, 'pcm16');
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

如果应用中已经保存的是 `[-1, 1]` 范围的 mono PCM `number[]`，可以直接调用底层 API：

```ts
const spec = Spectrogram.compute(normalizedPcm, 16000);
const tensor = await MelTensor.compute(normalizedPcm, 16000);
```

## ArkGraphics 3D

将 `SpectrumMesh` 映射到 `CustomGeometry`：

```ts
const geometry = new CustomGeometry();
geometry.topology = PrimitiveTopology.TRIANGLE_LIST;
geometry.vertices = mesh.vertices;
geometry.indices = mesh.indices;
geometry.normals = mesh.normals;
geometry.colors = mesh.colors;
```

如果需要线框、选区、高亮区域，可以基于同一份 `mesh.vertices` 和 `mesh.indices` 再构造额外几何体。

## 线程建议

声谱和 Mel 特征提取计算量较大。建议在生产项目中放到 Worker 或 TaskPool 执行，避免阻塞 UI。

`MelTensor.compute()` 内部每隔一段帧会让出执行权，但这只是降低阻塞风险，不等价于完整后台线程。
