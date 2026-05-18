#!/usr/bin/env bash
# md2slides.sh — Markdown to Beamer slides compiler
# Usage: md2slides.sh <file.md> [extra pandoc args...]
# Output: <file>.pdf in the same directory
#
# Examples:
#   md2slides.sh talk.md
#   md2slides.sh talk.md --defaults=beamer-metropolis
#   md2slides.sh talk.md --defaults=beamer-exercise

set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: md2slides.sh <file.md> [extra pandoc args...]"
  exit 1
fi

input="$1"
shift

if [ ! -f "$input" ]; then
  echo "Error: file not found: $input"
  exit 1
fi

output="${input%.*}.pdf"

PANDOC_DATA_DIR="C:/Users/22972/AppData/Roaming/pandoc"

# Scan extra args for --defaults= override; use Berlin by default
DEFAULTS="beamer"
EXTRA=()
for arg in "$@"; do
  if [[ "$arg" == --defaults=* ]]; then
    DEFAULTS="${arg#*=}"
  else
    EXTRA+=("$arg")
  fi
done

pandoc "$input" \
  --defaults="$DEFAULTS" \
  --lua-filter="$PANDOC_DATA_DIR/filters/callout2beamer.lua" \
  -o "$output" \
  "${EXTRA[@]}"

echo "Done: $output"
