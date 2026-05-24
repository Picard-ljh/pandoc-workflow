#!/usr/bin/env python3
"""Verify Beamer slide PDFs for common issues: vbox overflow, block coverage,
image overflow, and content overflow.

Usage: python verify-slides.py <pdf_path> [md_path]

Exit codes:
  0 — all checks passed
  1 — warnings found (review needed, but not blocking)
  2 — fatal issues found (must fix before proceeding)
"""

import argparse
import io
import re
import sys
from pathlib import Path

# Force UTF-8 output on Windows
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

# ── helpers ──────────────────────────────────────────────────────────

def red(text):
    return f"\033[91m{text}\033[0m"


def yellow(text):
    return f"\033[93m{text}\033[0m"


def green(text):
    return f"\033[92m{text}\033[0m"


def bold(text):
    return f"\033[1m{text}\033[0m"


# ── check 1: vbox overflow from .log ─────────────────────────────────

def check_vbox(pdf_path: Path) -> tuple[int, int, list[str]]:
    """Returns (warnings, fatals, detail_lines).

    Note: md2slides.sh runs xelatex twice, but the second pass overwrites .log,
    so we read only the final (stable) pass — TOC refs are resolved, no spurious
    overflow warnings from the first pass.
    """
    log_path = pdf_path.with_suffix(".log")
    if not log_path.exists():
        return 0, 0, [f"{yellow('[WARN]')} No .log file found, skipping vbox check"]

    text = log_path.read_text(encoding="utf-8", errors="replace")
    warnings = 0
    fatals = 0
    lines = []

    for match in re.finditer(r"Overfull \\vbox \(([0-9.]+)pt too high\) detected at line (\d+)", text):
        pts = float(match.group(1))
        line_no = int(match.group(2))
        if pts > 15:
            fatals += 1
            lines.append(f"  {red('FATAL')} line {line_no}: {pts:.1f}pt overflow (>15pt)")
        elif pts >= 5:
            warnings += 1
            lines.append(f"  {yellow('WARN')} line {line_no}: {pts:.1f}pt overflow (5–15pt)")
        # <5pt silently ignored

    return warnings, fatals, lines


# ── check 2: block coverage ──────────────────────────────────────────

# Map pandoc --defaults names to detected beamer theme
DEFAULTS_TO_THEME = {
    "beamer": "madrid",
    "beamer-exercise": "madrid",
    "beamer-metropolis": "metropolis",
    "beamer-metropolis-exercise": "metropolis",
    "beamer-berlin": "berlin",
    "beamer-berlin-exercise": "berlin",
}


def check_blocks(md_path: Path) -> tuple[int, int, list[str]]:
    """Returns (warnings, fatals, detail_lines)."""
    if not md_path.exists():
        return 0, 0, [f"{yellow('[WARN]')} No .md file found, skipping block check"]

    text = md_path.read_text(encoding="utf-8", errors="replace")
    blocks = [line for line in text.split("\n") if re.match(r"^(### |::: \{)", line)]

    # Group lines per slide so we can classify each slide before counting.
    slide_groups: list[tuple[str, list[str]]] = []
    cur_title = None
    cur_lines: list[str] = []
    for line in text.split("\n"):
        if re.match(r"^## ", line):
            if cur_title is not None:
                slide_groups.append((cur_title, cur_lines))
            cur_title = line[3:].strip()
            cur_lines = []
        elif cur_title is not None:
            cur_lines.append(line)
    if cur_title is not None:
        slide_groups.append((cur_title, cur_lines))

    # Exclude from coverage denominator: TOC / 致谢 / image-only pages.
    # Image syntax: native ![](..) OR raw \includegraphics (per beamer-guide.md).
    def is_image_only(body: list[str]) -> bool:
        has_image = any(
            re.search(r"!\[.*?\]\(", l) or "\\includegraphics" in l
            for l in body
        )
        has_block = any(re.match(r"^(### |::: \{)", l) for l in body)
        return has_image and not has_block

    functional_slides = [
        t for t, body in slide_groups
        if "目录" not in t and "致谢" not in t and not is_image_only(body)
    ]

    if not functional_slides:
        return 0, 0, []

    ratio = len(blocks) / len(functional_slides) * 100
    lines = [f"  Blocks: {len(blocks)} (###+:::) / {len(functional_slides)} ## content slides = {ratio:.0f}%"]

    # Per-slide block count: warn if any slide has > 2 blocks (overflow risk)
    overloaded = []
    for title, body in slide_groups:
        if "目录" in title or "致谢" in title:
            continue
        count = sum(1 for l in body if re.match(r"^(### |::: \{)", l))
        if count > 2:
            overloaded.append((title, count))
    warnings = 0
    if overloaded:
        warnings = 1
        lines.append(f"  {yellow('WARN')} {len(overloaded)} slide(s) with >2 blocks (overflow risk):")
        for t, c in overloaded[:5]:
            lines.append(f"    - {c} blocks: {t[:60]}")

    if ratio < 70:
        return warnings + 1, 0, lines + [f"  {yellow('WARN')} Block coverage below 70%. Add ### blocks for Madrid theme."]
    else:
        return warnings, 0, lines


# ── check 3: image placement in markdown source ──────────────────────

def check_images(md_path: Path) -> tuple[int, int, list[str]]:
    """Returns (warnings, fatals, detail_lines). Validates image placement,
    sizing, and centering in the markdown source."""
    if not md_path.exists():
        return 0, 0, []

    content = md_path.read_text(encoding="utf-8", errors="replace")

    warnings = 0
    fatal = 0
    lines_out = []

    # Detect native markdown image syntax ![alt](path) — disallowed.
    # beamer-guide.md requires raw \includegraphics with width+height+keepaspectratio.
    # Skip lines inside HTML comments <!-- ... -->.
    native_img_re = re.compile(r"(?<!\\)!\[[^\]]*\]\([^)]+\)")
    in_html_comment = False
    for i, line in enumerate(content.split("\n")):
        if "<!--" in line:
            in_html_comment = True
        if in_html_comment:
            if "-->" in line:
                in_html_comment = False
            continue
        if native_img_re.search(line):
            warnings += 1
            lines_out.append(
                f"  {yellow('WARN')} Line {i+1}: native ![](path) image syntax — "
                f"replace with \\begin{{center}}\\includegraphics"
                f"[width=0.55\\textwidth,height=0.30\\textheight,keepaspectratio]"
                f"{{path}}\\end{{center}}"
            )

    # Find all \includegraphics lines and their context
    img_lines = []
    for i, line in enumerate(content.split("\n")):
        if "\\includegraphics" in line:
            img_lines.append((i, line))

    if not img_lines:
        if warnings == 0:
            return 0, 0, [f"  {green('[PASS]')} image placement: no images found"]
        return warnings, 0, lines_out

    # Build line index for context lookups
    all_lines = content.split("\n")

    for line_no, img_line in img_lines:
        # ── check 3a: image should be at frame level, not inside block ──
        # In pandoc, a blank line before \begin{center} or \includegraphics
        # signals a new block-level element, which closes the preceding ### block.
        # So: the line immediately before \begin{center} (or the image itself
        # if no center wrapper) must be blank, or the image must be right after ##.
        center_line = line_no
        for j in range(line_no - 1, max(0, line_no - 4), -1):
            if "\\begin{center}" in all_lines[j]:
                center_line = j
                break
        prev_line = all_lines[center_line - 1].strip() if center_line > 0 else ""
        is_first_after_heading = False
        if not prev_line:
            # Blank line before — but verify it's not just after ## (which also needs blank)
            pass
        else:
            # Check if this is the first element right after ##
            for j in range(center_line - 1, -1, -1):
                s = all_lines[j].strip()
                if s == "":
                    continue
                if s.startswith("## "):
                    is_first_after_heading = True
                break
        if prev_line and not is_first_after_heading:
            warnings += 1
            lines_out.append(
                f"  {yellow('WARN')} Line {line_no+1}: image not separated from content above — "
                f"add a blank line before \\begin{{center}} to place at frame level"
            )

        # ── check 3b: image must be inside \begin{center}...\end{center} ──
        has_center_start = False
        has_center_end = False
        for j in range(max(0, line_no - 2), min(len(all_lines), line_no + 1)):
            if "\\begin{center}" in all_lines[j]:
                has_center_start = True
        for j in range(line_no, min(len(all_lines), line_no + 3)):
            if "\\end{center}" in all_lines[j]:
                has_center_end = True
        if not (has_center_start and has_center_end):
            warnings += 1
            lines_out.append(
                f"  {yellow('WARN')} Line {line_no+1}: image not in "
                f"\\begin{{center}}...\\end{{center}} — wrap it for horizontal positioning"
            )

        # ── check 3c: image must have width, height, and keepaspectratio ──
        has_width = "width=" in img_line
        has_height = "height=" in img_line
        has_keep = "keepaspectratio" in img_line
        missing = []
        if not has_width:
            missing.append("width")
        if not has_height:
            missing.append("height")
        if not has_keep:
            missing.append("keepaspectratio")
        if missing:
            warnings += 1
            lines_out.append(
                f"  {yellow('WARN')} Line {line_no+1}: image missing {', '.join(missing)} — "
                f"use width=0.55\\textwidth,height=0.30\\textheight,keepaspectratio"
            )

    if warnings == 0 and fatal == 0:
        lines_out = [f"  {green('[PASS]')} image placement: {len(img_lines)} image(s), all OK"]
        for line_no, _ in img_lines:
            lines_out.append(f"    Line {line_no+1}: centered, sized, at frame level")

    return warnings, fatal, lines_out


# ── check 4+5: image and content overflow via PyMuPDF ─────────────────

def check_visual(pdf_path: Path, theme: str = "madrid") -> tuple[int, int, list[str]]:
    """Returns (warnings, fatals, detail_lines). Uses PyMuPDF for hard boundary checks."""
    try:
        import fitz  # type: ignore
    except ImportError:
        return (
            0, 0,
            [f"  {yellow('[WARN]')} PyMuPDF not available, skipping visual checks"],
        )

    doc = fitz.open(str(pdf_path))
    warnings = 0
    fatals = 0
    lines = []

    # Footer baseline: page number block sits at y≈247–253 on a 255pt-tall canvas.
    # FOOTER_RE filters the page-number text itself; margin only needs to clear
    # the footer band (~10pt). Larger margin = false positives on tight pages.
    FOOTER_MARGIN_BY_THEME = {
        "madrid": 10,
        "metropolis": 10,
        "berlin": 10,
    }
    FOOTER_MARGIN = FOOTER_MARGIN_BY_THEME.get(theme, 30)

    for i in range(doc.page_count):
        page = doc[i]
        page_bottom = page.rect.y1 - FOOTER_MARGIN

        # --- images ---
        for img in page.get_images():
            for rect in page.get_image_rects(img):
                if rect[3] > page_bottom:
                    fatals += 1
                    overflow = rect[3] - page_bottom
                    lines.append(
                        f"  {red('FATAL')} Page {i+1}: image extends {overflow:.0f}pt "
                        f"past bottom (bottom={page_bottom:.0f}pt, image={rect[3]:.0f}pt)"
                    )

        # --- text blocks ---
        blocks = page.get_text("blocks")
        # Patterns for Beamer footer elements (not real content overflow)
        FOOTER_RE = re.compile(
            r"^("
            r"\d+ / \d+"                # page numbers: "1 / 22"
            r"|"
            r"\w+ \d{1,2}, \d{4}"      # date: "May 23, 2026"
            r")$"
        )
        for b in blocks:
            if len(b) >= 4 and b[3] > page_bottom:
                text = b[4] if len(b) > 4 and isinstance(b[4], str) else ""
                text = text.strip()
                # Skip Beamer footer: block sits entirely in footer band (y>=240)
                # AND content is short (footer text is always brief — author/title/date/page)
                block_top = b[1] if len(b) > 1 else 0
                if block_top >= 240 and len(text) < 80:
                    continue
                # Also skip if every line in block matches a footer pattern
                lines_in_block = text.split("\n")
                if all(FOOTER_RE.match(l.strip()) or len(l.strip()) == 0 for l in lines_in_block):
                    continue
                fatals += 1
                overflow = b[3] - page_bottom
                text_preview = text[:60]
                lines.append(
                    f"  {red('FATAL')} Page {i+1}: content extends {overflow:.0f}pt "
                    f"past bottom: \"{text_preview}...\""
                )

    doc.close()
    return warnings, fatals, lines


# ── report ────────────────────────────────────────────────────────────

def write_report(pdf_path: Path, total_warnings: int, total_fatals: int,
                 vbox_info: str, block_info: str, image_info: str, visual_info: str):
    """Write a human-readable verification report next to the PDF."""
    from datetime import datetime

    report_path = pdf_path.with_name(pdf_path.stem + "_验证报告.txt")
    status = "FATAL" if total_fatals > 0 else ("WARN" if total_warnings > 0 else "PASS")

    lines = [
        f"验证报告 — {pdf_path.name}",
        f"时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
        f"结论: {status}",
        f"",
        f"vbox 溢出: {vbox_info}",
        f"block 覆盖: {block_info}",
        f"图片位置: {image_info}",
        f"内容越界: {visual_info}",
    ]
    report_path.write_text("\n".join(lines), encoding="utf-8")


# ── main ─────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Verify Beamer slide PDF")
    parser.add_argument("pdf", help="Path to PDF file")
    parser.add_argument("md", nargs="?", help="Path to source markdown (optional, inferred from pdf name)")
    parser.add_argument("--defaults", default="beamer", help="pandoc --defaults name (used to detect theme)")
    args = parser.parse_args()
    theme = DEFAULTS_TO_THEME.get(args.defaults, "madrid")

    pdf_path = Path(args.pdf).resolve()
    if not pdf_path.exists():
        print(f"{red('FATAL')}: PDF not found: {pdf_path}")
        sys.exit(2)

    if args.md:
        md_path = Path(args.md).resolve()
    else:
        md_path = pdf_path.with_suffix(".md")

    print(f"\n{bold('Verifying')} {pdf_path.name} ...\n")

    total_warnings = 0
    total_fatals = 0
    vbox_info = "skipped"
    block_info = "skipped"
    image_info = "skipped"
    visual_info = "skipped"

    # Check 1: vbox
    w, f, detail = check_vbox(pdf_path)
    total_warnings += w
    total_fatals += f
    if w == 0 and f == 0 and not any("No .log" in d for d in detail):
        print(f"  {green('[PASS]')} vbox overflow: 0")
        vbox_info = "0"
    else:
        for d in detail:
            print(d)
        vbox_info = f"{w}W/{f}F"
        print(f"  vbox overflow: {w} warning(s), {f} fatal(s)")

    # Check 2: blocks (Madrid-specific: other themes don't rely on ### → block style)
    if theme == "madrid":
        w, f, detail = check_blocks(md_path)
    else:
        w, f, detail = 0, 0, [f"  {green('[PASS]')} block coverage: skipped (theme={theme})"]
    total_warnings += w
    total_fatals += f
    if w == 0 and f == 0:
        print(f"  {green('[PASS]')} block coverage: OK")
        block_info = "OK"
    else:
        for d in detail:
            print(d)
        block_info = f"{w}W"

    # Check 3: image placement
    w, f, detail = check_images(md_path)
    total_warnings += w
    total_fatals += f
    if w == 0 and f == 0:
        print(f"  {green('[PASS]')} image placement: OK")
        image_info = "OK"
    else:
        for d in detail:
            print(d)
        image_info = f"{w}W"

    # Check 4+5: visual
    w, f, detail = check_visual(pdf_path, theme=theme)
    total_warnings += w
    total_fatals += f
    if w == 0 and f == 0 and not any("not available" in d for d in detail):
        print(f"  {green('[PASS]')} image/content bounds: 0 overflow")
        visual_info = "0"
    else:
        for d in detail:
            print(d)
        visual_info = f"{w}W/{f}F"

    # ── summary ───────────────────────────────────────────────────────
    print(f"\n{bold('─' * 48)}")

    if total_fatals > 0:
        print(f"  {bold(red(f'RESULT: {total_fatals} FATAL issue(s) — must fix before proceeding'))}")
        write_report(pdf_path, total_warnings, total_fatals,
                     vbox_info, block_info, image_info, visual_info)
        sys.exit(2)
    elif total_warnings > 0:
        print(f"  {bold(yellow(f'RESULT: {total_warnings} warning(s) — review before proceeding'))}")
        write_report(pdf_path, total_warnings, total_fatals,
                     vbox_info, block_info, image_info, visual_info)
        sys.exit(1)
    else:
        print(f"  {bold(green('RESULT: ALL CHECKS PASSED'))}")
        write_report(pdf_path, total_warnings, total_fatals,
                     vbox_info, block_info, image_info, visual_info)
        sys.exit(0)


if __name__ == "__main__":
    main()
