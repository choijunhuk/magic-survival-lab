"""Build the editable manuscript and print-ready design PDF from page JSON."""

from __future__ import annotations

import html
import json
import re
from copy import deepcopy
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfgen.canvas import Canvas
from reportlab.platypus import Paragraph, Table, TableStyle


ROOT = Path(__file__).resolve().parents[2]
PARTS = ROOT / "docs/gdd/parts"
MANUSCRIPT = ROOT / "docs/gdd/FULL_DESIGN.md"
PDF = ROOT / "output/pdf/magic-survival-full-design.pdf"
METRICS = ROOT / ".omx/artifacts/gdd/layout-validation.json"
FONT = "/System/Library/Fonts/Supplemental/AppleGothic.ttf"
W, H = A4
INK = colors.HexColor("#172D3A")
TEAL = colors.HexColor("#247E79")
GOLD = colors.HexColor("#AE803D")
PAPER = colors.HexColor("#F9F7F1")
MUTED = colors.HexColor("#586C70")
RULE = colors.HexColor("#D6DED9")
MARGIN = 49
CONTENT_W = W - 2 * MARGIN
BOTTOM = 61

SOURCES = {
    "S1": ("Magic Survival · Google Play 공식 소개", "https://play.google.com/store/apps/details?id=com.vkslrzm.Zombie"),
    "S2": ("TomkoSK · Magic Survival Builder 고정 커밋", "https://github.com/TomkoSK/magic-survival-builder/tree/d58d53117e6bead22ee08f0ecac7bff9658ae922"),
    "S3": ("HTML 기준선 · magic-survival-lab 커밋 4ae06b1", "https://github.com/choijunhuk/magic-survival-lab/tree/4ae06b1"),
    "S4": ("초기 확장 설계안 · 저장소 원고", "https://github.com/choijunhuk/magic-survival-lab/blob/4ae06b1/docs/superpowers/specs/2026-10-29-expansion-design.md"),
    "S5": ("Godot · Android 내보내기 문서", "https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html"),
    "S6": ("Godot · iOS 내보내기 문서", "https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_ios.html"),
    "S7": ("Godot · 라이선스 문서", "https://godotengine.org/license/"),
}


def para(value: str, size: float, leading: float, color=INK, bold=False) -> Paragraph:
    return Paragraph(html.escape(str(value)).replace("\n", "<br/>"), ParagraphStyle(
        "text", fontName="KR", fontSize=size, leading=leading,
        textColor=color, alignment=TA_LEFT, wordWrap="CJK",
        allowWidows=0, allowOrphans=0,
    ))


def draw_para(c: Canvas, value: str, x: float, top: float, width: float,
              size: float, leading: float, color=INK) -> float:
    p = para(value, size, leading, color)
    _, height = p.wrap(width, 10000)
    p.drawOn(c, x, top - height)
    return height


def table_for(block: dict, scale: float) -> Table:
    columns = block["columns"]
    rows = block["rows"]
    count = len(columns)
    # The identifier column remains compact; the descriptive columns receive the width.
    if count == 5:
        widths = [49, 86, 43, 154, CONTENT_W - 332]
    elif count == 4:
        widths = [58, 116, 164, CONTENT_W - 338]
    elif count == 3:
        widths = [67, 161, CONTENT_W - 228]
    else:
        widths = [112, CONTENT_W - 112]
    if count == 3 and columns[0] == "쪽":
        widths = [52, 178, CONTENT_W - 230]
    font = 9.05 * scale
    lead = 12.9 * scale
    data = [[para(v, font, lead, colors.white) for v in columns]]
    data += [[para(v, font, lead) for v in row] for row in rows]
    t = Table(data, colWidths=widths, repeatRows=1, hAlign="LEFT")
    t.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), INK),
        ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.HexColor("#FFFFFF"), colors.HexColor("#F0F4F1")]),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING", (0, 0), (-1, -1), 6.2 * scale),
        ("RIGHTPADDING", (0, 0), (-1, -1), 5.5 * scale),
        ("TOPPADDING", (0, 0), (-1, -1), 5.2 * scale),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 5.4 * scale),
        ("LINEBELOW", (0, -1), (-1, -1), .45, RULE),
    ]))
    return t


def block_height(block: dict, scale: float) -> float:
    kind = block["kind"]
    if kind == "diagram":
        return 140 * scale
    heading = block.get("heading")
    base = (24 * scale if heading else 0) + 9 * scale
    if kind == "p":
        return base + para(block["text"], 10.6 * scale, 16.3 * scale).wrap(CONTENT_W, 10000)[1]
    if kind == "list":
        return base + sum(para("•  " + v, 10.2 * scale, 15.2 * scale).wrap(CONTENT_W - 8, 10000)[1] + 3 * scale for v in block["items"])
    if kind == "callout":
        return 17 * scale + para(block["text"], 9.9 * scale, 15.1 * scale).wrap(CONTENT_W - 28, 10000)[1] + 14 * scale
    if kind == "table":
        return base + table_for(block, scale).wrap(CONTENT_W, 10000)[1]
    raise ValueError(kind)


def page_background(c: Canvas, page: dict, number: int, total: int) -> None:
    c.setFillColor(PAPER)
    c.rect(0, 0, W, H, stroke=0, fill=1)
    c.setFillColor(TEAL)
    c.rect(0, H - 8, W, 8, stroke=0, fill=1)
    c.setStrokeColor(RULE)
    c.line(MARGIN, 47, W - MARGIN, 47)
    c.setFont("KR", 8.3)
    c.setFillColor(MUTED)
    c.drawString(MARGIN, 32, "MAGIC SURVIVAL LAB  /  GAME DESIGN DOCUMENT")
    c.drawRightString(W - MARGIN, 32, f"설계초안   {number:02d} / {total}")
    if number > 1:
        c.setFont("KR", 8.6)
        c.drawString(MARGIN, H - 30, page["chapter"])
        c.drawRightString(W - MARGIN, H - 30, page["id"].upper())
        c.setStrokeColor(RULE)
        c.line(MARGIN, H - 37, W - MARGIN, H - 37)


def draw_diagram(c: Canvas, block: dict, y: float, scale: float) -> float:
    nodes = block["nodes"]
    gap = 10
    boxw = (CONTENT_W - gap * 2) / 3
    boxh = 47 * scale
    for i, name in enumerate(nodes):
        row, col = divmod(i, 3)
        x = MARGIN + col * (boxw + gap)
        top = y - row * (boxh + 15 * scale)
        c.setFillColor(colors.HexColor("#E6F0EC") if i < 3 else colors.HexColor("#F4EBDC"))
        c.setStrokeColor(TEAL if i < 3 else GOLD)
        c.roundRect(x, top - boxh, boxw, boxh, 9, stroke=1, fill=1)
        c.setFillColor(TEAL if i < 3 else GOLD)
        c.setFont("KR", 8.8 * scale)
        c.drawString(x + 9, top - 16 * scale, f"0{i + 1}")
        c.setFillColor(INK)
        c.setFont("KR", 10.0 * scale)
        c.drawString(x + 9, top - 33 * scale, name)
        if col < 2:
            c.setStrokeColor(GOLD)
            c.line(x + boxw + 2, top - boxh / 2, x + boxw + gap - 2, top - boxh / 2)
    return y - 140 * scale


def draw_block(c: Canvas, block: dict, y: float, scale: float, toc_links: bool) -> float:
    kind = block["kind"]
    if kind == "diagram":
        return draw_diagram(c, block, y, scale)
    if kind != "callout":
        if heading := block.get("heading"):
            c.setFillColor(GOLD)
            c.rect(MARGIN, y - 14 * scale, 3, 14 * scale, stroke=0, fill=1)
            draw_para(c, heading, MARGIN + 11, y, CONTENT_W - 11, 11.7 * scale, 16 * scale, TEAL)
            y -= 24 * scale
        y -= 9 * scale
    if kind == "p":
        return y - draw_para(c, block["text"], MARGIN, y, CONTENT_W, 10.6 * scale, 16.3 * scale)
    if kind == "list":
        for item in block["items"]:
            y -= draw_para(c, "•  " + item, MARGIN + 8, y, CONTENT_W - 8, 10.2 * scale, 15.2 * scale) + 3 * scale
        return y
    if kind == "callout":
        h = block_height(block, scale)
        c.setFillColor(colors.HexColor("#E8F0EB"))
        c.roundRect(MARGIN, y - h + 6 * scale, CONTENT_W, h - 6 * scale, 8, stroke=0, fill=1)
        c.setFillColor(TEAL)
        c.rect(MARGIN, y - h + 6 * scale, 3, h - 6 * scale, stroke=0, fill=1)
        draw_para(c, block["text"], MARGIN + 14, y - 12 * scale, CONTENT_W - 28, 9.9 * scale, 15.1 * scale)
        return y - h
    if kind == "table":
        t = table_for(block, scale)
        _, h = t.wrap(CONTENT_W, 10000)
        t.drawOn(c, MARGIN, y - h)
        if toc_links:
            header = t._rowHeights[0]
            cursor = y - header
            for row, rh in zip(block["rows"], t._rowHeights[1:]):
                match = re.match(r"(\d+)", str(row[0]))
                if match:
                    c.linkRect("", f"p{int(match.group(1)):03d}", (MARGIN, cursor - rh, MARGIN + CONTENT_W, cursor), relative=0, thickness=0)
                cursor -= rh
        return y - h
    raise ValueError(kind)


def markdown(pages: list[dict]) -> str:
    lines = ["# 균열 연대기 — 전체 게임 설계서", "", "> 제작용 설계 초안 · 2026-10-29 · 현재 구현과 미래 제안을 구분한다.", ""]
    chapter = None
    for page in pages:
        if page["chapter"] != chapter:
            chapter = page["chapter"]
            lines += [f"## {chapter}", ""]
        lines += [f"### {page['id']} · {page['title']}", "", f"*{page['strap']}*", ""]
        for block in page["blocks"]:
            kind = block["kind"]
            if block.get("heading"):
                lines += [f"#### {block['heading']}", ""]
            if kind == "p":
                lines += [block["text"], ""]
            elif kind == "callout":
                lines += [f"> {block['text']}", ""]
            elif kind == "list":
                lines += [*(f"- {v}" for v in block["items"]), ""]
            elif kind == "table":
                lines += ["| " + " | ".join(block["columns"]) + " |", "| " + " | ".join("---" for _ in block["columns"]) + " |"]
                lines += ["| " + " | ".join(str(v).replace("|", "\\|") for v in row) + " |" for row in block["rows"]]
                lines += [""]
            elif kind == "diagram":
                lines += [" → ".join(block["nodes"]), ""]
        if page.get("sources"):
            lines += ["근거: " + ", ".join(f"[{s}](#근거-자료)" for s in page["sources"]), ""]
    lines += ["## 근거 자료", "", "외부 자료는 설계의 참고 자료이며, 제안 수치의 실측 증거가 아니다.", ""]
    for key, (label, url) in SOURCES.items():
        lines += [f"- **{key}** {label}: {url}"]
    lines += [""]
    return "\n".join(lines)


def main() -> None:
    pdfmetrics.registerFont(TTFont("KR", FONT))
    pages = [p for path in sorted(PARTS.glob("*.json")) for p in json.loads(path.read_text())["pages"]]
    expected = [f"p{i:03d}" for i in range(1, 89)]
    assert [p["id"] for p in pages] == expected, "Logical pages must be p001-p088 in order"
    MANUSCRIPT.write_text(markdown(pages), encoding="utf-8")
    rendered = []
    for page in pages:
        top = H - (225 if page["id"] == "p001" else 115)
        available = top - BOTTOM - 28
        table_index = next((i for i, b in enumerate(page["blocks"]) if b["kind"] == "table" and len(b["rows"]) >= 12), None)
        if page["id"] == "p031":
            first, second = deepcopy(page), deepcopy(page)
            first["blocks"] = page["blocks"][:3]
            second["id"] += "-cont"
            second["title"] += " · 이어서"
            second["strap"] = "출시 공명 분기와 변형 경계"
            second["blocks"] = page["blocks"][3:]
            rendered.extend((first, second))
        elif table_index is not None and sum(block_height(b, .94) for b in page["blocks"]) > available:
            first, second = deepcopy(page), deepcopy(page)
            catalog = page["blocks"][table_index]
            midpoint = len(catalog["rows"]) // 2 + (page["id"] == "p061")
            first["blocks"] = [*page["blocks"][:table_index], {**catalog, "rows": catalog["rows"][:midpoint]}]
            second["id"] += "-cont"
            second["title"] += " · 이어서"
            second["strap"] = "앞쪽의 목록과 이어지는 설계 조건"
            second["blocks"] = [{**catalog, "rows": catalog["rows"][midpoint:]}, *page["blocks"][table_index + 1:]]
            rendered.extend((first, second))
        else:
            rendered.append(page)
    total = len(rendered) + 1
    PDF.parent.mkdir(parents=True, exist_ok=True)
    METRICS.parent.mkdir(parents=True, exist_ok=True)
    c = Canvas(str(PDF), pagesize=A4, pageCompression=1)
    c.setTitle("균열 연대기 — 전체 게임 설계서")
    c.setAuthor("Magic Survival Lab")
    c.setSubject("장기 모바일 게임 설계 초안")
    metrics = []
    previous_chapter = None
    for index, page in enumerate(rendered, 1):
        cover = index == 1
        top = H - (225 if cover else 115)
        available = top - BOTTOM - 28
        scale = 1.0
        while sum(block_height(b, scale) for b in page["blocks"]) > available and scale > .82:
            scale = round(scale - .01, 2)
        required = sum(block_height(b, scale) for b in page["blocks"])
        if required > available:
            raise ValueError(f"{page['id']} exceeds page: {required:.1f} > {available:.1f} pt even at scale {scale}")
        page_background(c, page, index, total)
        if cover:
            c.setFillColor(INK)
            c.rect(0, H - 225, W, 217, stroke=0, fill=1)
            c.setFillColor(TEAL)
            for i in range(6):
                c.circle(W - 67, H - 95, 18 + i * 20, stroke=1, fill=0)
            c.setFillColor(GOLD)
            c.setFont("KR", 10)
            c.drawString(MARGIN, H - 65, "MAGIC SURVIVAL LAB    /    DESIGN DRAFT")
            c.setFillColor(colors.white)
            c.setFont("KR", 35)
            c.drawString(MARGIN, H - 119, page["title"])
            c.setFont("KR", 10)
            c.drawString(MARGIN, H - 155, page["strap"])
            c.setFillColor(colors.HexColor("#D7E7E2"))
            c.drawString(MARGIN, H - 192, "88쪽의 제품 비전 · 전투 · 세계 · 제작 · 검증")
        else:
            c.setFillColor(GOLD)
            c.setFont("KR", 9)
            c.drawString(MARGIN, H - 59, page["chapter"])
            c.setFillColor(INK)
            c.setFont("KR", 21 if len(page["title"]) < 24 else 18)
            c.drawString(MARGIN, H - 84, page["title"])
            draw_para(c, page["strap"], MARGIN, H - 94, CONTENT_W, 9.2, 12, MUTED)
        if page["chapter"] != previous_chapter:
            c.addOutlineEntry(page["chapter"], page["id"], level=0, closed=False)
            previous_chapter = page["chapter"]
        c.bookmarkPage(page["id"])
        c.addOutlineEntry(f"{page['id']}  {page['title']}", page["id"], level=1)
        y = top
        for block in page["blocks"]:
            y = draw_block(c, block, y, scale, index in (3, 4))
        if page.get("sources"):
            c.setFont("KR", 8)
            c.setFillColor(MUTED)
            c.drawString(MARGIN, 56, "근거 자료  " + "  ·  ".join(page["sources"]))
        metrics.append({"id": page["id"], "physical_page": index, "scale": scale, "minimum_body_pt": round(10.6 * scale, 2), "minimum_table_pt": round(9.05 * scale, 2), "content_bottom_pt": round(y, 1), "required_height_pt": round(required, 1)})
        c.showPage()
    # Reference list is separate from the 88 substantive design pages.
    page_background(c, {"chapter": "근거 자료", "id": "refs"}, total, total)
    c.setFillColor(INK)
    c.setFont("KR", 23)
    c.drawString(MARGIN, H - 85, "근거 자료")
    c.setFont("KR", 9)
    c.setFillColor(MUTED)
    c.drawString(MARGIN, H - 105, "링크는 원문으로 연결된다. 미래 설계 수치의 검증 결과로 해석하지 않는다.")
    c.bookmarkPage("references")
    c.addOutlineEntry("근거 자료", "references", level=0)
    y = H - 145
    for key, (label, url) in SOURCES.items():
        c.setFillColor(TEAL)
        c.setFont("KR", 11)
        c.drawString(MARGIN, y, f"{key}   {label}")
        y -= 20
        c.setFillColor(MUTED)
        c.setFont("KR", 7.5)
        c.drawString(MARGIN + 28, y, url)
        c.linkURL(url, (MARGIN + 28, y - 3, W - MARGIN, y + 10), relative=0)
        y -= 52
    c.save()
    METRICS.write_text(json.dumps({"logical_pages": len(pages), "physical_pages": total, "pages": metrics}, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Built {PDF} with {len(pages)} logical design pages on {len(rendered)} physical pages and one reference page")


if __name__ == "__main__":
    main()
