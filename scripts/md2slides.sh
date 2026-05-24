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

PANDOC_DATA_DIR="__PANDOC_DIR__"

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
if grep -nE '^> \[!\w+\]' "$BASE" > /dev/null 2>&1; then
  # Extract line numbers of callout starts (with or without inline title)
  callout_lines=$(grep -nE '^> \[!\w+\]' "$BASE" | cut -d: -f1)
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
  {
    line = $0
    while (match(line, /\\vspace\{[0-9.]+cm\}/)) {
      m = substr(line, RSTART, RLENGTH)
      v = m; sub(/\\vspace\{/, "", v); sub(/cm\}/, "", v)
      total += v + 0
      line = substr(line, RSTART + RLENGTH)
    }
  }
  END {
    if (slide != "" && total > threshold)
      printf "⚠  WARNING: Slide \"%s\" has %.1fcm total \\vspace (threshold: %.1fcm)\n", slide, total, threshold
  }
' threshold=2.5 "$BASE"

# Check slide density (blocks, display formulas, text lines per slide)
# Warns on slides likely to overflow — based on empirical overflow data
awk '
  /^## / {
    if (slide != "" && (blocks > 2 || formulas >= 2 || lines >= 8))
      printf "⚠  WARNING: Slide \"%s\" may overflow — %d block(s) + %d formula(s) + %d line(s)\n", slide, blocks, formulas, lines
    slide = $0; sub(/^## /, "", slide); blocks = 0; formulas = 0; lines = 0
    next
  }
  /^### / { blocks++; lines++; next }
  /^::: \{/ { blocks++; lines++; next }
  /^\$\$/  { in_formula = !in_formula; if (in_formula) formulas++; next }
  /^[^#\s]/ { lines++ }
  END {
    if (slide != "" && (blocks > 2 || formulas >= 2 || lines >= 8))
      printf "⚠  WARNING: Slide \"%s\" may overflow — %d block(s) + %d formula(s) + %d line(s)\n", slide, blocks, formulas, lines
  }
' "$BASE"

# Check if cover page uses ## headers (slide-level:2 makes each a separate slide)
# Only scan first 5 ## lines; cover is always at top of file
cover_hits=$(grep -m 5 '^## ' "$BASE" | grep -cE '(答辩人|指导教|学号|姓名)' || true)
if [ "$cover_hits" -ge 2 ]; then
  echo "❌ FATAL: Cover page split detected — $cover_hits ## headers in first 5 slides"
  echo "   look like personal info. Each will become a separate blank slide."
  echo "   Solution: replace with YAML front matter:"
  echo ""
  echo "   ---"
  echo "   title: 论文题目"
  echo "   subtitle: 学校 · 学院"
  echo "   author: |"
  echo "     答辩人：XXX\\"
  echo "     指导教师：XXX"
  echo "   date: 2026 年 5 月"
  echo "   ---"
  echo ""
  exit 1
fi

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
xelatex -interaction=nonstopmode "$texfile" > /dev/null || true

# Verify PDF was actually generated
if [ ! -f "${BASE%.*}.pdf" ]; then
  echo "ERROR: PDF was not generated."
  exit 1
fi

# ── Post-compilation checks ─────────────────────────────────────────
# Note: vbox overflow check moved to verify-slides.py (with 2/15pt thresholds)

logfile="${BASE%.*}.log"
# Check for undefined references or citations
if [ -f "$logfile" ] && grep -q "LaTeX Warning:.*undefined" "$logfile" 2>/dev/null; then
  echo "⚠  WARNING: Undefined references detected."
  grep -n "LaTeX Warning:.*undefined" "$logfile" | head -3
  echo ""
fi

# Check .tex for common cover page mistakes (before cleanup deletes it)
if [ -f "$texfile" ]; then
  # Check 1: Cover split — consecutive \begin{frame}{...} with personal info as titles
  if grep -qE '\\begin\{frame\}\{(答辩人|指导教|姓名|学号|学院|日期|20[0-9]{2})' "$texfile" 2>/dev/null; then
    echo "⚠  WARNING: Cover page may be split into multiple slides."
    echo "   Detected \\begin{frame} with personal info as frame title."
    echo "   Solution: Use YAML front matter (title:/author:/date:) instead of ## headers."
    echo ""
  fi
  # Check 2: Escaped LaTeX — two patterns that indicate YAML field escaping
  YAML_ESCAPE=0
  if grep -q '\\textbackslash' "$texfile" 2>/dev/null; then
    YAML_ESCAPE=1
  fi
  if grep -qE '\{\[\}[0-9]' "$texfile" 2>/dev/null; then
    YAML_ESCAPE=1
  fi
  if [ "$YAML_ESCAPE" -eq 1 ]; then
    echo "⚠  WARNING: LaTeX commands appear escaped in YAML fields."
    echo "   This can cause raw text like [2pt] or {} to appear on the cover."
    echo "   Solution: Use YAML literal block (|) with \\ at end of line for line breaks."
    echo ""
  fi
fi

# Clean up auxiliary files (keep .pdf and .md only; .log kept for verify-slides.py)
rm -f "${BASE%.*}".aux "${BASE%.*}".out \
      "${BASE%.*}".nav "${BASE%.*}".snm "${BASE%.*}".toc \
      "${BASE%.*}".vrb "$texfile"

# ── Post-compilation verification ──────────────────────────────
VERIFY_SCRIPT="${HOME}/.claude/scripts/verify-slides.py"
if command -v python3 &> /dev/null && [ -f "$VERIFY_SCRIPT" ] && [ -f "$output" ]; then
  verify_result=0
  python3 "$VERIFY_SCRIPT" "$output" "$input" --defaults "$DEFAULTS" || verify_result=$?
  if [ $verify_result -eq 2 ]; then
    echo ""
    echo "❌ FATAL: Verification found critical issues. Fix before proceeding."
    exit 1
  fi
fi

echo "Done: $output"
