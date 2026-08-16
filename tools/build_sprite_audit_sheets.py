#!/usr/bin/env python3
"""Build deterministic #001-251 QA contact sheets from shipped sprite art."""

from __future__ import annotations

import argparse
import re
from pathlib import Path

from PIL import Image, ImageDraw


COLS = 16
ROWS = 16
CELL = 72
BACKGROUND = (247, 242, 218, 255)
INK = (20, 31, 48, 255)
GRID = (207, 192, 139, 255)


def fit_nearest(image: Image.Image, width: int, height: int) -> Image.Image:
    image = image.convert("RGBA")
    bbox = image.getbbox()
    if bbox:
        image = image.crop(bbox)
    scale = min(width / max(1, image.width), height / max(1, image.height))
    size = (max(1, round(image.width * scale)),
            max(1, round(image.height * scale)))
    return image.resize(size, Image.Resampling.NEAREST)


def johto_species(root: Path) -> dict[int, str]:
    text = (root / "johto_data.lua").read_text(encoding="utf-8")
    result = {
        int(dex): species
        for dex, species in re.findall(
            r'\{\s*(\d+),\s*"([A-Z0-9_]+)"', text
        )
        if 152 <= int(dex) <= 251
    }
    if len(result) != 100:
        raise RuntimeError(f"expected 100 Johto species, found {len(result)}")
    return result


def front_path(root: Path, dex: int, variant: str) -> Path:
    return (root / "assets" / "crystal_animated" / "front" / variant
            / str(dex) / "001.png")


def party_path(root: Path, dex: int, johto: dict[int, str]) -> Path:
    if dex <= 151:
        return root / "assets" / "followers_kanto" / f"follower_{dex:03d}.png"
    return (root / "assets" / "followers_runtime" / "normal"
            / f"follower_{johto[dex]}.png")


def build(root: Path, output: Path, title: str, resolver, frame: int | None) -> None:
    sheet = Image.new("RGBA", (COLS * CELL, ROWS * CELL), BACKGROUND)
    draw = ImageDraw.Draw(sheet)
    for dex in range(1, 252):
        col, row = (dex - 1) % COLS, (dex - 1) // COLS
        x, y = col * CELL, row * CELL
        draw.rectangle((x, y, x + CELL - 1, y + CELL - 1), outline=GRID)
        draw.text((x + 3, y + 2), f"{dex:03d}", fill=INK)
        path = resolver(dex)
        if not path.is_file():
            raise FileNotFoundError(path)
        with Image.open(path) as source:
            sprite = source.convert("RGBA")
        if frame is not None:
            top = frame * 16
            if sprite.width != 16 or sprite.height < top + 16:
                raise RuntimeError(f"invalid party sheet: {path}")
            sprite = sprite.crop((0, top, 16, top + 16))
        sprite = fit_nearest(sprite, 62, 52)
        sheet.alpha_composite(
            sprite,
            (x + (CELL - sprite.width) // 2,
             y + 17 + (52 - sprite.height) // 2),
        )
    draw.rectangle((0, 0, sheet.width - 1, sheet.height - 1), outline=INK, width=2)
    output.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(output)
    print(f"SPRITE AUDIT SHEET PASS: {title}: {output}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path(__file__).parents[1])
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    root = args.root.resolve()
    output = args.output.resolve()
    johto = johto_species(root)

    build(root, output / "crystal-normal-001-251.png",
          "Crystal normal front frames #001-251",
          lambda dex: front_path(root, dex, "normal"), None)
    build(root, output / "crystal-shiny-001-251.png",
          "Crystal shiny front frames #001-251",
          lambda dex: front_path(root, dex, "shiny"), None)
    build(root, output / "party-icons-frame-a-001-251.png",
          "party icons resting frames #001-251",
          lambda dex: party_path(root, dex, johto), 0)
    build(root, output / "party-icons-frame-b-001-251.png",
          "party icons animated frames #001-251",
          lambda dex: party_path(root, dex, johto), 3)


if __name__ == "__main__":
    main()
