#!/usr/bin/env bash
set -euo pipefail

# Pull MLX-optimized models from Ollama.
#
# Models are listed in models-ollama.txt (one tag per line).
# The OLLAMA_MLX=1 environment variable enables the MLX backend.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="$ROOT_DIR/models-ollama.txt"

MAX_JOBS="${MAX_JOBS:-3}"
PULLS=()

if [[ ! -f "$MANIFEST" ]]; then
  echo "error: $MANIFEST not found" >&2
  exit 1
fi

# Parse models-ollama.txt — one model tag per line, skip blanks and comments
while IFS= read -r tag; do
  [[ "$tag" =~ ^[[:space:]]*# ]] && continue
  [[ -z "${tag// /}" ]] && continue
  tag="${tag%%[[:space:]]}"  # trim trailing whitespace
  PULLS+=("$tag")
done < "$MANIFEST"

if [[ ${#PULLS[@]} -eq 0 ]]; then
  echo "No models to pull. Edit $MANIFEST to add model tags." >&2
  exit 0
fi

pull_one() {
  local tag="$1"

  if ollama list 2>/dev/null | grep -q "$tag"; then
    echo " [SKIP] $tag already exists"
    return 0
  fi

  echo " [PULL] $tag"
  ollama pull "$tag"
}

export -f pull_one

run_pulls() {
  local -a pids=()
  local -a tags=()

  for tag in "${PULLS[@]}"; do
    tags+=("$tag")
  done

  for tag in "${tags[@]}"; do
    pull_one "$tag" &
    pids+=($!)

    if (( ${#pids[@]} >= MAX_JOBS )); then
      for pid in "${pids[@]}"; do
        wait "$pid"
      done
      pids=()
    fi
  done

  for pid in "${pids[@]}"; do
    wait "$pid"
  done
}

run_pulls
