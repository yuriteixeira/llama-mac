# Local LLM Inference Workspace

## Overview

This repository is a local workspace for running [`llama.cpp`](https://github.com/ggml-org/llama.cpp) via **Homebrew**, with local model files, configuration, and helper scripts.


## Assumptions & Requirements

- **macOS on Apple Silicon** (M1/M2/M3/M4) — Metal GPU acceleration requires it
- **Homebrew**: [`brew.sh`](https://brew.sh)
- **Xcode Command Line Tools**:
  ```bash
  xcode-select --install
  ```
- **Disk space**: 30–50 GB for models (each GGUF file is often 10–20 GB)
- **RAM**: 32 GB minimum; 64 GB recommended

Tuned for:
- **Local workstation**: models are loaded as needed, typically one at a time
- **GPU**: Apple Silicon Metal acceleration
- **Workspace paths**: repository-relative paths for portability across machines

## Building & Using

Since this project is Homebrew-based, setup is mostly install scripts + model downloads.

**Cloning:**

```bash
git clone git@github.com:yuriteixeira/llama-mac.git
cd llama-mac
```

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

**Using the models:**

My recommendation is https://pi.dev + its [pi-llama-cpp](https://pi.dev/packages/pi-llama-cpp) extension, which will allow to load any models configured in `./model-presets.ini`


## Managing Models & Presets

- Models are downloaded using `./scripts/download-models.sh` based on the curated list in `./models.txt`
- Model presets for `llama-server` are defined in `./model-presets.ini`
- They can be updated based on the models downloaded if you run `./scripts/update-presets.sh`
- Before updating `./models.txt` with a new model, make sure they are not deny-listed in `./DO-NOT-DOWNLOAD-THESE-MODELS.md`
- Make sure this machine's RAM can fit all the necessary data to run the model correctly (the model itself, context, engine, etc)

## Pro-tips

- Use `./scripts/audit-models.sh` to keep the local model inventory tidy
- If performance is poor, first check model size, RAM pressure, and whether Metal acceleration is actually being used
- Keep model paths and preset entries repository-relative so the setup stays portable
