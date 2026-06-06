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

Basedir is `/Users/yuriteixeira/Workspaces/local/llama-cpp`

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
  --parallel 1 \
  --host 0.0.0.0 \
  --port 12345
```

`llama-models.ini`:

```ini
version = 1

[*]
c = 32768
n-gpu-layers = all

[qwen3.6-27b-q5]
model = ./models/Qwen3.6-27B-Q5_K_M.gguf
load-on-startup = false

[qwen3.6-27b-q4]
model = ./models/Qwen3.6-27B-Q4_K_M.gguf
load-on-startup = false

[qwen3.6-35b-a3b-q4]
model = ./models/Qwen3.6-35B-A3B-UD-Q4_K_M.gguf
load-on-startup = false

[gemma-4-26b-a4b-it-q4]
model = ./models/gemma-4-26B-A4B-it-Q4_K_M.gguf
load-on-startup = false
```

### Key flags explained

| Flag              | Value                  | Why                                                       |
| ----------------- | ---------------------- | --------------------------------------------------------- |
| `--models-preset` | `./llama-models.ini`   | Defines available models and shared runtime settings      |
| `--models-max`    | `1`                    | Allow only one model to be loaded at a time               |
| `--parallel`      | `1`                    | Single-user setup; avoids reserving extra parallel slots  |
| `--host`          | `0.0.0.0`              | Expose the server to other tools/devices on the network   |
| `--port`          | `12345`                | OpenAI-compatible API port                                |
| `n-gpu-layers`    | `all`                  | Explicitly offload all possible layers to Metal GPU       |
| `c`               | `32768`                | Context window; good default for agentic coding           |

`--models-autoload` is enabled by default, so requests dynamically load the requested preset by model name. `--jinja` and `-fa/--flash-attn` are enabled/auto by default in current llama.cpp, so they are intentionally omitted.

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

```bash
# Flash attention is auto by default; force it only if needed
./llama.cpp/build/bin/llama-cli -m model.gguf -ngl all -fa on ...
```

### 5.3 KV Cache Quantisation (save RAM for bigger contexts)

```bash
# Use Q8_0 KV cache to halve cache memory (vs F16 default)
./llama.cpp/build/bin/llama-cli -m model.gguf -ngl all \
  --cache-type-k q8_0 \
  --cache-type-v q8_0 \
  -c 32768 ...
```

> Combining flash attention + quantised KV cache lets you push 70B models to 32K context within 64 GB.

### 5.4 Thermal Management

The M4 Max will thermal-throttle under sustained inference. Tips:
- Use a laptop stand with airflow
- In `System Settings → Battery → Options`, turn off "Optimise video streaming while on battery"
- Run `sudo powermetrics --samplers gpu_power -i 5000` in another terminal to monitor GPU thermals/clocks

---

## Phase 6 — Recommended Starter Configuration

For an agentic coding daily-driver, start with **two models**:

1. **Primary agent** — `Qwen3.6-27B Q5_K_M` — April 2026; strong agentic coding/tool-calling reputation; 256K native context; best quality-per-GB
2. **Fallback / faster primary** — `Qwen3.6-27B Q4_K_M` — same model, faster and lighter
3. **Alternative fast agent** — `Gemma 4 26B-A4B Q4_K_M` — April 2026; Google's MoE with native function-calling tokens; only 4B active = very fast; 256K ctx

Run via `llama-server`, then point your coding agent (Aider, Continue.dev, Cline, qwen-code, or Open WebUI) at `http://localhost:12345`. Select a model by request name, e.g. `qwen3.6-27b-q5` or `qwen3.6-27b-q4`.

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

Create `~/Library/LaunchAgents/local.llama-server.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Label</key>
    <string>local.llama-server</string>

    <key>ProgramArguments</key>
    <array>
      <string>/Users/yuriteixeira/Workspaces/local/llama-cpp/scripts/run-llama-server.sh</string>
    </array>

    <key>WorkingDirectory</key>
    <string>/Users/yuriteixeira/Workspaces/local/llama-cpp</string>

    <key>RunAtLoad</key>
    <true/>

    <key>KeepAlive</key>
    <true/>

    <key>StandardOutPath</key>
    <string>/Users/yuriteixeira/Workspaces/local/llama-cpp/logs/llama-server.out.log</string>

    <key>StandardErrorPath</key>
    <string>/Users/yuriteixeira/Workspaces/local/llama-cpp/logs/llama-server.err.log</string>
  </dict>
</plist>
```

Enable and start it:

```bash
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/local.llama-server.plist
launchctl enable gui/$(id -u)/local.llama-server
launchctl kickstart -k gui/$(id -u)/local.llama-server
```

Check status:

```bash
launchctl print gui/$(id -u)/local.llama-server
```

Stop/remove it:

```bash
launchctl bootout gui/$(id -u)/local.llama-server
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

# 3. Create model presets
cat > llama-models.ini <<'EOF'
version = 1

[*]
c = 32768
n-gpu-layers = all

[qwen3.6-27b-q5]
model = ./models/Qwen3.6-27B-Q5_K_M.gguf
load-on-startup = false
EOF

# 4. Run preset-based router; dynamically loads one model at a time
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
