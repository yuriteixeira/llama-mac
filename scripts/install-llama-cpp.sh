#!/usr/bin/env bash
set -euo pipefail

# Install llama.cpp via Homebrew — Metal is enabled by default on Apple Silicon.
# No submodule, no cmake, no build from source. Just: brew install llama.cpp

if ! xcode-select -p >/dev/null 2>&1; then
  echo "Xcode Command Line Tools are required. Starting installer..." >&2
  xcode-select --install
  echo "Re-run this script after installation completes." >&2
  exit 1
fi

if ! command -v brew >/dev/null 2>&1; then
  echo "error: Homebrew is required. Install from https://brew.sh" >&2
  exit 1
fi

echo "Installing llama.cpp via Homebrew (Metal enabled by default on Apple Silicon)..."
brew install llama.cpp

llama-cli --version
llama-server --list-devices
