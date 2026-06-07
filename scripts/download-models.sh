#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODELS_DIR="$ROOT_DIR/models"
MANIFEST="$ROOT_DIR/models.txt"

MAX_JOBS="${MAX_JOBS:-3}"
DOWNLOADS=()

# Parse models.txt — one URL per line, skip blanks and comments
while IFS= read -r url; do
  [[ "$url" =~ ^[[:space:]]*# ]] && continue
  [[ -z "${url// /}" ]] && continue
  url="${url%%[[:space:]]}"  # trim trailing whitespace

  # Extract filename from URL
  filename="${url##*/}"
  filename="${filename%%\?*}"  # strip query string

  # Derive dest path: models/<org>/<filename>
  # e.g. https://huggingface.co/unsloth/Qwen3.6-27B-GGUF/resolve/main/<file>
  #      → models/unsloth/<file>
  path_without_file="${url%%/resolve/*}"
  # path_without_file = https://huggingface.co/unsloth/Qwen3.6-27B-GGUF
  # Take the last two segments as the repo dir
  repo_dir="${path_without_file##*/}"       # Qwen3.6-27B-GGUF
  org="${path_without_file%/*}"             # https://huggingface.co/unsloth
  org="${org##*/}"                          # unsloth

  dest="$MODELS_DIR/$org/$filename"
  DOWNLOADS+=("$dest"$'\t'"$url")
done < "$MANIFEST"

download_one() {
  local spec="$1"
  local dest="${spec%%$'\t'*}"
  local url="${spec#*$'\t'}"

  mkdir -p "$(dirname "$dest")"

  if [[ -f "$dest" ]]; then
    echo "  [SKIP] $(basename "$dest") already exists"
    return 0
  fi

  echo "  [DOWN] $dest"
  wget -c "$url" -O "$dest"
}

export -f download_one

run_downloads() {
  local -a pids=()
  local -a specs=()

  for spec in "${DOWNLOADS[@]}"; do
    specs+=("$spec")
  done

  for spec in "${specs[@]}"; do
    download_one "$spec" &
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

run_downloads
