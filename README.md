# Local LLM Inference Workspace

## Overview

This repository is a local workspace for running large language models on **Apple Silicon Macs** using two inference backends:

| Backend | Framework | Best for |
|---------|-----------|----------|
| **llama.cpp** (default) | Metal GPU via `llama.cpp` | GGUF models, broad architecture support |
| **Ollama + MLX** (preview) | Apple's MLX | **2–3× faster** inference on Apple Silicon |

Both backends expose an **OpenAI-compatible API** and can coexist on the same machine.

## Assumptions & Requirements

- **macOS on Apple Silicon** (M1/M2/M3/M4/M5)
- **Homebrew**: [`brew.sh`](https://brew.sh)
- **Xcode Command Line Tools**:
   ```bash
  xcode-select --install
   ```
- **Disk space**: 10–20 GB per model (GGUF files) or Ollama's own model cache
- **RAM**: 32 GB minimum; 64 GB recommended
- **macOS 15.4+** (required for MLX backend stability)

Tuned for:
- **Local workstation**: models are loaded as needed, typically one at a time
- **GPU**: Apple Silicon Metal / MLX acceleration
- **Workspace paths**: repository-relative paths for portability across machines

## Building & Using

Since this project is Homebrew-based, setup is mostly install scripts + model downloads.

**Cloning:**

```bash
git clone git@github.com:yuriteixeira/llama-mac.git
cd llama-mac
```

### Option 1: llama.cpp (GGUF models)

**Installing llama.cpp:**

```bash
./scripts/install-llama-cpp.sh
```

If you want the bleeding-edge HEAD version of llama.cpp instead of the latest Homebrew stable tag:

```bash
brew uninstall llama.cpp
brew install llama.cpp --HEAD
```

**Downloading models:**

```bash
./scripts/download-models.sh
```

Alternative Hugging Face-based download:

```bash
./scripts/download-models-hf.sh
```

**Starting the service:**

```bash
./scripts/run-llama-server.sh
```

The server exposes an **OpenAI-compatible API** at `http://localhost:12345`.

---

### Option 2: Ollama + MLX (Apple Silicon optimized)

Ollama 0.19+ includes an optional MLX backend that runs inference **2–3× faster** than llama.cpp on Apple Silicon by eliminating CPU↔GPU memory copies. This is an experimental feature that requires 32 GB+ of unified memory.

**Installing Ollama:**

```bash
./scripts/install-ollama.sh
```

**Pulling MLX-optimized models:**

```bash
./scripts/download-models-ollama.sh
```

Additional model tags available at https://ollama.com/search.

**Starting the service:**

```bash
./scripts/run-ollama-server.sh
```
The script sets `OLLAMA_MLX=1` internally, so no extra env var is needed.

The server exposes an **OpenAI-compatible API** at `http://localhost:11434`.

**Listing installed models:**

```bash
./scripts/ollama-list-models.sh
```

> **Note**: MLX is Apple Silicon only, is still in preview, and doesn't yet support vision models or multi-GPU setups.

---

## Quick-Reference: All Scripts

Use the table below to find the right script for your task:

### Install

| Script | Purpose |
|--------|---------|
| `./scripts/install-llama-cpp.sh` | Install `llama.cpp` via Homebrew (Metal GPU) |
| `./scripts/install-ollama.sh` | Install `ollama` via Homebrew + verify MLX support |

### Download / Pull Models

| Script | Purpose |
|--------|---------|
| `./scripts/download-models.sh` | Download GGUF models from `models.txt` URLs (wget) |
| `./scripts/download-models-hf.sh` | Alternative Hugging Face `hf download` CLI based pull |
| `./scripts/download-models-ollama.sh` | Pull MLX-optimized model tags from `models-ollama.txt` |

### Run Servers

| Script | Purpose |
|--------|---------|
| `./scripts/run-llama-server.sh` | Start `llama-server` (API at `localhost:12345`, no env vars) |
| `./scripts/run-ollama-server.sh` | Start `ollama serve` with MLX enabled (API at `localhost:11434`) |

### List / Audit

| Script | Purpose |
|--------|---------|
| `./scripts/ollama-list-models.sh` | List installed Ollama models via local API |
| `./scripts/audit-models.sh` | Scan `models/` directory for missing/duplicate GGUF files |

### Manage Presets

| Script | Purpose |
|--------|---------|
| `./scripts/update-presets.sh` | Rebuild `model-presets.ini` to match downloaded GGUF files |

## Model Inventory

Two model lists are maintained:

| File | Backend | Description |
|------|---------|-------------|
| `models.txt` | llama.cpp | GGUF model download URLs |
| `models-ollama.txt` | Ollama | MLX-compatible model tags |

## Managing Models & Presets (llama.cpp)

- Models are downloaded using `./scripts/download-models.sh` based on the curated list in `./models.txt`
- Model presets for `llama-server` are defined in `./model-presets.ini`
- They can be updated based on the models downloaded if you run `./scripts/update-presets.sh`
- Before updating `./models.txt` with a new model, make sure they are not deny-listed in `./DO-NOT-DOWNLOAD-THESES-MODELS.md`
- Make sure this machine's RAM can fit all the necessary data to run the model correctly (the model itself, context, engine, etc)

## Pro-tips

- Use `./scripts/audit-models.sh` to keep the local model inventory tidy
- If performance is poor, first check model size, RAM pressure, and whether Metal acceleration is actually being used
- Keep model paths and preset entries repository-relative so the setup stays portable
- **For Apple Silicon**: try MLX via Ollama — it delivers 2–3× faster inference than the Metal backend
