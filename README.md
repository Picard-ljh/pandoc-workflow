# pandoc-workflow

Markdown → PDF 自动化排版工作流。一条命令出文章，一条命令出学术答辩 PPT。

## 前置条件

- [Pandoc](https://pandoc.org) ≥ 3.x
- [TeX Live](https://tug.org/texlive) 完整版（含 XeLaTeX、Beamer、ElegantNote、metropolis）

## 安装

把仓库链接发给 Claude Code，让它执行：

```bash
# Claude Code 会帮你跑下面这条：
bash install.sh
```

或者自己跑：

```bash
git clone https://github.com/<your-username>/pandoc-workflow.git
cd pandoc-workflow
bash install.sh
```

安装脚本会：
- 检测操作系统（Windows/macOS/Linux）
- 自动定位 Pandoc 用户数据目录
- 检测系统中文字体
- 安装全局默认配置、Lua 过滤器和脚本
- 打印 CLAUDE.md 片段，手动加到 `~/.claude/CLAUDE.md`

## 使用

```bash
# 文章 PDF（ElegantNote 排版）
bash ~/.claude/scripts/md2pdf.sh article.md

# 幻灯片 PDF（Beamer + Berlin 深蓝主题）
bash ~/.claude/scripts/md2slides.sh talk.md

# 幻灯片 PDF（metropolis 极简主题）
bash ~/.claude/scripts/md2slides.sh talk.md --defaults=beamer-metropolis
```

## Markdown 提示框

```markdown
> [!note] 笔记标题
> 笔记内容

> [!warning] 警告
> 警告内容

> [!tip] 小贴士
> 贴士内容
```

- 文章线：转为 LaTeX 定理环境（注/警告/提示等中文标签）
- 幻灯片线：转为 Beamer block/alertblock/exampleblock 着色块

## 文件结构

```
pandoc/defaults/     — Pandoc 默认参数（文章 + 幻灯片）
pandoc/filters/      — Lua 过滤器（提示框转换）
scripts/             — 一键编译脚本
```

## 不包含

- 不需要 Python
- 不涉及 API key
- 无网络依赖（全部本地工具）
