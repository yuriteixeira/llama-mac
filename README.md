# Local llama.cpp Workspace

This repository is a local setup for running [`llama.cpp`](https://github.com/ggml-org/llama.cpp) with local model files, configuration, and helper scripts.

llama.cpp is installed via **Homebrew** — no submodule, no build from source. This README documents only the local workspace around it.

## Prerequisites

- **macOS on Apple Silicon** (M1/M2/M3/M4) — Metal GPU acceleration requires it
- **Homebrew**: [`brew.sh`](https://brew.sh)
- **Xcode Command Line Tools**:
  ```bash
  xcode-select --install
  ```
- **Disk space**: 30–50 GB for models (each GGUF file is 10–20 GB)
- **RAM**: 32 GB minimum; 64 GB recommended (the config defaults use `q8_0` cache quality for near-F16 KV performance)

## Quick Start

Run these steps in order:

```bash
# 1. Clone the repository
git clone git@github.com:yuriteixeira/llama-mac.git
cd llama-mac

# 2. Install llama.cpp via Homebrew (Metal enabled by default)
./scripts/build-llama-cpp-metal.sh

# 3. Download models (uses wget by default)
./scripts/download-models.sh
# Alternative: ./scripts/download-models-hf.sh (requires `hf` CLI + Hugging Face token)

# 4. Start the server
./scripts/run-llama-server.sh
```

The server exposes an **OpenAI-compatible API** at `http://localhost:12345`.

> **Tip**: If you want the bleeding-edge HEAD version of llama.cpp instead of the
> latest Homebrew stable tag, install it first:
> ```bash
> brew uninstall llama.cpp
> brew install llama.cpp --HEAD
> ```

### Downloaded models

The `download-models.sh` script fetches the following GGUF files into `models/`:

| Model | File | Approx. Size |
|---|---|---|
| Qwen3.6-27B Q5_K_M ★ | `Qwen3.6-27B-Q5_K_M.gguf` | ~18 GB |
| Qwen3.6-27B Q4_K_M | `Qwen3.6-27B-Q4_K_M.gguf` | ~15 GB |
| Qwen3.6-35B-A3B MoE | `Qwen3.6-35B-A3B-UD-Q4_K_M.gguf` | ~22 GB |
| Gemma 4 26B-A4B | `gemma-4-26B-A4B-it-Q4_K_M.gguf` | ~16 GB |

The Qwen3.6-27B Q5_K_M is the **recommended starting point**. It loads faster and leaves room for context window. See [`llama-models.ini`](./llama-models.ini) for all available presets.

## Local helper scripts

At the repository root:

```text
scripts/
├── build-llama-cpp-metal.sh
├── download-models-hf.sh
├── download-models.sh
└── run-llama-server.sh
```

These scripts are local conveniences for:

- installing llama.cpp via Homebrew (Metal enabled by default on Apple Silicon)
- downloading models
- running the llama server
- managing local GGUF model files

## Local model configuration

The root-level [`llama-models.ini`](./llama-models.ini) defines model aliases and runtime defaults.

Global defaults:

```ini
[*]
c = 65536
n-gpu-layers = all
```

This means configured models default to:

- `c = 65536`: 64k token context size
- `n-gpu-layers = all`: offload all possible layers to GPU

Example model entry:

```ini
[fast-detailed-qwen3.6-35b-a3b-q4]
model = ./models/Qwen3.6-35B-A3B-UD-Q4_K_M.gguf
```

Each section gives a model a short alias and points to a GGUF file under `models/`.

## Architecture

This repository is a thin local orchestration layer around llama.cpp (installed via Homebrew).

```text
scripts/ + llama-models.ini
        ↓
local models in models/
        ↓
Homebrew llama.cpp server runtime
```

The project-specific pieces are the configuration file, local model storage, and helper scripts. Inference, model loading, server behavior, and backend execution are provided by the Homebrew `llama.cpp` package.

All workspace paths should be repository-relative so the setup remains portable across machines.
