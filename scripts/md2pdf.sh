#!/usr/bin/env bash
# md2pdf.sh — Markdown to PDF via ElegantNote + Pandoc
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: md2pdf.sh <file.md> [extra pandoc args...]"
  exit 1
fi

input="$1"; shift

if [ ! -f "$input" ]; then
  echo "Error: file not found: $input"; exit 1
fi

output="${input%.*}.pdf"

pandoc "$input" \
  --defaults=elegantnote \
  --lua-filter="__PANDOC_DIR__/filters/callout2latex.lua" \
  -o "$output" \
  "$@"

echo "Done: $output"
