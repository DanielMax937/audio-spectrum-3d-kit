# HarmonyOS Audio Spectrum 3D Kit

面向 HarmonyOS / ArkTS 的音频特征提取与 3D 声谱网格生成工具包。

这个仓库把 LungListener 中可复用的音频处理流程抽成独立组件：输入 PCM 音频，自动完成采样值归一化，生成归一化声谱图、`3 x 128 x 128` 三通道 log-mel 特征张量，以及可映射到 ArkGraphics 3D `CustomGeometry` 的 3D 高度图网格。

本仓库不包含患者管理、医疗业务 UI、签名文件、临床数据集，也不包含非 HarmonyOS 运行时包。

## 能力

- HarmonyOS ArkTS STFT 声谱图计算。
- 常见音频采样格式自动归一化。
- 生成兼容 `1 x 3 x 128 x 128` NCHW 模型输入的 log-mel 特征张量。
- 生成适配 ArkGraphics 3D 的 3D 声谱网格。
- 提供 MindSpore Lite 固定输入形状模型转换说明。

## 目录结构

```text
packages/harmonyos/src/main/ets/audio_spectrum_3d/
  Constants.ets
  AudioInput.ets
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

## 快速使用

把 ArkTS 包复制到你的 HarmonyOS 模块中：

```text
packages/harmonyos/src/main/ets/audio_spectrum_3d
```

例如复制到：

```text
entry/src/main/ets/audio_spectrum_3d
```

然后在业务代码中导入：

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

## 输入格式

用户只需要声明输入类型，包会自动归一化：

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

所有归一化后的采样都会被限制在 `[-1, 1]`。

如果你已经有归一化后的 `number[]`，也可以直接调用底层 API：

```ts
const spec = Spectrogram.compute(normalizedPcm, 16000);
const tensor = await MelTensor.compute(normalizedPcm, 16000);
```

## 映射到 ArkGraphics 3D

`SpectrumMeshBuilder.build()` 返回的网格可以映射到 `CustomGeometry`：

```ts
const geometry = new CustomGeometry();
geometry.topology = PrimitiveTopology.TRIANGLE_LIST;
geometry.vertices = mesh.vertices;
geometry.indices = mesh.indices;
geometry.normals = mesh.normals;
geometry.colors = mesh.colors;
```

## 特征格式

默认模型特征张量：

```text
shape: 3 x 128 x 128
layout: CHW
dtype: float32
range: [0, 1]
sample rate: 16000 Hz
duration: 前 5 秒
channels:
  0: 64-mel, hop 256
  1: 128-mel, hop 256
  2: 64-mel, hop 512
```

模型推理前通常需要补 batch 维度：

```text
1 x 3 x 128 x 128
```

3D 网格输出：

```text
vertices: Vec3[]
normals: Vec3[]
colors: ColorRGBA[]
indices: 三角形索引
stats: 时间/频率网格数量、顶点数、三角形数
```

## 模型接入

本包不内置模型。你可以将 `MelTensor` 输出作为 MindSpore Lite 模型输入。

推荐模型输入：

```text
input name: input
input shape: 1,3,128,128
input layout: NCHW
output shape: 1,N
```

ONNX 到 MindSpore Lite `.ms` 的转换辅助脚本在：

```text
scripts/convert_mindspore_lite.sh
```

## 线程建议

声谱和 Mel 特征提取属于计算密集任务。`MelTensor.compute()` 内部会分段让出执行权，但生产项目仍建议放到 Worker 或 TaskPool 中执行，避免阻塞 UI。

## 免责声明

本工具包用于音频信号处理、可视化、原型开发和研究，不是医疗器械，也不提供诊断结论。

## 许可证

MIT
