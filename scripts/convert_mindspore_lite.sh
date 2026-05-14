#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <input.onnx> <output-prefix>" >&2
  echo "Example: $0 model.onnx build/model" >&2
  exit 2
fi

INPUT_ONNX="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
OUTPUT_PREFIX="$2"
TOOLS_DIR="${TOOLS_DIR:-$HOME/.cache/audio-spectrum-3d-kit/tools}"
MSLITE_VERSION="${MSLITE_VERSION:-2.4.1}"
MSLITE_ARCHIVE="mindspore-lite-${MSLITE_VERSION}-linux-x64.tar.gz"
MSLITE_DIR="$TOOLS_DIR/mindspore-lite-${MSLITE_VERSION}-linux-x64"
MSLITE_URL="https://ms-release.obs.cn-north-4.myhuaweicloud.com/${MSLITE_VERSION}/MindSpore/lite/release/linux/x86_64/${MSLITE_ARCHIVE}"
MSLITE_SHA256="${MSLITE_SHA256:-af999cc35ba63ac37146d5926ecdc726b44bc9f6043088b3fc6671f33f896b08}"

mkdir -p "$TOOLS_DIR" "$(dirname "$OUTPUT_PREFIX")"

if [[ ! -f "$TOOLS_DIR/$MSLITE_ARCHIVE" ]]; then
  curl -L -o "$TOOLS_DIR/$MSLITE_ARCHIVE" "$MSLITE_URL"
fi

actual_sha="$(shasum -a 256 "$TOOLS_DIR/$MSLITE_ARCHIVE" | awk '{print $1}')"
if [[ "$actual_sha" != "$MSLITE_SHA256" ]]; then
  echo "MindSpore Lite archive checksum mismatch: $actual_sha" >&2
  exit 1
fi

if [[ ! -d "$MSLITE_DIR" ]]; then
  tar -xzf "$TOOLS_DIR/$MSLITE_ARCHIVE" -C "$TOOLS_DIR"
fi

docker run --rm --platform linux/amd64 \
  -v "$TOOLS_DIR:/tools" \
  -v "$(dirname "$INPUT_ONNX"):/model-in:ro" \
  -v "$(cd "$(dirname "$OUTPUT_PREFIX")" && pwd):/model-out" \
  python:3.10-slim sh -lc "
    set -eu
    base=/tools/mindspore-lite-${MSLITE_VERSION}-linux-x64
    export LD_LIBRARY_PATH=\"\$base/tools/converter/lib:\$base/runtime/lib:\${LD_LIBRARY_PATH:-}\"
    \"\$base/tools/converter/converter/converter_lite\" \
      --fmk=ONNX \
      --modelFile=/model-in/$(basename "$INPUT_ONNX") \
      --inputShape=input:1,3,128,128 \
      --inputDataFormat=NCHW \
      --outputFile=/model-out/$(basename "$OUTPUT_PREFIX")
  "

echo "Wrote ${OUTPUT_PREFIX}.ms"
