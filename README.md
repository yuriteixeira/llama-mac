# Local llama.cpp Workspace

This repository is a local setup around [`llama.cpp`](./llama.cpp), with the main upstream code in `llama.cpp/` and local model/configuration helpers at the repository root.

## Big picture

`llama.cpp` is a C/C++ LLM inference engine. Its purpose is to run GGUF-format language models locally with good performance on CPU, Apple Metal, CUDA, Vulkan, SYCL, HIP, and other supported backends.

This workspace is organized as:

```text
.
├── llama.cpp/          # main llama.cpp source tree
├── models/             # local GGUF model files
├── scripts/            # local helper scripts
├── plans/              # setup notes/plans
└── llama-models.ini    # model config for server/runtime
```

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

## Main llama.cpp architecture

Inside `llama.cpp/`, the core layout is:

```text
llama.cpp/
├── include/            # public C/C++ API
├── src/                # libllama implementation
├── ggml/               # tensor/math/backend engine
├── common/             # shared CLI/server utilities
├── tools/              # production tools: cli, server, quantize, bench, etc.
├── examples/           # example programs
├── tests/              # test suite
├── docs/               # documentation
├── conversion/         # model conversion helpers
└── gguf-py/            # Python GGUF tooling
```

## Core layers

### 1. `ggml/` - tensor engine

`ggml` is the low-level compute layer.

```text
llama.cpp/ggml/src/
├── ggml.c / ggml.cpp          # tensor graph core
├── ggml-quants.c              # quantized tensor formats
├── gguf.cpp                   # GGUF file format
├── ggml-cpu/                  # CPU backend
├── ggml-cuda/                 # NVIDIA CUDA backend
├── ggml-metal/                # Apple Metal backend
├── ggml-vulkan/               # Vulkan backend
├── ggml-hip/                  # AMD HIP backend
└── ...
```

`ggml` handles:

- tensors
- computation graphs
- quantized matrix multiplication
- backend/device abstraction
- CPU/GPU execution
- GGUF file reading/writing

Think of this as the minimal C/C++ tensor runtime underneath `llama.cpp`.

### 2. `src/` - libllama

This is the actual LLM inference library.

Important files:

```text
llama.cpp/src/
├── llama.cpp                 # main public API implementation
├── llama-model.cpp           # model loading and model representation
├── llama-model-loader.cpp    # GGUF loading logic
├── llama-context.cpp         # runtime context/session state
├── llama-graph.cpp           # builds computation graphs
├── llama-kv-cache.cpp        # KV cache handling
├── llama-memory*.cpp         # memory/cache management
├── llama-vocab.cpp           # tokenizer/vocabulary
├── llama-sampler.cpp         # token sampling
├── llama-chat.cpp            # chat template handling
├── llama-grammar.cpp         # grammar-constrained generation
├── llama-quant.cpp           # quantization support
└── models/                   # per-architecture model implementations
```

The public API is declared in:

```text
llama.cpp/include/llama.h
```

The API exposes opaque types such as:

```c
struct llama_model;
struct llama_context;
struct llama_sampler;
struct llama_vocab;
```

Typical inference flow:

1. Load a GGUF model into `llama_model`.
2. Create a `llama_context`.
3. Tokenize prompt text.
4. Decode/evaluate tokens.
5. Sample the next token.
6. Repeat until generation is complete.

### 3. `common/` - shared app utilities

`common/` contains code reused by tools and examples.

```text
llama.cpp/common/
├── arg.cpp / arg.h           # command-line argument parsing
├── common.cpp / common.h     # shared setup helpers
├── sampling.cpp              # sampling helper logic
├── chat.cpp                  # chat formatting
├── download.cpp              # HF/model download helpers
├── hf-cache.cpp              # Hugging Face cache support
├── console.cpp               # terminal handling
├── log.cpp                   # logging
└── ...
```

Most command-line tools use `common/` for argument parsing, model loading, prompt processing, logging, and shared runtime setup.

### 4. `tools/` - built executables

Key tools:

```text
llama.cpp/tools/
├── cli/              # llama-cli, simple text generation
├── server/           # llama-server, OpenAI-compatible HTTP API
├── quantize/         # quantize GGUF models
├── perplexity/       # evaluate perplexity
├── llama-bench/      # benchmark inference
├── batched-bench/    # batch benchmark
├── tokenize/         # tokenizer utility
├── embedding/        # embedding-related tools
└── rpc/              # RPC backend tooling
```

Most commonly used tools:

- `llama-cli`: run a model from the terminal
- `llama-server`: expose an HTTP/OpenAI-compatible API
- `llama-quantize`: convert models to smaller quantized formats
- `llama-bench`: benchmark inference performance

### 5. `examples/`

The `examples/` directory contains smaller reference programs showing how to use the library.

```text
llama.cpp/examples/
├── simple/
├── simple-chat/
├── embedding/
├── retrieval/
├── speculative/
├── parallel/
├── batched/
└── ...
```

Good starting points:

```text
llama.cpp/examples/simple/
llama.cpp/examples/simple-chat/
```

## Build system

The project uses CMake.

Top-level build file:

```text
llama.cpp/CMakeLists.txt
```

Important build options include:

```cmake
LLAMA_BUILD_TOOLS
LLAMA_BUILD_EXAMPLES
LLAMA_BUILD_SERVER
LLAMA_BUILD_TESTS
LLAMA_BUILD_COMMON
LLAMA_BUILD_UI
```

The main library target is defined in:

```text
llama.cpp/src/CMakeLists.txt
```

It builds the `llama` library from files such as:

```text
llama.cpp
llama-model.cpp
llama-context.cpp
llama-graph.cpp
llama-kv-cache.cpp
llama-sampler.cpp
...
```

and links it against:

```text
ggml
```

The dependency chain is roughly:

```text
tools/examples
    ↓
common
    ↓
libllama
    ↓
ggml
    ↓
CPU/GPU backends
```

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

## Mental model of inference

A simplified runtime path looks like this:

```text
User prompt
   ↓
llama-vocab.cpp tokenizes text
   ↓
llama-context.cpp stores runtime state
   ↓
llama-graph.cpp builds ggml computation graph
   ↓
ggml backend executes graph on CPU/GPU/Metal/CUDA/etc.
   ↓
logits returned
   ↓
llama-sampler.cpp picks next token
   ↓
token converted back to text
   ↓
repeat
```

For server usage:

```text
HTTP request
   ↓
tools/server
   ↓
common argument/model helpers
   ↓
libllama
   ↓
ggml backend
   ↓
HTTP response / streaming tokens
```

## Where to start reading

If your goal is:

- Run models locally: `tools/cli/`, `tools/server/`, root `scripts/`
- Understand the public API: `include/llama.h`
- Understand model loading: `src/llama-model-loader.cpp`, `src/llama-model.cpp`
- Understand inference: `src/llama-context.cpp`, `src/llama-graph.cpp`
- Understand tokenization: `src/llama-vocab.cpp`
- Understand sampling: `src/llama-sampler.cpp`
- Understand GPU/Metal backend: `ggml/src/ggml-metal/`
- Understand quantization: `ggml/src/ggml-quants.c`, `src/llama-quant.cpp`, `tools/quantize/`

## Summary

This codebase is a local desktop-oriented setup for building and running `llama.cpp`. The core inference library is `libllama`, powered by the lower-level `ggml` tensor engine, with command-line and server tools layered on top.
