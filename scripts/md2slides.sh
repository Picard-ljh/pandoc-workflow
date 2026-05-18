#!/usr/bin/env bash
# md2slides.sh — Markdown to Beamer slides via Pandoc
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: md2slides.sh <file.md> [extra pandoc args...]"
  exit 1
fi

input="$1"; shift

if [ ! -f "$input" ]; then
  echo "Error: file not found: $input"; exit 1
fi

output="${input%.*}.pdf"

pandoc "$input" \
  --defaults=beamer \
  --lua-filter="__PANDOC_DIR__/filters/callout2beamer.lua" \
  -o "$output" \
  "$@"

echo "Done: $output"
