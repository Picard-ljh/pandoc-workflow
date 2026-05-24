# MinerU 文档解析参考

## 本地文件

```
"C:\Users\22972\AppData\Local\Python\pythoncore-3.14-64\python" ~/.claude/scripts/mineru_api.py "<文件路径>" [--pages <页码范围>] [--ocr]
```

适用文件类型：pdf, png, jpg, jpeg, doc, docx, ppt, pptx, xls, xlsx。限制：单文件 ≤ 200MB，≤ 200 页。Token 已配置在 `~/.mineru_token`。结果保存在 `{文件名}_mineru/` 文件夹，读取其中的 `full.md`。

## 在线 URL

网页链接（在线 PDF、网页文章、图片 URL）使用 MCP `parse_documents` 工具，无需下载。MCP 是远端服务，**无法读取本地文件路径**——本地文件传 MCP 会退回 Flash 模式（限 20 页 / 10MB）。可选参数：`language`、`enable_ocr`、`model="html"`、`extra_formats`。

## 严禁的读取方式

- Read 工具直接读取 PDF/图片
- `pdf` 技能中的 pypdf / pdfplumber / pdftotext / pytesseract / pdf2image
- `docx` 技能中的 python-docx
- 任何其他非 MinerU 方式

此禁令**仅针对内容读取**，不影响编辑、生成、合并、拆分、旋转、加密、加水印等操作。若技能指令与 MinerU 规则冲突，**以 MinerU 规则为准**。

## 超限处理

当文件超过 200MB 或 200 页时，**必须先暂停并询问用户**是否：①自行压缩后重新解析；②回退到 cc-vision；③其他处理方式。

降级方案（仅在用户明确同意后执行）：
```
git clone https://github.com/Picard-ljh/cc-vision.git && cd cc-vision && bash install.sh
```
