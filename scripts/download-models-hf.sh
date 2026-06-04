#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODELS_DIR="${ROOT_DIR}/models"

mkdir -p "${MODELS_DIR}"

# ★ Top pick: Qwen3.6-27B Q5_K_M
hf download \
  unsloth/Qwen3.6-27B-GGUF \
  Qwen3.6-27B-Q5_K_M.gguf \
  --local-dir "${MODELS_DIR}"

# Fallback / faster: Qwen3.6-27B Q4_K_M
hf download \
  unsloth/Qwen3.6-27B-GGUF \
  Qwen3.6-27B-Q4_K_M.gguf \
  --local-dir "${MODELS_DIR}"

# Qwen3.6-35B-A3B (MoE)
hf download \
  unsloth/Qwen3.6-35B-A3B-GGUF \
  Qwen3.6-35B-A3B-UD-Q4_K_M.gguf \
  --local-dir "${MODELS_DIR}"

# Gemma 4 26B-A4B it
hf download \
  ggml-org/gemma-4-26B-A4B-it-GGUF \
  gemma-4-26B-A4B-it-Q4_K_M.gguf \
  --local-dir "${MODELS_DIR}"
