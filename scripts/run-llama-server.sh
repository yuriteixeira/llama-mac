#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

exec "${ROOT_DIR}/llama.cpp/build/bin/llama-server" \
  --models-preset "${ROOT_DIR}/llama-models.ini" \
  --models-max 1 \
  --parallel 1 \
  --host 0.0.0.0
