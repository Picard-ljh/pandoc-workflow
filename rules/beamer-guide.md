# Beamer / PPT 制作参考

## 编译命令

```bash
bash ~/.claude/scripts/md2slides.sh "<Markdown文件路径>" [额外 pandoc 参数]
```

排版引擎：Beamer + XeLaTeX，16:9 横屏，whale 标准配色。中文：SimSun + SimHei。

## 标题结构规范（`slide-level: 2` 已全局固化）

| 层级 | Markdown | Beamer 映射 | 是否产生 slide 页 | 职责 |
|------|----------|------------|-------------------|------|
| 1 | `# 章节名` | `\section{}` | ❌ 否 | 仅填充目录 + 顶部导航条 |
| 2 | `## 页标题` | `\begin{frame}{}` | ✅ 是 | 每页一个 slide |
| 3 | `### 框标题` | `\begin{block}{}` | 否（依附于 `##`） | Madrid 蓝色内容框（默认方案） |

- `##` 才产生页面，`#` 不会——**裸 `#` 下面无内容时，pandoc 只写一行 `\section{}`，不生成页面，不报错，直接跳过。** 有内容时 pandoc 可能自动补帧，但不可依赖。
- 目录页和致谢页同样需要用 `##`，只是不需要 `###`；致谢页内容需用 `\begin{center}...\end{center}` 包裹以居中显示（`\centering` 在 pandoc Markdown 中对多段落无效）
- Section 分隔页已全局禁用

### 彩色框补充语法

callout2beamer.lua 过滤器中，以下 fenced div 渲染为不同颜色的 Madrid 框，**按需使用**：

| 语法 | Madrid 颜色 | 用途 |
|------|-----------|------|
| `### 标题` | 蓝色 | 默认内容块 |
| `::: {.alertblock}` … `:::` | 红色 / 橙色 | 警告、关键结论 |
| `::: {.exampleblock}` … `:::` | 绿色 | 案例、示例 |

`:::` 块和 `###` 块一样计入密度控制和 block 覆盖率检查（verify-slides.py 同时识别两种语法）。

## 编译与主题

**三种场景**：

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

## 写作约束（防溢出 / 防渲染异常）

基于已满意的样例 PDF 总结的硬约束。**违反不会报错**，但 verify-slides.py 会发软警告，且很可能要返工。

- **每页 block ≤ 2**：`### 标题` 或 `::: {...}` 算 1 个 block。3 个以上极易把内容挤到底部之外。
- **每页正文 ≤ 14 行**：以 10.6pt 中文为基准。带公式行的页要更少。
- **字号不要动**：默认 11pt 已经过验证。不要写 `{\large …}`、`\Large`，不要在 YAML 改 fontsize。
- **公式独占行**：用 `$$ … $$`，不要把长公式塞进正文段落中段。
- **封面必须用 YAML front matter**：不要用 `##` 写封面（详见上文）。
- **目录页/致谢页不算 block 页**：可以没有 block。
- **图片单独成页或占满一行**：不要塞进 block 里。
- **图片必须用 raw LaTeX 写法**：禁止 `![](path)` 语法（pandoc 默认不加居中，也无尺寸控制，容易溢出）。统一用：
  ```latex
  \begin{center}
  \includegraphics[width=0.55\textwidth,height=0.30\textheight,keepaspectratio]{path}
  \end{center}
  ```
  三参数缺一不可：`width` + `height` 限定盒子，`keepaspectratio` 防变形。`\begin{center}` 前后留空行，确保图片在 frame 层级（不被吸入上一个 block）。

## 习题课

`#` 后仅写题号/简短标签（如 `# 题1`），题干内容另起一行放在 `#` 下方。`#` 行在习题模式下不渲染（无标题栏），仅用于内部 slide 分页。

## Markdown 转 PDF

```bash
bash ~/.claude/scripts/md2pdf.sh "<Markdown文件路径>" [额外 pandoc 参数]
```

- 输出 PDF 与源文件同目录、同名、`.pdf` 后缀
- 排版引擎：ElegantNote（ElegantLaTeX），蓝黑配色、pad 尺寸（6×8in）、11pt
- 支持中文：ctex + XeLaTeX，内置 callout2latex 过滤器
- 常用额外参数：`--top-level-division=chapter`（# 标题映射为 chapter）
- 若需 A4 纸张，追加 `--metadata=classoption:"[cn,11pt,normal]"`
- 若需调试，可先输出 .tex：`pandoc xxx.md --defaults=elegantnote --lua-filter=callout2latex -t latex -o xxx.tex`

## PDF 转 PPT

```bash
node C:\Users\22972\.claude\scripts\pdf2pptx.js "<PDF路径>" --output "<输出路径>"
```

- 需 Node.js 环境，默认 300 DPI（`--dpi` 可调）
- 生成的是图片型 PPT，每页为高清截图，不可编辑文字但版面 100% 还原
