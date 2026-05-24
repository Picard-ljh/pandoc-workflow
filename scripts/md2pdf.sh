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
texfile="${input%.*}.tex"
PANDOC_DATA_DIR="__PANDOC_DIR__"

# Compile Markdown → LaTeX
pandoc "$input" \
  --defaults=elegantnote \
  --lua-filter="$PANDOC_DATA_DIR/filters/blanks.lua" \
  --lua-filter="$PANDOC_DATA_DIR/filters/callout2latex.lua" \
  -o "$texfile" \
  "$@"

# First XeLaTeX pass
xelatex -interaction=nonstopmode "$texfile" > /dev/null || {
  echo "ERROR: xelatex compilation failed."
  echo "Check ${input%.*}.log for details."
  exit 1
}

# Second pass for TOC / cross-references
xelatex -interaction=nonstopmode "$texfile" > /dev/null || true

# Verify PDF was generated
if [ ! -f "$output" ]; then
  echo "ERROR: PDF was not generated."
  exit 1
fi

# Post-compilation checks
logfile="${input%.*}.log"
if [ -f "$logfile" ]; then
  if grep -q "LaTeX Warning:.*undefined" "$logfile" 2>/dev/null; then
    echo "⚠  WARNING: Undefined references detected."
    grep -n "LaTeX Warning:.*undefined" "$logfile" | head -3
    echo ""
  fi
fi

# Clean up
rm -f "$texfile" "${input%.*}".aux "${input%.*}".log "${input%.*}".out

echo "Done: $output"
