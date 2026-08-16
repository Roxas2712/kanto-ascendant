#!/usr/bin/env python3
"""Build labeled review sheets for the authored trainer Voxel standees."""

from __future__ import annotations

import csv
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


MOD = Path(__file__).resolve().parents[1]
QA = MOD / "qa" / "trainer_voxel_asset_authoring_20260812"
ASSETS = MOD / "assets" / "characters" / "frlg_trainers"
MANIFEST = QA / "MANIFEST.tsv"

EXISTING = [
    ("elite_four_lorelei", "OPP_LORELEI", "Lorelei", "Top Vier Eis"),
    ("elite_four_bruno", "OPP_BRUNO", "Bruno", "Top Vier Kampf"),
    ("elite_four_agatha", "OPP_AGATHA", "Agatha", "Top Vier Geist"),
    ("elite_four_lance", "OPP_LANCE", "Siegfried", "Top Vier Drache"),
]


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    name = "Arial Bold.ttf" if bold else "Arial.ttf"
    path = Path("/System/Library/Fonts/Supplemental") / name
    return ImageFont.truetype(str(path), size)


def checker(size: tuple[int, int], step: int = 12) -> Image.Image:
    image = Image.new("RGBA", size, (42, 46, 56, 255))
    draw = ImageDraw.Draw(image)
    for y in range(0, size[1], step):
        for x in range(0, size[0], step):
            if (x // step + y // step) % 2:
                draw.rectangle((x, y, x + step - 1, y + step - 1), fill=(55, 60, 72, 255))
    return image


def rows() -> list[dict[str, str]]:
    with MANIFEST.open(encoding="utf-8", newline="") as handle:
        result = list(csv.DictReader(handle, delimiter="\t"))
    for row in result:
        row["path"] = str(ASSETS / f"{row['stem']}_voxel_front_hd_v1.png")
        row["status"] = "NEU: ASCENDANT HD"
    for stem, class_id, name, role in EXISTING:
        result.append({
            "stem": stem,
            "class_id": class_id,
            "german_name": name,
            "role": role,
            "path": str(ASSETS / f"{stem}_voxel_front_hd_v2.png"),
            "status": "BEREITS ABGENOMMEN",
        })
    return result


def card(row: dict[str, str]) -> Image.Image:
    width, height = 300, 250
    result = Image.new("RGBA", (width, height), (24, 27, 34, 255))
    draw = ImageDraw.Draw(result)
    preview = checker((180, 180))
    sprite = Image.open(row["path"]).convert("RGBA").resize((180, 180), Image.Resampling.NEAREST)
    preview.alpha_composite(sprite)
    result.alpha_composite(preview, (60, 8))
    draw.rectangle((58, 6, 241, 189), outline=(104, 113, 135, 255), width=2)
    draw.text((12, 194), row["german_name"], font=font(18, True), fill=(245, 247, 252, 255))
    draw.text((12, 216), row["class_id"], font=font(11), fill=(170, 202, 255, 255))
    role = row["role"]
    if len(role) > 42:
        role = role[:39] + "..."
    draw.text((12, 232), role, font=font(11), fill=(196, 201, 211, 255))
    return result


def build() -> None:
    entries = rows()
    out = QA / "contact_sheets"
    out.mkdir(parents=True, exist_ok=True)
    chunk_size = 14
    for number, start in enumerate(range(0, len(entries), chunk_size), 1):
        chunk = entries[start:start + chunk_size]
        cols, rows_count = 4, 4
        sheet = Image.new("RGBA", (cols * 300 + 48, rows_count * 250 + 104), (15, 17, 22, 255))
        draw = ImageDraw.Draw(sheet)
        draw.text((24, 18), f"KANTO ASCENDANT — TRAINER HD {number}/3", font=font(28, True), fill=(255, 255, 255, 255))
        draw.text((24, 56), "128×128 Full-Voxel-Vorschau · Name · Runtime-Klasse · Rolle", font=font(17), fill=(186, 195, 212, 255))
        for index, entry in enumerate(chunk):
            x = 24 + (index % cols) * 300
            y = 92 + (index // cols) * 250
            sheet.alpha_composite(card(entry), (x, y))
        sheet.convert("RGB").save(out / f"trainer_hd_review_{number}.png", optimize=True)


if __name__ == "__main__":
    build()
