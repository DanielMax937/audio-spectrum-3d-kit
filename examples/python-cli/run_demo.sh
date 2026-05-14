#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."
python3 examples/python-cli/generate_demo_wav.py
PYTHONPATH=packages/python python3 -m audio_spectrum_3d.cli examples/python-cli/demo.wav \
  --out examples/python-cli/demo-spectrum3d.json \
  --tensor-out examples/python-cli/demo-mel.npy
