# 001 — llama.cpp on Apple M4 Max (64 GB) with Metal 4

## Hardware Profile

| Spec               | Value                                      |
| ------------------- | ------------------------------------------ |
| Machine             | MacBook Pro 16″ (Mac16,5)                  |
| Chip                | Apple M4 Max                               |
| CPU Cores           | 16 (12P + 4E)                              |
| GPU Cores           | 40                                         |
| Unified Memory      | 64 GB LPDDR5                               |
| Memory Bandwidth    | ~546 GB/s                                  |
| Metal Support       | **Metal 4**                                |
| OS                  | macOS Tahoe 26.5 (build 25F71)             |
| Disk Free           | ~632 GB                                    |
| Homebrew            | ✅ installed at `/opt/homebrew`             |

### Key Advantage

Apple Silicon **unified memory** means the full 64 GB is shared between CPU and GPU — no PCIe bottleneck, no VRAM ceiling. Combined with 546 GB/s bandwidth and 40 GPU cores with Metal 4 support, this is one of the best consumer setups for local LLM inference.

### Assumptions

Assuming basedir is `~/Workspaces/local/llama-mac`

---

## Phase 1 — Build llama.cpp with Metal 4

### 1.1 Initialise submodule

```bash
git submodule update --init --recursive llama.cpp
```

### 1.2 Build (Metal-optimised release)

```bash
cmake -S llama.cpp -B llama.cpp/build \
  -DGGML_METAL=ON \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_OSX_ARCHITECTURES=arm64
cmake --build llama.cpp/build --config Release -j14
```

> `-DGGML_METAL=ON` enables the Metal compute backend, which on macOS 26+ automatically picks up **Metal 4 Tensor API** optimisations (merged upstream in PR #16634 and refined in #20962).
> `-j14` saturates all 14 CPU cores for the build.

### 1.3 Verify Metal

```bash
./llama.cpp/build/bin/llama-cli --version
./llama.cpp/build/bin/llama-server --list-devices   # should list Apple GPU / Metal device
```

---

## Phase 2 — Model Selection (2026-only, Agentic Coding Focus)

Selection rule: **only 2026 releases are accepted**, preferably from the last ~3 months, and the model must be practical on this **64 GB M4 Max** with llama.cpp + Metal. That excludes excellent but huge frontier models whose GGUF quants exceed local memory.

With 64 GB unified memory, macOS + desktop use ~4–6 GB, leaving **~58 GB for model weights + KV cache**.

### Tier 1 — Primary local coding agents ★ Best current fit

| Model                                | Release   | Architecture     | Quant      | GGUF Size | Est. RAM (32K ctx)  | Why                                                                     |
| ------------------------------------ | --------- | ---------------- | ---------- | --------- | ------------------- | ----------------------------------------------------------------------  |
| **Qwen3.6-27B**                      | Apr 2026  | 27B dense        | Q5_K_M     | ~19 GB    | ~24 GB              | Current local default for serious coding; strong refactoring + tools    |
| **Qwen3.6-27B**                      | Apr 2026  | 27B dense        | Q4_K_M     | ~17 GB    | ~22 GB              | Best speed/quality fit; 77.2% claimed SWE-bench Verified; 256K ctx      |
| **Qwen3.6-27B**                      | Apr 2026  | 27B dense        | Q8_0       | ~29 GB    | ~34 GB              | Highest-fidelity local option that still leaves room for long context   |
| **Qwen3.6-35B-A3B**                  | Apr 2026  | 35B MoE (3B act) | Q4_K_M     | ~21 GB    | ~25 GB              | Fast MoE variant; 73.4% claimed SWE-bench Verified; 51.5 Terminal-Bench |

> **Top pick:** `Qwen3.6-27B Q5_K_M` if available; otherwise `Qwen3.6-27B Q4_K_M`. It is new enough, compact enough, and has the strongest agentic-coding reputation among models that fit comfortably on your Mac.

### Tier 2 — Alternative 2026 agentic/tool-calling models

| Model                                | Release   | Architecture     | Quant      | GGUF Size | Est. RAM (32K ctx)  | Why                                                                    |
| ------------------------------------ | --------- | ---------------- | ---------- | --------- | ------------------- | ---------------------------------------------------------------------- |
| **Gemma 4 26B-A4B**                  | Apr 2026  | 26B MoE (4B act) | Q5_K_M     | ~19 GB    | ~24 GB              | Google's latest open model family; native function-calling tokens      |
| **Gemma 4 26B-A4B**                  | Apr 2026  | 26B MoE (4B act) | Q4_K_M     | ~16 GB    | ~20 GB              | Fast secondary coding agent; 256K ctx; strong agentic workflow support |
| **Gemma 4 26B-A4B**                  | Apr 2026  | 26B MoE (4B act) | Q8_0       | ~27 GB    | ~31 GB              | Higher-fidelity Gemma option while still fitting easily                |

> **Gemma 4** is included because it is a 2026 release and has first-class tool/function-calling support. For coding-agent use, test it against Qwen3.6 on your own repos before making it default.

### Watchlist / excluded despite being new

| Model                    | Release       | Reason                                                                          |
| ------------------------ | ------------- | ------------------------------------------------------------------------------- |
| **MiniMax M3**           | Jun 2026      | Too large for 64 GB local GGUF; smallest practical quants require ~100 GB+      |
| **Kimi K2.6**            | Apr 2026      | Excellent agentic coding model, but GGUF quants require hundreds of GB          |
| **DeepSeek V4 Flash/Pro**| Apr–May 2026  | Strong coding models, but local GGUF quants exceed 64 GB once context is added  |
| **Step 3.7 Flash**       | May 2026      | Smallest GGUFs are ~62–76 GB before OS/context; too tight / too degraded        |
| **KAT-Coder-V2**         | Mar 2026      | Very strong paper score, but no practical confirmed GGUF path for this machine  |
| **Devstral 2 / Small 2** | Dec 2025      | Good agentic model, but excluded by the user's 2026-only rule                   |
| **Qwen3-Coder-30B-A3B**  | 2025          | Good, but excluded because newer Qwen3.6 models replace it                      |
| **Qwen 2.5 Coder**       | 2025          | Superseded by Qwen3.6                                                           |
| **Gemma 3**              | 2025          | Superseded by Gemma 4                                                           |

---

## Phase 3 — Download Models

### Option A — `hf` CLI (recommended)

Resumable, handles gated models (auth), verifies file integrity automatically.

```bash
# Install HF CLI (one-time)
pip install huggingface-hub

# ★ Top pick: Qwen3.6-27B Q5_K_M
hf download \
  unsloth/Qwen3.6-27B-GGUF \
  Qwen3.6-27B-Q5_K_M.gguf \
  --local-dir models/

# Fallback / faster: Qwen3.6-27B Q4_K_M
hf download \
  unsloth/Qwen3.6-27B-GGUF \
  Qwen3.6-27B-Q4_K_M.gguf \
  --local-dir models/

# Qwen3.6-35B-A3B (MoE variant — fast inference)
hf download \
  unsloth/Qwen3.6-35B-A3B-GGUF \
  Qwen3.6-35B-A3B-UD-Q4_K_M.gguf \
  --local-dir models/

# Gemma 4 26B-A4B it (native function calling)
hf download \
  ggml-org/gemma-4-26B-A4B-it-GGUF \
  gemma-4-26B-A4B-it-Q4_K_M.gguf \
  --local-dir models/
```

### Option B — `wget` (no dependencies)

Simpler, no extra install needed. Use `-c` for resume support.

From the basedir:

```bash
mkdir -p models

# ★ Top pick: Qwen3.6-27B Q5_K_M
wget -c "https://huggingface.co/unsloth/Qwen3.6-27B-GGUF/resolve/main/Qwen3.6-27B-Q5_K_M.gguf" \
  -P models/

# Fallback / faster: Qwen3.6-27B Q4_K_M
wget -c "https://huggingface.co/unsloth/Qwen3.6-27B-GGUF/resolve/main/Qwen3.6-27B-Q4_K_M.gguf" \
  -P models/

# Qwen3.6-35B-A3B (MoE)
wget -c "https://huggingface.co/unsloth/Qwen3.6-35B-A3B-GGUF/resolve/main/Qwen3.6-35B-A3B-UD-Q4_K_M.gguf" \
  -P models/

# Gemma 4 26B-A4B it
wget -c "https://huggingface.co/ggml-org/gemma-4-26B-A4B-it-GGUF/resolve/main/gemma-4-26B-A4B-it-Q4_K_M.gguf" \
  -P models/
```

> **Tip:** unsloth and bartowski repos on HF are reliable sources for pre-quantised GGUF files.

---

## Phase 4 — Run with Optimal Settings

### 4.1 CLI (interactive chat)

```bash
./llama.cpp/build/bin/llama-cli \
  -m models/Qwen3.6-27B-Q5_K_M.gguf \
  -ngl all \
  -c 32768 \
  -i
```

### 4.2 Server (OpenAI-compatible API with model presets)

Run from the repository root:

```bash
./scripts/run-llama-server.sh
```

The script runs:

```bash
./llama.cpp/build/bin/llama-server \
  --models-preset ./llama-models.ini \
  --models-max 1 \
  --host 0.0.0.0 \
  --port 12345
```

All model-performance settings live in the `[*]` (global) section of the INI file. The router cascades these to child processes via `LLAMA_ARG_*` environment variables — CLI args are kept minimal (router control only).

`llama-models.ini`:

```ini
version = 1

[*]
c = 65536
n-gpu-layers = all
; Best default on 64 GB Apple Silicon: near-F16 KV quality with ~50% KV RAM.
; Use lower-bit caches only for extreme context/model-fit experiments.
cache-type-k = q8_0
cache-type-v = q8_0
load-on-startup = false
; Apple Silicon performance: Metal Flash Attention + prefix caching + mlock.
fa = on
mlock = on
cache-reuse = 256
b = 2048
ub = 2048
prio = 2
; Unified KV cache (shared pool across slots) + single parallel slot.
kvu = on
np = 1

; Agent-facing Qwen presets: disable Qwen thinking/reasoning so tool calls
; and visible assistant content are not starved by hidden reasoning tokens.
[qwen3.6-27b-q5_k_m]
model = ./models/Qwen3.6-27B-Q5_K_M.gguf
reasoning = off
reasoning-budget = 0
chat-template-kwargs = {"enable_thinking":false}

[qwen3.6-27b-q4]
model = ./models/Qwen3.6-27B-Q4_K_M.gguf
reasoning = off
reasoning-budget = 0
chat-template-kwargs = {"enable_thinking":false}

; Manual-chat aliases if you explicitly want Qwen thinking mode.
[qwen3.6-27b-q5_k_m-think]
model = ./models/Qwen3.6-27B-Q5_K_M.gguf
reasoning = on
reasoning-budget = -1
chat-template-kwargs = {"enable_thinking":true}

[qwen3.6-27b-q4-think]
model = ./models/Qwen3.6-27B-Q4_K_M.gguf
reasoning = on
reasoning-budget = -1
chat-template-kwargs = {"enable_thinking":true}

[qwen3.6-35b-a3b-q4]
model = ./models/Qwen3.6-35B-A3B-UD-Q4_K_M.gguf

[gemma-4-26b-a4b-it-q4]
model = ./models/gemma-4-26B-A4B-it-Q4_K_M.gguf
```

### Key flags explained

| Flag              | Value                  | Why                                                       |
| ----------------- | ---------------------- | --------------------------------------------------------- |
| `--models-preset` | `./llama-models.ini`   | Defines available models and shared runtime settings      |
| `--models-max`    | `1`                    | Allow only one model to be loaded at a time               |
| `--host`          | `0.0.0.0`              | Expose the server to other tools/devices on the network   |
| `--port`          | `12345`                | OpenAI-compatible API port                                |
| `n-gpu-layers`    | `all`                  | Explicitly offload all possible layers to Metal GPU       |
| `c`               | `65536`                | Context window; better default for repo-scale agentic coding on 64 GB M4 Max |
| `cache-type-k/v`  | `q8_0`                 | Best default KV cache strategy: near-F16 quality with roughly half the KV RAM |
| `fa`              | `on`                   | Metal Flash Attention: faster prefill, smaller memory footprint, prerequisite for KV cache quantization |
| `mlock`           | `on`                   | Lock model in RAM; prevents macOS paging on 64 GB with headroom |
| `cache-reuse`     | `256`                  | Prefix caching: skips redundant prefill on repeated system prompts (key for agent loops) |
| `b` / `ub`        | `2048`                 | Batch / unified batch size; recommended default for M4 Max throughput |
| `prio`            | `2`                    | High thread priority so Metal threads aren't starved by macOS background tasks |
| `kvu`             | `on`                   | Unified KV cache (shared pool across slots)               |
| `np`              | `1`                    | Single-user setup; avoids reserving extra parallel slots  |
| `reasoning` / `reasoning-budget` | `off` / `0` on Qwen 27B agent presets | Prevents Qwen thinking blocks from consuming the completion budget before visible tool calls/content |

`--models-autoload` is enabled by default, so requests dynamically load the requested preset by model name. Reasoning is disabled only in the Qwen 27B agent-facing presets; use the `*-think` aliases for manual chats where you explicitly want thinking mode.

> **Why INI `[*]` instead of CLI flags?** The router cascades the global `[*]` section to child processes via `LLAMA_ARG_*` environment variables. This avoids duplication and keeps CLI args reserved for router-level control (`--host`, `--port`, `--models-max`, etc.). CLI args override INI values when both are present, so this is the cleanest single-source-of-truth approach.

### 4.3 Context Window Budget

For Qwen3.6-27B Q5_K_M (~19 GB weights):
- **32K context** → ~24 GB total → ✅ tons of headroom
- **128K context** → ~34 GB total → ✅ comfortable
- **256K context** → ~49 GB total → ✅ fits, but close heavy apps

For Qwen3.6-27B Q4_K_M (~17 GB weights):
- **32K context** → ~22 GB total → ✅ tons of headroom
- **128K context** → ~32 GB total → ✅ comfortable
- **256K context** → ~47 GB total → ✅ fits

For Qwen3.6-35B-A3B Q4_K_M (~21 GB weights):
- **32K context** → ~25 GB total → ✅ tons of headroom
- **128K context** → ~36 GB total → ✅ comfortable
- **256K context** → ~51 GB total → ⚠️ tight, close other apps

For Gemma 4 26B-A4B Q4_K_M (~16 GB weights):
- **32K context** → ~20 GB total → ✅ tons of headroom
- **128K context** → ~31 GB total → ✅ comfortable
- **256K context** → ~46 GB total → ✅ fits (native max)

For Devstral Small 2 24B Q8_0 (~25 GB weights):
- **32K context** → ~30 GB total → ✅ comfortable
- **128K context** → ~42 GB total → ✅ fits (native max)

---

## Phase 5 — Metal-Specific Optimisations

### 5.1 Metal 4 Tensor API (automatic)

On macOS 26 (Tahoe) + M4 Max, the latest llama.cpp master **automatically uses Metal 4 Tensor API** when available. This accelerates prompt processing (prefill) significantly. No extra flags needed — just ensure you're on the latest llama.cpp.

### 5.2 Flash Attention

Flash Attention is enabled via `fa = on` in the `[*]` section of `llama-models.ini`. This enables the Metal Flash Attention kernel: faster prefill at long contexts, smaller memory footprint per token, and a prerequisite for KV cache quantization. Always keep this on for Apple Silicon.

### 5.3 KV Cache Quantisation (default strategy)

Use **Q8_0 for both K and V cache by default** on this machine:

```bash
./llama.cpp/build/bin/llama-cli -m model.gguf -ngl all \
  --cache-type-k q8_0 \
  --cache-type-v q8_0 \
  -c 65536 ...
```

Why this is the default:
- llama.cpp's built-in default is `f16`, which is the most conservative/compatibility-first choice.
- `q8_0` cuts KV cache memory by roughly half with negligible quality loss for coding-agent workloads.
- On a 64 GB M4 Max, the memory saved is better spent on larger context than on F16 KV cache precision.

Do **not** make lower-bit caches the normal default (`q4_0`, `q4_1`, `iq4_nl`, `q5_0`, `q5_1`, or UI-labelled “turbo2/3/4” cache modes). They are useful emergency/experimental profiles for fitting extreme contexts or larger models, but they carry higher risk of long-context degradation, retrieval mistakes, and coding-agent instability.

> Combining flash attention + Q8_0 KV cache is the best daily-driver balance. Drop below Q8_0 only when a specific model/context does not fit.

### 5.4 Qwen reasoning strategy for coding agents

For Pi and other tool-heavy coding agents, run Qwen 27B in **non-thinking mode** by default:

```ini
reasoning = off
reasoning-budget = 0
chat-template-kwargs = {"enable_thinking":false}
```

Why:
- Agent harnesses already externalize planning via tool calls, file reads, grep/search, and follow-up observations.
- Qwen thinking blocks can consume the completion budget in hidden `reasoning_content` before visible assistant content or valid tool calls are emitted.
- This failure can look like the harness/system prompt was “evicted” even when the llama.cpp context is far from full.

Keep separate `*-think` aliases for manual chats where you explicitly want long reasoning. Do not point Pi at those aliases for normal codebase exploration.

### 5.5 Thermal Management

The M4 Max will thermal-throttle under sustained inference. Tips:
- Use a laptop stand with airflow
- In `System Settings → Battery → Options`, turn off "Optimise video streaming while on battery"
- Run `sudo powermetrics --samplers gpu_power -i 5000` in another terminal to monitor GPU thermals/clocks

---

## Phase 6 — Recommended Starter Configuration

For an agentic coding daily-driver, start with these presets:

1. **Primary agent** — `qwen3.6-27b-q5_k_m` — Qwen 27B Q5_K_M with reasoning disabled for reliable Pi/tool use.
2. **Fallback / faster primary** — `qwen3.6-27b-q4` — same Qwen 27B family, faster/lighter, also with reasoning disabled.
3. **Manual reasoning aliases** — `qwen3.6-27b-q5_k_m-think` and `qwen3.6-27b-q4-think` — use only for direct chat, not Pi codebase tooling.
4. **Alternative fast agent** — `gemma-4-26b-a4b-it-q4` — Google's MoE with native function-calling tokens; only 4B active = very fast; 256K ctx.

Run via `llama-server`, then point your coding agent (Aider, Continue.dev, Cline, qwen-code, or Open WebUI) at `http://localhost:12345`. Select an agent preset by request name, e.g. `qwen3.6-27b-q5_k_m` or `qwen3.6-27b-q4`.

```bash
# Serve preset-based router; dynamically loads one model at a time
./scripts/run-llama-server.sh
```

---

## Phase 7 — Start llama-server at login

Use a macOS LaunchAgent so the server starts automatically when you log in.

```bash
mkdir -p ~/Library/LaunchAgents logs
```

Create `~/Library/LaunchAgents/llama-server.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Label</key>
    <string>llama-server</string>

    <key>ProgramArguments</key>
    <array>
      <string>~/Workspaces/local/llama-mac/scripts/run-llama-server.sh</string>
    </array>

    <key>WorkingDirectory</key>
    <string>~/Workspaces/local/llama-mac</string>

    <key>RunAtLoad</key>
    <true/>

    <key>KeepAlive</key>
    <true/>

    <key>StandardOutPath</key>
    <string>~/Workspaces/local/llama-mac/logs/llama-server.out.log</string>

    <key>StandardErrorPath</key>
    <string>~/Workspaces/local/llama-mac/logs/llama-server.err.log</string>
  </dict>
</plist>
```

Enable and start it:

```bash
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/llama-server.plist
launchctl enable gui/$(id -u)/llama-server
launchctl kickstart -k gui/$(id -u)/llama-server
```

Check status:

```bash
launchctl print gui/$(id -u)/llama-server
```

Stop/remove it:

```bash
launchctl bootout gui/$(id -u)/llama-server
```

> This starts at user login, not before login. For a personal MacBook setup, that is usually the right behavior.

---

## Quick Start (copy-paste)

```bash
# 1. Initialise submodule & build
git submodule update --init --recursive llama.cpp
cmake -S llama.cpp -B llama.cpp/build -DGGML_METAL=ON -DCMAKE_BUILD_TYPE=Release
cmake --build llama.cpp/build --config Release -j16

# 2. Download the top agentic coding model to root ./models
mkdir -p models
pip install huggingface-hub
hf download unsloth/Qwen3.6-27B-GGUF \
  Qwen3.6-27B-Q5_K_M.gguf --local-dir models/

# 3. Create model presets (performance flags in [*] global section)
cat > llama-models.ini <<'EOF'
version = 1

[*]
c = 65536
n-gpu-layers = all
cache-type-k = q8_0
cache-type-v = q8_0
load-on-startup = false
fa = on
mlock = on
cache-reuse = 256
b = 2048
ub = 2048
prio = 2
kvu = on
np = 1

[qwen3.6-27b-q5_k_m]
model = ./models/Qwen3.6-27B-Q5_K_M.gguf
reasoning = off
reasoning-budget = 0
chat-template-kwargs = {"enable_thinking":false}

[qwen3.6-27b-q5_k_m-think]
model = ./models/Qwen3.6-27B-Q5_K_M.gguf
reasoning = on
reasoning-budget = -1
chat-template-kwargs = {"enable_thinking":true}
EOF

# 4. Run preset-based router; dynamically loads one model at a time.
./scripts/run-llama-server.sh
```

---

## References

- [llama.cpp Metal 4 Tensor API PR #16634](https://github.com/ggml-org/llama.cpp/pull/16634)
- [Metal Tensor API optimisations PR #20962](https://github.com/ggml-org/llama.cpp/pull/20962)
- [M4 Max Benchmarks (~12.5 tok/s on 70B)](https://markaicode.com/benchmarks/llamacpp-m4-max-benchmark/)
- [Apple Silicon LLM Guide](https://llmhardware.io/guides/mac-studio-m4-max-llm-guide)
- [Qwen3.6 — 77.2% SWE-bench Verified](https://awesomeagents.ai/models/qwen-3-6-27b/)
- [Gemma 4 for Agentic Coding](https://bernhardwannasek.com/using-gemma-4-for-agentic-coding/)
- [Kimi K2.6 local GGUF hardware requirements](https://www.unsloth.ai/docs/models/kimi-k2.6)
- [MiniMax local deployment hardware requirements](https://platform.minimax.io/docs/guides/local-deploy)
