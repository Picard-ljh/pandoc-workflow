#!/usr/bin/env bash
# pandoc-workflow installer — ElegantLaTeX + Beamer Markdown→PDF pipeline
# Run: bash install.sh
# Safe to re-run; will not overwrite existing custom files.

set -euo pipefail

echo "=== pandoc-workflow installer ==="

# --- Detect OS ---
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*) OS="windows";;
  Darwin*)              OS="macos";;
  Linux*)               OS="linux";;
  *) echo "Unknown OS: $(uname -s)"; exit 1;;
esac
echo "[*] OS: $OS"

# --- Find Pandoc user data directory ---
PANDOC_DIR=$(pandoc --version 2>/dev/null | awk '/^[Uu]ser [Dd]ata [Dd]irectory:/ { $1=""; $2=""; gsub(/^[[:space:]]+/, ""); print; exit }')
if [ -z "$PANDOC_DIR" ]; then
  echo "ERROR: pandoc not found. Install pandoc first: https://pandoc.org"
  exit 1
fi
echo "[*] Pandoc data dir: $PANDOC_DIR"

# --- Detect CJK fonts ---
CJK_MAIN=""
CJK_SANS=""
detect_fonts() {
  case "$OS" in
    windows)
      # Windows: SimSun + SimHei are built-in
      CJK_MAIN="SimSun"
      CJK_SANS="SimHei"
      ;;
    macos)
      # macOS: check if system fonts exist
      if fc-list 2>/dev/null | grep -qi "Songti SC"; then
        CJK_MAIN="Songti SC"
        CJK_SANS="Heiti SC"
      else
        CJK_MAIN=""
        CJK_SANS=""
      fi
      ;;
    linux)
      # Linux: try common CJK fonts
      if fc-list 2>/dev/null | grep -qi "Noto Serif CJK"; then
        CJK_MAIN="Noto Serif CJK SC"
        CJK_SANS="Noto Sans CJK SC"
      elif fc-list 2>/dev/null | grep -qi "SimSun"; then
        CJK_MAIN="SimSun"
        CJK_SANS="SimHei"
      else
        CJK_MAIN=""
        CJK_SANS=""
      fi
      ;;
  esac
}
detect_fonts
echo "[*] CJK main font: ${CJK_MAIN:-<auto via ctex>}"
echo "[*] CJK sans font: ${CJK_SANS:-<auto via ctex>}"

# --- Claude config dir ---
CLAUDE_DIR="${HOME}/.claude"
SCRIPTS_DIR="${CLAUDE_DIR}/scripts"

# --- Create directories ---
mkdir -p "${PANDOC_DIR}/defaults" "${PANDOC_DIR}/filters" "${SCRIPTS_DIR}"

# --- Helper: replace placeholder with actual path ---
apply_template() {
  local src="$1" dst="$2"
  sed -e "s|__PANDOC_DIR__|${PANDOC_DIR}|g" \
      -e "s|__CJK_MAIN__|${CJK_MAIN}|g" \
      -e "s|__CJK_SANS__|${CJK_SANS}|g" \
      "$src" > "$dst"
}

# --- Copy defaults (template substitution) ---
echo "[*] Installing Pandoc defaults..."
apply_template "pandoc/defaults/elegantnote.yaml"   "${PANDOC_DIR}/defaults/elegantnote.yaml"
apply_template "pandoc/defaults/beamer.yaml"         "${PANDOC_DIR}/defaults/beamer.yaml"
apply_template "pandoc/defaults/beamer-metropolis.yaml" "${PANDOC_DIR}/defaults/beamer-metropolis.yaml"
# These have no placeholders, copy directly
cp "pandoc/defaults/elegantnote-env.tex"  "${PANDOC_DIR}/defaults/elegantnote-env.tex"
cp "pandoc/defaults/beamer-color.tex"            "${PANDOC_DIR}/defaults/beamer-color.tex"
cp "pandoc/defaults/beamer-berlin.yaml"           "${PANDOC_DIR}/defaults/beamer-berlin.yaml"
cp "pandoc/defaults/beamer-exercise.yaml"         "${PANDOC_DIR}/defaults/beamer-exercise.yaml"
cp "pandoc/defaults/beamer-berlin-exercise.yaml"  "${PANDOC_DIR}/defaults/beamer-berlin-exercise.yaml"
cp "pandoc/defaults/beamer-metropolis-exercise.yaml" "${PANDOC_DIR}/defaults/beamer-metropolis-exercise.yaml"
cp "pandoc/defaults/beamer-exercise-style.tex"   "${PANDOC_DIR}/defaults/beamer-exercise-style.tex"

# --- Copy filters ---
echo "[*] Installing Lua filters..."
cp "pandoc/filters/callout2latex.lua"  "${PANDOC_DIR}/filters/callout2latex.lua"
cp "pandoc/filters/callout2beamer.lua" "${PANDOC_DIR}/filters/callout2beamer.lua"

# --- Copy scripts ---
echo "[*] Installing scripts..."
apply_template "scripts/md2pdf.sh"   "${SCRIPTS_DIR}/md2pdf.sh"
apply_template "scripts/md2slides.sh" "${SCRIPTS_DIR}/md2slides.sh"
chmod +x "${SCRIPTS_DIR}/md2pdf.sh" "${SCRIPTS_DIR}/md2slides.sh"

# --- Print CLAUDE.md snippet ---
CLAUDE_SNIPPET=$(cat <<'SNIPPET'
### Markdown → PDF / PPT

当用户要求 Markdown 转 PDF 或做学术答辩 PPT 时：

- **文章 PDF**：`bash ~/.claude/scripts/md2pdf.sh <file.md>`
  排版引擎：ElegantNote + XeLaTeX，pad 尺寸，中文支持，内置 callout2latex
- **幻灯片 PDF**：`bash ~/.claude/scripts/md2slides.sh <file.md> [--defaults=beamer-berlin|beamer-metropolis]`
  排版引擎：Beamer + XeLaTeX，16:9，whale 标准配色。默认 Madrid，可选 Berlin/metropolis
  生成 PPT 前**必须询问用户**选用哪种主题
- **习题课 / 纯题目展示**：`bash ~/.claude/scripts/md2slides.sh <file.md> --defaults=beamer-exercise`
  排版引擎：Beamer + Madrid，8pt 小字 + 无标题栏 + 左上角紧贴。可选 beamer-berlin-exercise 或 beamer-metropolis-exercise
SNIPPET
)

echo ""
echo "=== Install complete ==="
echo ""
echo "Add the following to ~/.claude/CLAUDE.md so Claude knows about this workflow:"
echo "---"
echo "$CLAUDE_SNIPPET"
echo "---"
echo ""
echo "Then run:  bash ~/.claude/scripts/md2pdf.sh your-file.md"
echo "       or:  bash ~/.claude/scripts/md2slides.sh your-talk.md"
