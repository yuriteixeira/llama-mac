# 002 — Fix Qwen 27B “Pi harness eviction” under llama-server

## Summary

The failure does **not** look like the 65K llama.cpp context filling up, nor like macOS/Metal memory pressure. In the reproduced agent session, Qwen 27B was still at only ~6–12K prompt tokens, but it began returning almost everything in `reasoning_content` and then hit `finish_reason = length` before producing normal assistant content.

For Pi, this looks like the model “forgot” or “evicted” the harness: it keeps internally planning/tool-chaining, but the visible assistant `content` is empty or truncated. Subsequent codebase questions amplify the problem because tool results and internet-search results increase the prompt and trigger longer thinking blocks.

Primary fix: run the Qwen 27B presets as **non-thinking agent models** by disabling llama.cpp reasoning/thinking at the server level.

---

## What I ran

Started the repository script in verbose mode with llama.cpp logging enabled:

```bash
LLAMA_ARG_LOG_VERBOSITY=2 \
LLAMA_ARG_LOG_TIMESTAMPS=1 \
LLAMA_ARG_LOG_PREFIX=1 \
LLAMA_ARG_LOG_FILE="$PWD/logs/llama-server-verbose-test.log" \
./scripts/run-llama-server.sh
```

Then simulated a Pi-like multi-turn codebase exploration session against `qwen3.6-27b-q4` with:

- local file listing
- file reads
- grep-style repo search
- web-search style tool calls
- follow-up codebase questions

Logs produced:

- `logs/probe-agent-session-qwen-q4.out`
- `logs/llama-server-verbose-test.stdout`
- `logs/llama-server-verbose-test.log`

I then repeated the same session with:

```bash
LLAMA_ARG_REASONING=off ./scripts/run-llama-server.sh
```

Logs produced:

- `logs/probe-agent-session-qwen-q4-reasoning-off.out`
- `logs/llama-server-verbose-test-reasoning-off.stdout`

---

## Evidence

### 1. Context was far from full

The configured context is active:

```text
n_ctx = 65536
n_ctx_train = 262144
```

The failing reproduction was nowhere near 65K tokens:

```text
finish=length usage={'completion_tokens': 700, 'prompt_tokens': 6248, 'total_tokens': 6948}
finish=length usage={'completion_tokens': 700, 'prompt_tokens': 6283, 'total_tokens': 6983}
```

So the symptom is not ordinary context-window exhaustion.

### 2. Qwen was emitting planning in `reasoning_content`, not useful assistant `content`

With default llama.cpp reasoning auto-detection, Qwen replies looked like:

```json
{
  "role": "assistant",
  "content": "",
  "reasoning_content": "The user is asking me to analyze ...",
  "tool_calls": [...]
}
```

Later turns ended with:

```text
finish = length
content = ""
reasoning_content = "... long internal analysis ..."
```

That is exactly the shape that can make a coding-agent harness appear to be lost: the model is still spending tokens, but the harness-visible channel is empty or incomplete.

### 3. Disabling reasoning changes the behavior immediately

With `LLAMA_ARG_REASONING=off`, the same style of session returned normal visible content plus tool calls:

```json
{
  "role": "assistant",
  "content": "I'll explore the llama-mac repo to understand how llama-server is configured...",
  "tool_calls": [...]
}
```

The session still had imperfect local-model tool behavior, but the major “empty content / hidden reasoning / length finish” failure disappeared.

### 4. The cache warning is real but likely secondary

The server logs also show:

```text
--cache-idle-slots requires --kv-unified, disabling
```

This is caused by `--parallel 1`: llama.cpp only enables unified KV by default when slot count is automatic. Since this setup explicitly sets `--parallel 1`, idle-slot prompt-cache behavior is disabled unless `--kv-unified` is also set.

This is worth fixing for cleaner slot/cache behavior, but it did **not** explain the reproduced harness failure: prompt-cache checkpoints were being saved/restored, and the failure occurred at very small prompt sizes.

---

## Root cause

Qwen 27B is being served as a thinking/reasoning chat model. llama.cpp auto-detects the template and extracts thought text into `reasoning_content` with an unrestricted reasoning budget.

For agentic coding through Pi, that is a bad default because:

1. tool-heavy prompts encourage long internal planning;
2. internet/tool results increase prompt complexity;
3. the model can spend the entire completion budget in reasoning;
4. Pi expects actionable assistant content/tool calls, not an unbounded hidden thinking transcript;
5. follow-up questions then look like the harness was evicted even though context is not full.

---

## Recommended fix

### Change `scripts/run-llama-server.sh`

Keep server-level settings model-neutral, but add `--kv-unified` for stable slot/prompt-cache behavior:

```bash
exec "${LLAMA_BIN_DIR}/llama-server" \
  --models-preset "${ROOT_DIR}/llama-models.ini" \
  --models-max 1 \
  --parallel 1 \
  --kv-unified \
  --host 0.0.0.0 \
  --port 12345
```

### Change `llama-models.ini`

Disable reasoning on the Qwen 27B presets used by Pi, and keep explicit `*-think` aliases for manual chat:

```ini
[qwen3.6-27b-q4]
model = ./models/Qwen3.6-27B-Q4_K_M.gguf
reasoning = off
reasoning-budget = 0
chat-template-kwargs = {"enable_thinking":false}

[qwen3.6-27b-q4-think]
model = ./models/Qwen3.6-27B-Q4_K_M.gguf
reasoning = on
reasoning-budget = -1
chat-template-kwargs = {"enable_thinking":true}
```

Notes:

- `--kv-unified` removes the idle-slot cache warning and enables the default idle-slot prompt-cache behavior to work as intended.
- `reasoning = off` disables template-level thinking where supported.
- `reasoning-budget = 0` is the stronger llama.cpp-compatible guard for Qwen-style thinking models.
- `chat-template-kwargs = {"enable_thinking":false}` makes the intent explicit for Qwen templates.
- Point Pi at the non-`*-think` Qwen aliases.

---

## Validation checklist

After changing the script:

```bash
./scripts/run-llama-server.sh
```

Then verify:

1. First model load still reports `n_ctx = 65536`.
2. Logs no longer show repeated completions ending in `finish_reason = length` at small prompt sizes.
3. OpenAI responses have useful `message.content` and/or valid `tool_calls`.
4. `message.reasoning_content` is absent or minimal.
5. The `--cache-idle-slots requires --kv-unified` warning is gone.

---

## If the issue persists

Try these in order:

1. Increase Pi/client `max_tokens` for local Qwen to at least `2048`–`4096`.
2. Reduce context from `65536` to `32768` only if memory pressure appears; current evidence does not require it.
3. Prefer `qwen3.6-27b-q4` over `qwen3.6-27b-q5_k_m` for faster tool loops.
4. If tool-call syntax remains unreliable, test the Gemma preset; Qwen quality may be higher, but local tool formatting can vary by quant/template.
