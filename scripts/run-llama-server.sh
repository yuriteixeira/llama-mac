#!/usr/bin/env bash
set -euo pipefail

# llama-server from Homebrew — no DYLD_LIBRARY_PATH needed; Homebrew's rpaths
# resolve shared libraries correctly wherever this repository is cloned.

exec llama-server \
  --models-preset "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/llama-models.ini" \
  --models-max 1 \
  --host 0.0.0.0 \
  --port 12345
