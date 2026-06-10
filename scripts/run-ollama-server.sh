#!/usr/bin/env bash
set -euo pipefail

# Start ollama serve with MLX backend enabled on Apple Silicon.
# The script sets OLLAMA_MLX=1 internally — just run it directly.
# The server exposes an OpenAI-compatible API at http://localhost:11434

echo "Starting Ollama with MLX backend on Apple Silicon..."
exec bash -c 'export OLLAMA_MLX=1 && exec ollama serve'
