# MindSpore Lite 模型接入

本工具包不内置模型，只提供模型可以消费的音频特征张量。

## 推荐输入格式

```text
name: input
shape: 1,3,128,128
layout: NCHW
dtype: float32
range: [0, 1]
```

`MelTensor.compute()` 返回的是 `3 x 128 x 128` 的 `Float32Array`，推理时通常按 `1 x 3 x 128 x 128` 喂给模型。

## ONNX 转 MindSpore Lite

示例命令：

```bash
converter_lite \
  --fmk=ONNX \
  --modelFile=model.onnx \
  --inputShape=input:1,3,128,128 \
  --inputDataFormat=NCHW \
  --outputFile=model
```

仓库中提供了辅助脚本：

```bash
scripts/convert_mindspore_lite.sh model.onnx build/model
```

生成结果：

```text
build/model.ms
```

## Docker 与缓存

如果通过 Docker 运行 converter，镜像和 MindSpore Lite 工具包可以缓存复用。只有在以下情况才需要重新下载：

- 主动更换 MindSpore Lite 版本。
- 删除了本地工具缓存目录。
- 删除了本地 Docker 镜像。

## HarmonyOS 端加载

将生成的 `.ms` 文件放到 HarmonyOS 模块的 rawfile 资源目录，然后通过 `@kit.MindSporeLiteKit` 加载。

推理输入使用 `AudioInput.melTensor()` 或 `MelTensor.compute()` 生成的张量数据。
