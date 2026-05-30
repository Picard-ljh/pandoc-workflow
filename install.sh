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

# --- Verify TeX Live / ElegantLaTeX is installed ---
if ! kpsewhich elegantnote.cls > /dev/null 2>&1; then
  echo "WARNING: ElegantNote not found. TeX Live (full) may not be installed."
  echo "  Install TeX Live: https://tug.org/texlive/"
  echo "  The article pipeline (md2pdf) requires it; the slides pipeline (md2slides) needs Beamer."
  echo "  Continue anyway? (y/N)"
  read -r yn
  case "$yn" in [Yy]*) ;; *) exit 1;; esac
else
  echo "[*] TeX Live with ElegantLaTeX detected"
fi

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
apply_template "pandoc/defaults/beamer-berlin.yaml"           "${PANDOC_DIR}/defaults/beamer-berlin.yaml"
apply_template "pandoc/defaults/beamer-exercise.yaml"         "${PANDOC_DIR}/defaults/beamer-exercise.yaml"
apply_template "pandoc/defaults/beamer-berlin-exercise.yaml"  "${PANDOC_DIR}/defaults/beamer-berlin-exercise.yaml"
apply_template "pandoc/defaults/beamer-metropolis-exercise.yaml" "${PANDOC_DIR}/defaults/beamer-metropolis-exercise.yaml"
cp "pandoc/defaults/beamer-exercise-style.tex"   "${PANDOC_DIR}/defaults/beamer-exercise-style.tex"
cp "pandoc/defaults/beamer-footline.tex"         "${PANDOC_DIR}/defaults/beamer-footline.tex"

# --- Copy filters ---
echo "[*] Installing Lua filters..."
cp "pandoc/filters/callout2latex.lua"  "${PANDOC_DIR}/filters/callout2latex.lua"
cp "pandoc/filters/callout2beamer.lua" "${PANDOC_DIR}/filters/callout2beamer.lua"
cp "pandoc/filters/blanks.lua"         "${PANDOC_DIR}/filters/blanks.lua"
cp "pandoc/filters/exercise-block.lua" "${PANDOC_DIR}/filters/exercise-block.lua"

# --- Copy scripts ---
echo "[*] Installing scripts..."
apply_template "scripts/md2pdf.sh"   "${SCRIPTS_DIR}/md2pdf.sh"
apply_template "scripts/md2slides.sh" "${SCRIPTS_DIR}/md2slides.sh"
chmod +x "${SCRIPTS_DIR}/md2pdf.sh" "${SCRIPTS_DIR}/md2slides.sh"

# --- Copy verify-slides.py (no template) ---
echo "[*] Installing verify-slides.py..."
cp "scripts/verify-slides.py" "${SCRIPTS_DIR}/verify-slides.py"
chmod +x "${SCRIPTS_DIR}/verify-slides.py"

# --- Check Python dependencies for verify-slides.py ---
if ! python3 -c "import fitz" 2>/dev/null; then
  echo ""
  echo "⚠  WARNING: pymupdf not found — verify-slides.py will not work."
  echo "   Install: pip install pymupdf"
  echo "   (verify-slides.py checks for vbox overflow, block coverage, etc.)"
fi

# --- Copy rules ---
echo "[*] Installing rules..."
mkdir -p "${CLAUDE_DIR}/rules"
cp rules/beamer-guide.md "${CLAUDE_DIR}/rules/beamer-guide.md"
cp rules/mineru-reference.md "${CLAUDE_DIR}/rules/mineru-reference.md"

# --- Print CLAUDE.md snippet ---
CLAUDE_SNIPPET=$(cat <<'SNIPPET'
## PPT 制作

```bash
bash ~/.claude/scripts/md2slides.sh "<Markdown文件路径>" [额外 pandoc 参数]
```

排版引擎：Beamer + XeLaTeX，16:9 横屏，whale 标准配色。

三种主题（生成前必须询问用户，默认 Madrid）：
- Madrid：`--defaults=beamer`
- Berlin：`--defaults=beamer-berlin`
- metropolis：`--defaults=beamer-metropolis`
- 习题课模式加 `-exercise` 后缀

编译后自动运行 verify-slides.py 质检，FATAL 会阻止输出。

> 标题结构、写作约束（block ≤ 2、公式、图片规范）、彩色框语法 → `~/.claude/rules/beamer-guide.md`

## Markdown 转 PDF

```bash
bash ~/.claude/scripts/md2pdf.sh "<Markdown文件路径>" [额外 pandoc 参数]
```

- 排版引擎：ElegantNote（ElegantLaTeX），蓝黑配色、pad 尺寸（6×8in）、11pt
- 支持中文：ctex + XeLaTeX，内置 callout2latex + blanks 过滤器
- 若需 A4：追加 `--metadata=classoption:"[cn,11pt,normal]"`
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
