# pandoc-workflow —— Markdown 一键变文章 / 一键变 PPT

## 这是什么？

你写 Markdown（一种极简单的纯文本格式），跑一句命令，自动变成：

- **排版精美的文章 PDF**（适合写论文、笔记、博客）
- **专业的学术答辩 PPT**（适合毕业答辩、会议报告、教学课件）

整个过程全自动，不需要你懂 LaTeX、不需要你调排版、不需要你写代码。

---

## 你需要先装什么？

装这两样东西就行，都是免费的：

### 1. Pandoc

- 下载：https://pandoc.org/installing.html
- 选你的系统（Windows / macOS / Linux），下载安装包，一路下一步
- 装完后打开终端，输入 `pandoc --version`，看到版本号就说明 OK 了

### 2. TeX Live（完整版）

- 下载：https://tug.org/texlive/
- Windows 用户：下载 `install-tl-windows.exe`，一路默认安装
- macOS 用户：下载 `MacTeX.pkg`，一路默认安装
- Linux 用户：`sudo apt install texlive-full` 或等价的包管理器命令
- **注意**：安装包很大（约 4GB），下载和安装需要一段时间，建议连着 Wi-Fi 放在后台等
- 装完后打开终端，输入 `xelatex --version`，看到版本号就说明 OK 了

**只要你装过这两样，并且终端里输入命令有反应，就可以继续了。**

---

## 怎么安装这个工作流？

### 方法一：让 Claude Code 帮你装（最简单）

打开 Claude Code，把仓库链接发给他，说：

> "帮我安装 https://github.com/Picard-ljh/pandoc-workflow"

Claude Code 会自动：
1. 克隆仓库
2. 跑安装脚本
3. 检测你的操作系统和中文字体
4. 把所有配置放到正确的位置
5. 告诉你接下来怎么用

你只用看着就行，不需要碰任何代码。

### 方法二：自己手动装

```bash
# 1. 克隆仓库
git clone https://github.com/Picard-ljh/pandoc-workflow.git
cd pandoc-workflow

# 2. 运行安装脚本
bash install.sh
```

安装脚本会：
- **自动检测**你的操作系统（Windows / macOS / Linux）
- **自动找到** Pandoc 的用户数据目录
- **自动发现**你电脑上的中文字体
- **安装**所有配置文件和脚本到全局位置
- **打印**一段文字，让你复制粘贴到 CLAUDE.md

最后一步：打开 `~/.claude/CLAUDE.md`（在你的用户目录下），把安装脚本打印的那段话粘贴进去。这样 Claude Code 才知道这个工作流的存在。

---

## 怎么用？

### 写一篇文章，转成 PDF

1. 随便在哪写一个 Markdown 文件，比如 `我的文章.md`：

```markdown
---
title: 我的第一篇文章
author: 我的名字
---

# 第一章

这是正文内容，包含**粗体**和*斜体*。

## 数学公式

行内公式 $E=mc^2$，块级公式：

$$
\int_0^\infty e^{-x^2} dx = \frac{\sqrt{\pi}}{2}
$$

## 表格

| 名称 | 数量 |
|------|------|
| 苹果 | 10   |
| 香蕉 | 5    |

## 提示框

> [!note] 笔记
> 这是一条笔记。

> [!warning] 警告
> 这是一条警告信息。
```

2. 打开终端，cd 到文件所在目录，跑：

```bash
bash ~/.claude/scripts/md2pdf.sh 我的文章.md
```

3. 同目录下出现 `我的文章.pdf`，打开看效果。

一行命令，文章就排版好了。

---

### 做一份学术答辩 PPT

1. 写一个 Markdown 文件，每个 `##` 标题就是一帧幻灯片（`#` 是章节导航，不产生页面）：

```markdown
---
title: 我的答辩题目
subtitle: 本科毕业论文答辩
author: 我的名字
date: 2026年5月
---

## 研究背景

- 背景要点一
- 背景要点二
- 背景要点三

> [!note] 行业现状
> 补充说明信息。

## 主要贡献

1. 贡献一
2. 贡献二
3. 贡献三

> [!warning] 注意事项
> 这里有需要注意的约束条件。

## 总结

- 总结要点一
- 总结要点二
```

2. 跑命令：

```bash
bash ~/.claude/scripts/md2slides.sh 我的答辩.md
```

3. 同目录下出现 `我的答辩.pdf`，10 页 PPT 做好了。

---

### 三种幻灯片主题

本工作流内置三种 Beamer 主题，全部使用 whale 标准配色。Claude Code 会在做 PPT 前问你选哪个：

**Madrid（默认）**
- 顶部导航条 + 底部信息栏
- 页脚：页码 N/M（精简设计，封面信息不重复）
- 经典学术风，适合答辩和正式报告

**Berlin**
- 顶部横条 + 底部页脚（页码 N/M，与 Madrid 相同）
- 深蓝配色（自定义 navyblue #003366），章节导航突出
- 适合结构比较复杂的演讲

**metropolis 极简**
- 无横条，仅细线
- 仅页码，无信息栏
- 现代极简风，适合技术分享

切换方法：
```bash
# 默认 Madrid，不需要加任何参数
bash ~/.claude/scripts/md2slides.sh talk.md

# Berlin
bash ~/.claude/scripts/md2slides.sh talk.md --defaults=beamer-berlin

# metropolis 极简
bash ~/.claude/scripts/md2slides.sh talk.md --defaults=beamer-metropolis
```

> **配色说明**：Madrid 和 metropolis 使用各自内置的标准配色。Berlin 额外引用 `beamer-color.tex`（自定义深蓝 navyblue #003366），这是有意为之——Berlin 的深蓝顶条与 Madrid 的 whale 蓝属于不同色调。如果你希望所有主题视觉统一，将 `beamer-berlin.yaml` 中的 `beamer-color.tex` 引用删除即可还原为 whale 标准蓝。

### 习题课 / 纯题目展示

专用排版预设，8pt 小字 + 无标题栏 + 左上角紧贴 + 段距收紧，每页一道题留白充足：

```bash
# Madrid + 习题排版
bash ~/.claude/scripts/md2slides.sh problems.md --defaults=beamer-exercise

# Berlin + 习题排版
bash ~/.claude/scripts/md2slides.sh problems.md --defaults=beamer-berlin-exercise

# metropolis + 习题排版
bash ~/.claude/scripts/md2slides.sh problems.md --defaults=beamer-metropolis-exercise
```

> **写作规范**：习题课模式下，`#` 后只写题号（如 `# 题1`），题干内容另起一行放在 `#` 下方。因为该模式隐藏了标题栏，`#` 行内容不可见。

---

## 幻灯片写作约束

制作 Beamer 幻灯片时，请遵守以下规则以避免内容溢出和排版问题：

- **每页 block ≤ 2 个**：`### 标题` 或 `::: {.alertblock}` 算 1 个 block，超过 2 个极易挤到底部之外
- **每页正文 ≤ 14 行**：以 10.6pt 中文为基准，带公式的页要更少
- **公式独占行**：用 `$$...$$`，不要把长公式塞进正文段落
- **封面用 YAML front matter**：不要用 `##` 写封面信息
- **致谢页居中**：用 `\begin{center}...\end{center}` 包裹（`\centering` 对多段落无效）

编译后 `verify-slides.py` 会自动检查这些约束，不符合时会报 warning 或 fatal。

---

## 自动验证（verify-slides.py）

编译完成后，`md2slides.sh` 会自动运行 `verify-slides.py` 进行质量检查：

| 检查项 | 说明 | 级别 |
|--------|------|------|
| vbox overflow | 内容超出帧底边界 | >15pt FATAL / 2–15pt WARNING / <2pt 忽略 |
| block 覆盖率 | 每页 block 数量 | >2 个发出 WARNING |
| 图片溢出 | 图片超出页面边界 | FATAL |
| 内容溢出 | 文字超出底部边界 | >15pt FATAL / 2–15pt WARNING / <2pt 忽略 |

所有检查通过后才算编译成功。FATAL 级别的检查不通过会阻止输出，必须在 Markdown 中修复后重新编译。

---

## 提示框大全

你在 Markdown 里写在 `>` 后面的 `[!类型]`，会在 PDF 里变成对应的样式：

### 文章 PDF 里

| Markdown 写法 | PDF 显示 | Markdown 写法 | PDF 显示 |
|--------------|---------|--------------|---------|
| `> [!note]` | **注** | `> [!warning]` | **警告** |
| `> [!tip]` | **提示** | `> [!caution]` | **注意** |
| `> [!important]` | **重要** | `> [!example]` | **例** |
| `> [!info]` | **信息** | `> [!question]` | **问题** |
| `> [!danger]` | **危险** | `> [!success]` | **成功** |
| `> [!bug]` | **缺陷** | `> [!todo]` | **待办** |
| `> [!failure]` | **失败** | `> [!done]` | **完成** |
| `> [!hint]` | **提示** | `> [!faq]` | **常见问题** |

### 幻灯片 PPT 里

| Markdown 写法 | 幻灯片显示 | 颜色 |
|--------------|-----------|------|
| `> [!note]` | 蓝色标题块 | 深蓝标题 + 灰底 |
| `> [!warning]` | 红色警告块 | 深红标题 + 灰底 |
| `> [!tip]` | 绿色示例块 | 深绿标题 + 灰底 |
| `> [!important]` | 红色警告块 | 深红标题 + 灰底 |
| `> [!example]` | 绿色示例块 | 深绿标题 + 灰底 |
| `> [!danger]` | 红色警告块 | 深红标题 + 灰底 |
| `> [!success]` | 绿色示例块 | 深绿标题 + 灰底 |
| 其他所有类型 | 蓝色块 | 深蓝标题 + 灰底 |

---

### 提示框的写法规则

```markdown
> [!类型] 标题写在这里
> 正文第一行
> 正文第二行
```

注意：
- `[!类型]` 后面**不要加空格**，直接写标题
- 每一行都以 `>` 开头
- 不同类型的提示框有不同颜色 / 标签

---

## 进阶用法

### 改纸张大小 / 字体大小

```bash
# A4 纸张
bash ~/.claude/scripts/md2pdf.sh article.md --metadata=classoption:"[cn,11pt,normal]"

# 更大字体
bash ~/.claude/scripts/md2pdf.sh article.md --metadata=classoption:"[cn,14pt,pad]"
```

### 换颜色主题（仅文章线）

```bash
bash ~/.claude/scripts/md2pdf.sh article.md --metadata=classoption:"[cn,11pt,pad,green]"
```

可选颜色：`blue`（默认）、`green`、`cyan`、`sakura`、`black`、`brown`

### 想看中间产物

```bash
# 生成 .tex 中间文件（调试用）
pandoc article.md --defaults=elegantnote --lua-filter=callout2latex --lua-filter=blanks -s -t latex -o article.tex
```

---

## 整体原理

```
你的 Markdown 文件 (.md)
        │
        ▼
    Pandoc 读取
    ├── 标题（#） → 章节标题 / 新帧
    ├── 正文       → 段落
    ├── $$公式$$   → 数学排版
    ├── 表格       → 三线表
    └── > [!类型]  → 交给 Lua 过滤器转换
        │
        ▼
    Lua 过滤器
    ├── callout2latex.lua（文章线） + blanks.lua（填空横线）
    │   把 [!type] 变成 \begin{note}...\end{note}，___ 变成下划线
    ├── callout2beamer.lua（幻灯片线） + blanks.lua
    │   把 [!type] 变成 \begin{block}...\end{block}，___ 变成下划线
    └── exercise-block.lua（习题课模式）
        把 # 分页之间的内容自动包裹在 \begin{block}{}...\end{block} 中
        │
        ▼
    LaTeX 排版引擎
    ├── ElegantNote（文章）—— 处理字体、行距、颜色
    └── Beamer（幻灯片）—— 处理帧、块、页脚
        │
        ▼
    XeLaTeX 编译
    ├── 计算每个字符的精确位置
    ├── 自动断行、分页
    └── 输出 PDF
```

**核心思想**：你只用写内容（Markdown），排版交给机器（LaTeX）。Markdown 是人话，LaTeX 是排版界的黄金标准（Knuth 教授花了十年写的算法），这条流水线把两者连起来了。

---

## 典型用法

### 场景 1：你有论文 PDF，要做答辩 PPT

> "帮我把桌面的论文.pdf 做成答辩 PPT"

Claude Code 会：读论文 → 提取内容 → 询问你用 Madrid/Berlin/metropolis → 写 Markdown → 编译

### 场景 2：你有一堆题目，要做成习题课 PPT

> "把题.txt 做成习题课 PPT，Madrid 主题"

Claude Code 会：解析题目 → 每页一道题 → `--defaults=beamer-exercise` → 出 PDF

### 场景 3：你想写博客，顺便出个 PDF 版

> "帮我写一篇关于 XXX 的文章，转成 PDF"

Claude Code 会：写 Markdown → `md2pdf.sh` → 出 PDF

### 场景 4：重新编译已有的 Markdown

> "答辩PPT.md 重新编译一下"

Claude Code 会：跑 `md2slides.sh` → 出 PDF

---

## 常见问题

### Q: 装完跑命令报 "pandoc: command not found"

**A:** Pandoc 没装或者没加到系统路径。去 https://pandoc.org 下载重装，安装时勾选"添加到 PATH"。

### Q: 跑命令报 "xelatex: command not found"

**A:** TeX Live 没装。参考上面"你需要先装什么"部分。装完后要**重启终端**。

### Q: 中文变成方块或乱码

**A:** 中文系统字体没被找到。确认 TeX Live 是完整版（不是基础版）。如果还不行，在终端分别输入 `fc-list :lang=zh` 看看有没有中文字体。

### Q: 提示框全部报错

**A:** 安装脚本没跑成功。重新执行 `bash install.sh`，确认看到 "Install complete"。

### Q: 我想用其他 Beamer 主题

**A:** 在命令后面加 `--metadata=theme:"主题名"`。Beamer 内置主题有：Berlin, Madrid, Copenhagen, Warsaw, Singapore 等。试试看哪个你喜欢。

---

## 文件结构

```
pandoc-workflow/
├── README.md                          ← 你正在看的这份文档
├── install.sh                         ← 一键安装脚本
├── .gitignore
├── pandoc/
│   ├── defaults/
│   │   ├── elegantnote.yaml           ← 文章线默认参数
│   │   ├── elegantnote-env.tex        ← 文章线提示框环境定义（16 种）
│   │   ├── beamer.yaml                ← 幻灯片线默认参数（Madrid + whale）
│   │   ├── beamer-berlin.yaml         ← Berlin + whale
│   │   ├── beamer-metropolis.yaml     ← metropolis + metropolis
│   │   ├── beamer-exercise.yaml       ← Madrid + 习题排版
│   │   ├── beamer-berlin-exercise.yaml ← Berlin + 习题排版
│   │   ├── beamer-metropolis-exercise.yaml ← metropolis + 习题排版
│   │   ├── beamer-color.tex           ← Berlin 自定义深蓝配色
│   │   ├── beamer-exercise-style.tex  ← 习题排版样式（小字 + 紧贴）
│   │   └── beamer-footline.tex        ← Madrid + Berlin 精简页脚（N/M 页码）
│   └── filters/
│       ├── callout2latex.lua          ← 文章线提示框转换
│       ├── callout2beamer.lua         ← 幻灯片线提示框转换
│       ├── exercise-block.lua         ← 习题课自动包裹 block
│       └── blanks.lua                 ← 填空横线转换（___ → 下划线）
└── scripts/
    ├── md2pdf.sh                      ← 一键出文章 PDF
    ├── md2slides.sh                   ← 一键出幻灯片 PDF
    └── verify-slides.py               ← 编译后质量检查
├── rules/
│   ├── beamer-guide.md                ← Beamer 写作参考
│   └── mineru-reference.md            ← MinerU 文档解析参考
```

---

## 安全说明

- 本项目**不涉及任何 API Key**，不调用任何网络服务
- 全部使用本地工具（Pandoc、XeLaTeX）
- 不会泄露你的任何信息
- 代码 100% 开源，MIT 许可证
