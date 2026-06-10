#!/usr/bin/env bash
set -euo pipefail

# Install ollama via Homebrew and verify MLX support on Apple Silicon.
#
# After installation, to enable MLX:
#   export OLLAMA_MLX=1
#   ollama serve

if ! command -v brew >/dev/null 2>&1; then
  echo "error: Homebrew is required. Install from https://brew.sh" >&2
  exit 1
fi

if ! xcode-select -p >/dev/null 2>&1; then
  echo "Xcode Command Line Tools are required. Starting installer..." >&2
  xcode-select --install
  echo "Re-run this script after installation completes." >&2
  exit 1
fi

echo "Installing ollama via Homebrew..."
brew install ollama

# Check version
OLLAMA_VERSION=$(ollama --version 2>/dev/null || ollama version 2>/dev/null || echo "unknown")
echo "Ollama version: $OLLAMA_VERSION"

if command -v ollama >/dev/null 2>&1; then
  echo ""
  echo "✅ ollama installed successfully!"
  echo ""
  echo "To enable the MLX backend on Apple Silicon, run:"
  echo ""
  echo "  export OLLAMA_MLX=1"
  echo "  ollama serve"
  echo ""
  echo "Then pull models as usual:"
  echo ""
  echo "  ollama pull qwen3.5:35b-a3b"
  echo ""
  echo "The server exposes an OpenAI-compatible API at http://localhost:11434"
else
  echo "error: ollama command not found after install" >&2
  exit 1
fi
