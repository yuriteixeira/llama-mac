#!/usr/bin/env bash
set -euo pipefail

# List currently available MLX model tags on this machine,
# along with size and modification info — mirrors `ollama list` output.

echo "=== Ollama Models (MLX-capable tags) ==="
echo ""
ollama list 2>/dev/null || echo "No models installed. Run ./scripts/download-models-ollama.sh to pull models."
echo ""
echo "See models-ollama.txt for the curated list of recommended tags."
echo "Available tags: https://ollama.com/search"
