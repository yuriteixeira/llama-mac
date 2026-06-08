#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODELS_DIR="$ROOT_DIR/models"
MANIFEST="$ROOT_DIR/models.txt"
PRESETS="$ROOT_DIR/model-presets.ini"

usage() {
  cat <<'EOF'
Usage: scripts/audit-models.sh

Audits the model inventory across:
  - ./models directory (.gguf files, recursively)
  - ./models.txt download manifest
  - ./model-presets.ini preset model entries

Output columns:
  name | in ./models | in ./models.txt | in ./model-presets.ini
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

# Keep newline-delimited sets instead of associative arrays so this script works
# with macOS' default Bash 3.2.
in_models_dir=''
in_manifest=''
in_presets=''
all_models=''

add_model() {
  local name="$1"
  [[ -z "$name" ]] && return
  all_models="${all_models}${name}"$'\n'
}

contains_model() {
  local list="$1"
  local name="$2"
  printf '%s' "$list" | grep -Fxq -- "$name"
}

# Local inventory: recursively list downloaded GGUF files under ./models.
if [[ -d "$MODELS_DIR" ]]; then
  while IFS= read -r model_path; do
    name="${model_path##*/}"
    in_models_dir="${in_models_dir}${name}"$'\n'
    add_model "$name"
  done < <(find "$MODELS_DIR" -type f -name '*.gguf' 2>/dev/null | sort)
fi

# Manifest inventory: extract destination filenames from one URL per line.
if [[ -f "$MANIFEST" ]]; then
  while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip comments and blank lines.
    [[ "$line" =~ ^[[:space:]]*[#\;] ]] && continue
    [[ -z "${line//[[:space:]]/}" ]] && continue

    # Keep the first whitespace-delimited token as the URL, then strip query params.
    url="${line%%[[:space:]]*}"
    name="${url##*/}"
    name="${name%%\?*}"

    [[ "$name" == *.gguf ]] || continue
    in_manifest="${in_manifest}${name}"$'\n'
    add_model "$name"
  done < "$MANIFEST"
fi

# Preset inventory: extract basenames from active model = ... lines.
if [[ -f "$PRESETS" ]]; then
  while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip comments and blank lines.
    [[ "$line" =~ ^[[:space:]]*[#\;] ]] && continue
    [[ -z "${line//[[:space:]]/}" ]] && continue

    if [[ "$line" =~ ^[[:space:]]*model[[:space:]]*=[[:space:]]*(.+)$ ]]; then
      model_path="${BASH_REMATCH[1]}"
      # Remove inline comments if the model path is followed by whitespace + ;/#.
      model_path="${model_path%%[[:space:]]\;*}"
      model_path="${model_path%%[[:space:]]#*}"
      name="${model_path##*/}"

      [[ "$name" == *.gguf ]] || continue
      in_presets="${in_presets}${name}"$'\n'
      add_model "$name"
    fi
  done < "$PRESETS"
fi

yes_no() {
  local set_name="$1"
  local name="$2"

  case "$set_name" in
    models) contains_model "$in_models_dir" "$name" ;;
    manifest) contains_model "$in_manifest" "$name" ;;
    presets) contains_model "$in_presets" "$name" ;;
    *) return 1 ;;
  esac
}

NAME_WIDTH=58
MODELS_WIDTH=11
MANIFEST_WIDTH=15
PRESETS_WIDTH=22

repeat_char() {
  local char="$1"
  local count="$2"
  local output=''

  printf -v output '%*s' "$count" ''
  printf '%s' "${output// /$char}"
}

print_border() {
  local left="$1"
  local junction="$2"
  local right="$3"

  printf '%s%s%s%s%s%s%s%s%s\n' \
    "$left" "$(repeat_char '─' "$((NAME_WIDTH + 2))")" \
    "$junction" "$(repeat_char '─' "$((MODELS_WIDTH + 2))")" \
    "$junction" "$(repeat_char '─' "$((MANIFEST_WIDTH + 2))")" \
    "$junction" "$(repeat_char '─' "$((PRESETS_WIDTH + 2))")" \
    "$right"
}

print_row() {
  printf "│ %-*s │ %-*s │ %-*s │ %-*s │\n" \
    "$NAME_WIDTH" "$1" \
    "$MODELS_WIDTH" "$2" \
    "$MANIFEST_WIDTH" "$3" \
    "$PRESETS_WIDTH" "$4"
}

print_border '┌' '┬' '┐'
print_row 'name' 'in ./models' 'in ./models.txt' 'in ./model-presets.ini'
print_border '├' '┼' '┤'

if [[ -z "$all_models" ]]; then
  print_row 'No models found in ./models, ./models.txt, or ./model-presets.ini.' '' '' ''
  print_border '└' '┴' '┘'
  exit 0
fi

while IFS= read -r name; do
  models_value='no'
  manifest_value='no'
  presets_value='no'

  if yes_no models "$name"; then models_value='yes'; fi
  if yes_no manifest "$name"; then manifest_value='yes'; fi
  if yes_no presets "$name"; then presets_value='yes'; fi

  print_row "$name" "$models_value" "$manifest_value" "$presets_value"
done < <(printf '%s' "$all_models" | sort -u)

print_border '└' '┴' '┘'
