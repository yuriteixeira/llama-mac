# Ollama MLX Backend Integration Plan

## Overview

Ollama version 0.19+ introduced an optional **MLX backend** specifically for Apple Silicon Macs. This backend delivers **2–3× faster inference** compared to the traditional llama.cpp Metal backend by eliminating unnecessary CPU↔GPU memory copies through MLX's unified memory design.

| Metric | llama.cpp (Metal) | Ollama + MLX | Speedup |
|--------|-------------------|--------------|---------|
| Prefill (time to first token) | baseline | ~1.6× faster | ~60% better |
| Decode (tokens/sec) | baseline | ~2× faster | ~100% better |
| GPU utilization | 40–60% | 85–95% | — |

## Supported Architectures (as of mid-2026)

Ollama's MLX backend supports these model families natively:

- **Qwen 3 / 3.5 / 3.6** (incl. MoE variants like 35B-A3B)
- **Gemma 3 / 4**
- **Llama** series
- **Mistral** series
- **Phi** series
- **GLM-4 MoE**

Models are automatically pulled with MLX-optimized weights when the backend is enabled.

## Requirements

| Requirement | Minimum | Recommended |
|-------------|---------|-------------|
| Ollama version | 0.19+ | Latest |
| Apple Silicon | M1 / M2 / M3 / M4 / M5 | M4 / M5 (better NAX support) |
| Unified Memory | 32 GB | 64 GB+ |
| macOS | 15.4+ | Latest stable |

> **Note**: Base MacBooks with 16 GB can technically run small models, but 32 GB is the practical floor for anything useful. Vision models and multi-GPU setups remain unsupported.

## Goals

1. Add Ollama as an **alternative inference backend** alongside the existing llama.cpp setup
2. Provide scripts to install, configure, and run Ollama with MLX enabled
3. Document model selection and management under Ollama
4. Keep both backends in the repo so users can choose based on their needs

## Implementation Plan

### Step 1 — Shell Scripts

| Script | Purpose |
|--------|---------|
| `scripts/install-ollama.sh` | Install ollama via Homebrew, verify MLX support |
| `scripts/download-models-ollama.sh` | Pull and manage MLX model tags via `ollama` CLI |
| `scripts/run-ollama-server.sh` | Start `ollama serve` with `OLLAMA_MLX=1` |
| `scripts/ollama-list-models.sh` | Show available MLX-compatible models and their tags |

### Step 2 — Model Inventory Files

| File | Purpose |
|------|---------|
| `models-ollama.txt` | List of ollama model tags to pull (one per line) |
| `models-ollama-extras.txt` | Optional/alternative model tags |

### Step 3 — Update Existing Assets

| File | Changes |
|------|---------|
| `README.md` | Add Ollama/MLX as an alternative setup path; document both backends |
| `model-presets.ini` | No changes — this is llama.cpp only |
| `DO-NOT-DOWNLOAD-THESE-MODELS.md` | Add any ollama-specific denial entries |

### Step 4 — Integration Points

- Ollama also exposes an **OpenAI-compatible API** on `localhost:11434`
- Users can choose which backend to use per-session
- Both backends can coexist; they listen on different ports
- The Python `pi-llama-cpp` extension could be extended to also support ollama's API

## Models Installed Locally

The following models are currently pulled and available on this machine:

| Model | Size | Quantization | Capabilities | RAM Required |
|-------|------|--------------|--------------|--------------|
| `qwen3.6:27b-coding-mxfp8` | ~31 GB | MXFP8 | Vision, Thinking, Tools | ~33 GB+ |
| `gemma4:31b-mxfp8` | ~32 GB | MXFP8 | Tools, Thinking | ~34 GB+ |
| `qwen3.6:35b-a3b-coding-mxfp8` | ~38 GB | MXFP8 | Vision, Thinking, Tools | ~40 GB+ |

> All three models use **MXFP8** quantization (rather than GGUF), which preserves higher accuracy at the same bit-width and aligns with cloud-inference standards.

## Implementation Status

All steps are **complete**:

- ✅ `scripts/install-ollama.sh` — Homebrew install + MLX guidance
- ✅ `scripts/download-models-ollama.sh` — Pulls from `models-ollama.txt`
- ✅ `scripts/run-ollama-server.sh` — Starts `ollama serve` with `OLLAMA_MLX=1`
- ✅ `scripts/ollama-list-models.sh` — Lists installed models via API
- ✅ `models-ollama.txt` — Curated tag list
- ✅ `README.md` — Both backends documented side-by-side

## Risks & Caveats

- MLX backend is still **experimental** — may have rough edges
- Vision models are now supported via MLX (previously unsupported)
- No multi-GPU / Mac Studio Ultra dual-die support
- Larger models may push memory with less headroom than llama.cpp
- Ollama updates may occasionally break MLX compatibility (preview stage)
- MXFP8 models require ~32 GB minimum RAM just for the model weights alone, plus context / KV cache overhead
