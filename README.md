# Local llama.cpp Workspace

This repository is a local setup for building and running [`llama.cpp`](./llama.cpp) with local model files, configuration, and helper scripts.

`llama.cpp/` is an upstream dependency kept as a submodule. This README only documents the local workspace around it.

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

- building with Apple Metal support
- downloading models
- running the llama server
- managing local GGUF model files

Given the model config and script names, this workspace appears set up for local inference on Apple Silicon using Metal GPU acceleration.

## Local model configuration

The root-level [`llama-models.ini`](./llama-models.ini) defines model aliases and runtime defaults.

Global defaults:

```ini
[*]
c = 32768
n-gpu-layers = all
```

This means configured models default to:

- `c = 32768`: 32k token context size
- `n-gpu-layers = all`: offload all possible layers to GPU

Example model entry:

```ini
[qwen3.6-27b-q5]
model = ./models/Qwen3.6-27B-Q5_K_M.gguf
load-on-startup = false
```

Each section gives a model a short alias and points to a GGUF file under `models/`.

## Architecture

This repository is a thin local orchestration layer around the upstream `llama.cpp` submodule.

```text
scripts/ + llama-models.ini
        ↓
local models in models/
        ↓
llama.cpp tools/server/runtime
```

The project-specific pieces are the configuration file, local model storage, and helper scripts. Inference, model loading, server behavior, and backend execution are provided by the `llama.cpp` dependency.

All workspace paths should be repository-relative so the setup remains portable across machines.
