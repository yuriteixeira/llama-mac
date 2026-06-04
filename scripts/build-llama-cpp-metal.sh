#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LLAMA_DIR="${ROOT_DIR}/llama.cpp"
BUILD_DIR="${LLAMA_DIR}/build"
JOBS="${JOBS:-14}"

if [[ ! -d "${LLAMA_DIR}" ]]; then
  echo "error: llama.cpp submodule directory not found: ${LLAMA_DIR}" >&2
  echo "run: git submodule update --init --recursive llama.cpp" >&2
  exit 1
fi

if [[ ! -f "${LLAMA_DIR}/CMakeLists.txt" ]]; then
  echo "initialising llama.cpp submodule..."
  git -C "${ROOT_DIR}" submodule update --init --recursive llama.cpp
fi

cmake -S "${LLAMA_DIR}" -B "${BUILD_DIR}" \
  -DGGML_METAL=ON \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_OSX_ARCHITECTURES=arm64

cmake --build "${BUILD_DIR}" --config Release -j"${JOBS}"

"${BUILD_DIR}/bin/llama-cli" --version
"${BUILD_DIR}/bin/llama-server" --list-devices
