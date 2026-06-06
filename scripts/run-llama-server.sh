#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LLAMA_BIN_DIR="${ROOT_DIR}/llama.cpp/build/bin"

# The bundled llama-server binary may carry an absolute LC_RPATH from the
# machine/path where it was built. Prefer the local build directory so dyld can
# resolve @rpath/*.dylib after this repository is moved or cloned elsewhere.
export DYLD_LIBRARY_PATH="${LLAMA_BIN_DIR}${DYLD_LIBRARY_PATH:+:${DYLD_LIBRARY_PATH}}"

exec "${LLAMA_BIN_DIR}/llama-server" \
  --models-preset "${ROOT_DIR}/llama-models.ini" \
  --models-max 1 \
  --parallel 1 \
  --kv-unified \
  --host 0.0.0.0 \
  --port 12345
