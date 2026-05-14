# MindSpore Lite Model Hook

This toolkit does not ship a model. It provides the tensor format that a model can consume.

Expected input:

```text
name: input
shape: 1,3,128,128
layout: NCHW
dtype: float32
range: [0, 1]
```

Example ONNX to MindSpore Lite conversion:

```bash
converter_lite \
  --fmk=ONNX \
  --modelFile=model.onnx \
  --inputShape=input:1,3,128,128 \
  --inputDataFormat=NCHW \
  --outputFile=model
```

If you use Docker to run the converter, cache the MindSpore Lite package and Docker image between conversions. You only need to download a new image or converter package when you intentionally change their versions or delete the cache.

For HarmonyOS, put the generated `.ms` file under your module rawfile resources and feed the tensor buffer to `@kit.MindSporeLiteKit`.
