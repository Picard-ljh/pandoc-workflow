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

# --- Copy scripts ---
echo "[*] Installing scripts..."
apply_template "scripts/md2pdf.sh"   "${SCRIPTS_DIR}/md2pdf.sh"
apply_template "scripts/md2slides.sh" "${SCRIPTS_DIR}/md2slides.sh"
chmod +x "${SCRIPTS_DIR}/md2pdf.sh" "${SCRIPTS_DIR}/md2slides.sh"

# --- Print CLAUDE.md snippet ---
CLAUDE_SNIPPET=$(cat <<'SNIPPET'
## PPT 制作

当用户要求做 PPT 时，使用脚本：

```bash
bash ~/.claude/scripts/md2slides.sh "<Markdown文件路径>" [额外 pandoc 参数]
```

排版引擎：Beamer + XeLaTeX，16:9 横屏，whale 标准配色。中文：SimSun + SimHei。

**三种场景与对应命令**：

| 场景 | 额外参数 | 说明 |
|------|---------|------|
| 学术答辩 / 日常汇报 / 教学课件 | `--defaults=beamer-{theme}` | 标准 Beamer，正常字号 |
| 习题课 / 纯题目展示 | `--defaults=beamer-{theme}-exercise` | 8pt 小字，无标题栏，紧凑排版 |

**三种主题**（生成前**必须询问用户**选择，默认 Madrid）：

| 主题 | `{theme}` 值 | 风格 |
|------|-------------|------|
| Madrid（默认） | `beamer` 或 `beamer-exercise` | 顶部导航条 + 底部信息栏，经典学术风 |
| Berlin | `beamer-berlin` 或 `beamer-berlin-exercise` | 顶部横条 + 底部页脚 |
| metropolis 极简 | `beamer-metropolis` 或 `beamer-metropolis-exercise` | 无横条，仅细线分隔 |

**习题课写作规范**：`#` 后仅写题号/简短标签（如 `# 题1`），题干内容另起一行放在 `#` 下方。注意：`#` 行在习题模式下不渲染（无标题栏），仅用于内部 slide 分页。

## Markdown 转 PDF

当用户要求将 Markdown 转为 PDF 时：

```bash
bash ~/.claude/scripts/md2pdf.sh "<Markdown文件路径>" [额外 pandoc 参数]
```

- 输出 PDF 与源文件同目录、同名、`.pdf` 后缀
- 排版引擎：ElegantNote（ElegantLaTeX），蓝黑配色、pad 尺寸（6×8in）、11pt
- 支持中文：ctex + XeLaTeX
- 内置 callout2latex 过滤器：`> [!note]` 等提示框自动转为 LaTeX 环境
- 常用额外参数：`--top-level-division=chapter`（# 标题映射为 chapter）
- 若需 A4 纸张，追加 `--metadata=classoption:"[cn,11pt,normal]"`
- 若需 end-to-end 调试，可先输出 .tex：`pandoc xxx.md --defaults=elegantnote --lua-filter=callout2latex -t latex -o xxx.tex`
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
