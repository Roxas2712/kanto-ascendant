#!/usr/bin/env python3
"""Verify and assemble the renderer-backed Hoenn Mega acceptance captures."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "qa" / "hoenn_mega_animation"
LIVE = OUT / "live"
FORMS = ("blaziken", "swampert", "sceptile")
GEN1 = (("blaziken", "player", "", "red"),
        ("blaziken", "enemy", "_shiny", "red"),
        ("swampert", "player", "", "blue"),
        ("swampert", "enemy", "_shiny", "blue"),
        ("sceptile", "player", "", "yellow"),
        ("sceptile", "enemy", "_shiny", "yellow"))
VOXEL = (("blaziken", "enemy", ""), ("blaziken", "player", "_shiny"),
         ("swampert", "player", ""), ("swampert", "enemy", "_shiny"),
         ("sceptile", "player", ""), ("sceptile", "enemy", "_shiny"))


def font() -> ImageFont.ImageFont:
    try:
        return ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", 15)
    except OSError:
        return ImageFont.load_default()


def make_sheet(name: str, captures: list[tuple[Path, str]]) -> str:
    cell_w, cell_h, label_h, cols = 256, 192, 24, 3
    rows = (len(captures) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * cell_w, rows * (cell_h + label_h)), (18, 21, 29))
    draw, text = ImageDraw.Draw(sheet), font()
    for index, (path, label) in enumerate(captures):
        if not path.is_file():
            raise FileNotFoundError(path)
        with Image.open(path) as source:
            image = source.convert("RGB").resize((cell_w, cell_h), Image.Resampling.NEAREST)
        x, y = index % cols * cell_w, index // cols * (cell_h + label_h)
        sheet.paste(image, (x, y))
        draw.text((x + 6, y + cell_h + 4), label, fill=(242, 245, 255), font=text)
    target = OUT / name
    sheet.save(target, "PNG", optimize=False)
    return target.name


def main() -> None:
    crystal: list[tuple[Path, str]] = []
    for form in FORMS:
        for side in ("enemy", "player"):
            for shiny in ("", "_shiny"):
                filename = f"mega_{form}_2d_{side}{shiny}.png"
                crystal.append((LIVE / filename, f"{form} {side} {shiny[1:] or 'normal'}"))
    gen1 = [(LIVE / f"mega_{form}_2d_{side}{shiny}_gen1_{edition}.png",
             f"{form} {edition} {side} {shiny[1:] or 'normal'}")
            for form, side, shiny, edition in GEN1]
    voxel = [(LIVE / f"mega_{form}_voxel_{side}{shiny}.png",
              f"{form} voxel {side} {shiny[1:] or 'normal'}")
             for form, side, shiny in VOXEL]
    sheets = {
        "crystal2D": make_sheet("live_2d_crystal_contact.png", crystal),
        "gen1Fallback": make_sheet("live_2d_gen1_contact.png", gen1),
        "voxel": make_sheet("live_voxel_contact.png", voxel),
    }
    paths = [path for group in (crystal, gen1, voxel) for path, _ in group]
    report = {
        "format": 1,
        "captureCount": len(paths),
        "sheets": sheets,
        "sha256": {path.name: hashlib.sha256(path.read_bytes()).hexdigest() for path in paths},
    }
    (OUT / "live_capture_report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(f"Hoenn Mega live gallery: PASS ({len(paths)} screenshots)")


if __name__ == "__main__":
    main()
