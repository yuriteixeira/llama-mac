#!/usr/bin/env bash
set -euo pipefail

# Start ollama serve optimized for Apple Silicon (single user).
#
# Modes:
#   background  Configure the user launchd environment and start/restart via Homebrew services (default)
#   foreground  Run `ollama serve` in the foreground
#
# Examples:
#   ./scripts/run-ollama-server.sh
#   ./scripts/run-ollama-server.sh background
#   ./scripts/run-ollama-server.sh foreground
#
# The server exposes an OpenAI-compatible API at http://0.0.0.0:11434.
#
# Optimized variables:
#   OLLAMA_MLX=1               Enable MLX backend (Apple Silicon, 2-3× faster)
#   OLLAMA_FLASH_ATTENTION=1   Reduces peak activation memory on Apple Silicon
#   OLLAMA_KV_CACHE_TYPE=q8_0  Quantized KV cache — ~50% RAM savings vs f16
#   OLLAMA_NUM_PARALLEL=1      Single-user: prevent KV cache fragmentation
#   OLLAMA_MAX_LOADED_MODELS=1 Only one model in memory at a time
#   OLLAMA_KEEP_ALIVE=-1       Keep model loaded indefinitely (no cold-start)

MODE="${1:-background}"

OLLAMA_ENV=(
  "OLLAMA_MLX=1"
  "OLLAMA_FLASH_ATTENTION=1"
  "OLLAMA_KV_CACHE_TYPE=q8_0"
  "OLLAMA_NUM_PARALLEL=1"
  "OLLAMA_MAX_LOADED_MODELS=1"
  "OLLAMA_KEEP_ALIVE=-1"
)

print_usage() {
  cat <<'EOF'
Usage: ./scripts/run-ollama-server.sh [background|foreground]

Modes:
  background  Set Ollama env vars with launchctl and start/restart `ollama` via brew services (default)
  foreground  Run `ollama serve` in the foreground
EOF
}

export_ollama_env() {
  for entry in "${OLLAMA_ENV[@]}"; do
    export "${entry}"
  done
}

set_launchctl_ollama_env() {
  for entry in "${OLLAMA_ENV[@]}"; do
    local name="${entry%%=*}"
    local value="${entry#*=}"
    launchctl setenv "${name}" "${value}"
  done
}

run_foreground() {
  echo "Starting Ollama with MLX + Apple Silicon optimizations..."
  export_ollama_env
  exec ollama serve
}

run_background() {
  echo "Configuring Ollama launchd environment with MLX + Apple Silicon optimizations..."
  set_launchctl_ollama_env

  echo "Starting/restarting Ollama via Homebrew services..."
  brew services restart ollama

  echo "Ollama background service is managed by Homebrew services. Check status with: brew services list"
}

case "${MODE}" in
  background)
    run_background
    ;;
  foreground)
    run_foreground
    ;;
  -h|--help|help)
    print_usage
    ;;
  *)
    echo "Unknown mode: ${MODE}" >&2
    print_usage >&2
    exit 2
    ;;
esac
