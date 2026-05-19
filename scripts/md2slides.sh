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
texfile="${input%.*}.tex"

PANDOC_DATA_DIR="C:/Users/22972/AppData/Roaming/pandoc"

# Scan extra args for --defaults= override; use Madrid by default
DEFAULTS="beamer"
EXTRA=()
for arg in "$@"; do
  if [[ "$arg" == --defaults=* ]]; then
    DEFAULTS="${arg#*=}"
  else
    EXTRA+=("$arg")
  fi
done

cd "$(dirname "$input")"
BASE=$(basename "$input")

# ── Pre-flight checks ──────────────────────────────────────────────

# Check for raw LaTeX environments inside callout blocks
if grep -n '^> \[!.*\] *$' "$BASE" > /dev/null 2>&1; then
  # Extract line numbers of callout starts
  callout_lines=$(grep -n '^> \[!.*\] *$' "$BASE" | cut -d: -f1)
  for cl in $callout_lines; do
    # Search forward from callout line for \begin{...} within the same blockquote.
    # A blockquote ends with a blank line, a non-> line, or EOF.
    total=$(wc -l < "$BASE")
    block_end=$(tail -n +"$cl" "$BASE" \
      | awk '/^$/ || (!/^>/ && NR>1) {print NR-1; exit}')
    block_end=${block_end:-$((total - cl + 1))}
    end_line=$((cl + block_end - 1))
    if sed -n "${cl},${end_line}p" "$BASE" | grep -q '\\begin{'; then
      echo "⚠  WARNING: Raw LaTeX environment \\begin{...} inside callout block near line $cl"
      echo "   This may cause the callout marker [!type] to appear verbatim."
      echo "   Consider using \\centering instead, or remove the \\begin{center}...\\end{center} wrapper."
      echo ""
    fi
  done
fi

# Check for excessive \vspace per slide (prevents content overflow)
# Frame available height ≈ 13cm for Madrid 16:9 11pt; \vspace sum > 2.5cm is risky
awk '
  /^## / {
    if (slide != "" && total > threshold)
      printf "⚠  WARNING: Slide \"%s\" has %.1fcm total \\vspace (threshold: %.1fcm)\n", slide, total, threshold
    slide = $0; sub(/^## /, "", slide); total = 0
  }
  /\\vspace\{[0-9.]+cm\}/ {
    s = $0; sub(/.*\\vspace\{/, "", s); sub(/cm\}.*/, "", s); total += s + 0
  }
  END {
    if (slide != "" && total > threshold)
      printf "⚠  WARNING: Slide \"%s\" has %.1fcm total \\vspace (threshold: %.1fcm)\n", slide, total, threshold
  }
' threshold=2.5 "$BASE"

# ── Compilation: Markdown → LaTeX → PDF ─────────────────────────────

# Preprocess: escape ___ so Pandoc treats as literal underscores,
# then blanks.lua converts them to \underline{\hspace{3cm}}.
sed 's/___/\\\\_\\\\_\\\\_/g' "$BASE" \
  | pandoc -f markdown \
  -s \
  --resource-path=. \
  --defaults="$DEFAULTS" \
  --lua-filter="$PANDOC_DATA_DIR/filters/blanks.lua" \
  --lua-filter="$PANDOC_DATA_DIR/filters/callout2beamer.lua" \
  -o "$texfile" \
  "${EXTRA[@]}"

# Compile LaTeX to PDF with XeLaTeX (first pass — must succeed)
xelatex -interaction=nonstopmode "$texfile" > /dev/null || {
  echo "ERROR: xelatex compilation failed."
  echo "Check ${BASE%.*}.log for details."
  exit 1
}

# Second pass for TOC / cross-references (failure is non-fatal)
xelatex -interaction=nonstopmode "$texfile" > /dev/null 2>&1 || true

# Verify PDF was actually generated
if [ ! -f "${BASE%.*}.pdf" ]; then
  echo "ERROR: PDF was not generated."
  exit 1
fi

# ── Post-compilation checks ─────────────────────────────────────────

logfile="${BASE%.*}.log"
if [ -f "$logfile" ]; then
  if grep -q "Overfull \\\\vbox" "$logfile" 2>/dev/null; then
    echo "⚠  WARNING: Content overflow detected (Overfull \\vbox)."
    echo "   Some slides have content exceeding the frame height."
    echo "   Consider reducing \\vspace or splitting the slide."
    echo ""
    grep -n "Overfull \\\\vbox" "$logfile" | head -5
    echo ""
  fi
fi

# Check for undefined references or citations
if grep -q "LaTeX Warning:.*undefined" "$logfile" 2>/dev/null; then
  echo "⚠  WARNING: Undefined references detected."
  grep -n "LaTeX Warning:.*undefined" "$logfile" | head -3
  echo ""
fi

# Clean up auxiliary files (keep .pdf and .md only)
rm -f "${BASE%.*}".aux "${BASE%.*}".log "${BASE%.*}".out \
      "${BASE%.*}".nav "${BASE%.*}".snm "${BASE%.*}".toc \
      "${BASE%.*}".vrb "$texfile"

echo "Done: $output"
