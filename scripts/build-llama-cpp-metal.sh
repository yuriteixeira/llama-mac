#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LLAMA_DIR="${ROOT_DIR}/llama.cpp"
BUILD_DIR="${LLAMA_DIR}/build"
JOBS="${JOBS:-14}"

export PATH="${HOME}/.local/bin:${PATH}"

install_brew_package() {
  local command_name="$1"
  local package_name="$2"

  if command -v "${command_name}" >/dev/null 2>&1; then
    return
  fi

  if ! command -v brew >/dev/null 2>&1; then
    echo "error: Homebrew is required to install ${package_name}" >&2
    exit 1
  fi

  brew install "${package_name}"
}

install_hf_cli() {
  if command -v hf >/dev/null 2>&1; then
    return
  fi

  install_brew_package pipx pipx
  pipx install huggingface-hub || pipx upgrade huggingface-hub
  export PATH="${HOME}/.local/bin:${PATH}"

  if ! command -v hf >/dev/null 2>&1; then
    echo "error: hf CLI was installed but is not on PATH" >&2
    echo "try: pipx ensurepath" >&2
    exit 1
  fi
}

if ! xcode-select -p >/dev/null 2>&1; then
  echo "Xcode Command Line Tools are required. Starting installer..." >&2
  xcode-select --install
  echo "Re-run this script after installation completes." >&2
  exit 1
fi

install_brew_package git git
install_brew_package cmake cmake
install_brew_package wget wget
install_brew_package node node
install_hf_cli

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
