#!/usr/bin/env python3
"""Build review sheets from mega_crystal_qa_driver live screenshots."""

from __future__ import annotations

import argparse
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


FORMS = (
    ("mega_aerodactyl", "Mega Aerodactyl"),
    ("mega_alakazam", "Mega Alakazam"),
    ("mega_ampharos", "Mega Ampharos"),
    ("mega_beedrill", "Mega Beedrill"),
    ("mega_blastoise", "Mega Blastoise"),
    ("mega_charizard_x", "Mega Charizard X"),
    ("mega_charizard_y", "Mega Charizard Y"),
    ("mega_clefable", "Mega Clefable"),
    ("mega_dragonite", "Mega Dragonite"),
    ("mega_feraligatr", "Mega Feraligatr"),
    ("mega_gengar", "Mega Gengar"),
    ("mega_gyarados", "Mega Gyarados"),
    ("mega_heracross", "Mega Heracross"),
    ("mega_houndoom", "Mega Houndoom"),
    ("mega_kangaskhan", "Mega Kangaskhan"),
    ("mega_meganium", "Mega Meganium"),
    ("mega_mewtwo_x", "Mega Mewtwo X"),
    ("mega_mewtwo_y", "Mega Mewtwo Y"),
    ("mega_pidgeot", "Mega Pidgeot"),
    ("mega_pinsir", "Mega Pinsir"),
    ("mega_raichu_x", "Mega Raichu X"),
    ("mega_raichu_y", "Mega Raichu Y"),
    ("mega_scizor", "Mega Scizor"),
    ("mega_skarmory", "Mega Skarmory"),
    ("mega_slowbro", "Mega Slowbro"),
    ("mega_starmie", "Mega Starmie"),
    ("mega_steelix", "Mega Steelix"),
    ("mega_tyranitar", "Mega Tyranitar"),
    ("mega_venusaur", "Mega Venusaur"),
    ("mega_victreebel", "Mega Victreebel"),
    ("ascendant_typhlosion", "Ascendant Typhlosion"),
)

THUMBNAIL = (320, 240)
LABEL_HEIGHT = 32
COLUMNS = 4


def font() -> ImageFont.ImageFont:
    for candidate in (
        "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    ):
        try:
            return ImageFont.truetype(candidate, 18)
        except OSError:
            pass
    return ImageFont.load_default()


def build(source: Path, layout: str, target: Path, shiny: bool) -> None:
    rows = math.ceil(len(FORMS) / COLUMNS)
    cell_width = THUMBNAIL[0]
    cell_height = THUMBNAIL[1] + LABEL_HEIGHT
    sheet = Image.new(
        "RGB",
        (COLUMNS * cell_width, rows * cell_height),
        (18, 21, 29),
    )
    draw = ImageDraw.Draw(sheet)
    label_font = font()

    missing: list[Path] = []
    for index, (stem, label) in enumerate(FORMS):
        suffix = "_shiny" if shiny else ""
        screenshot = source / f"{stem}_{layout}{suffix}.png"
        if not screenshot.is_file():
            missing.append(screenshot)
            continue
        with Image.open(screenshot) as image:
            resampling = (
                Image.Resampling.NEAREST
                if layout == "2d"
                else Image.Resampling.LANCZOS
            )
            thumbnail = image.convert("RGB").resize(THUMBNAIL, resampling)
        column = index % COLUMNS
        row = index // COLUMNS
        x = column * cell_width
        y = row * cell_height
        sheet.paste(thumbnail, (x, y))
        draw.rectangle(
            (x, y + THUMBNAIL[1], x + cell_width, y + cell_height),
            fill=(18, 21, 29),
        )
        draw.text(
            (x + 10, y + THUMBNAIL[1] + 6),
            label,
            font=label_font,
            fill=(242, 245, 255),
        )

    if missing:
        raise SystemExit(
            "Missing screenshots:\n" + "\n".join(str(path) for path in missing)
        )
    target.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(target, "PNG", optimize=False)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument(
        "--output", type=Path, help="output directory (defaults to source)"
    )
    parser.add_argument(
        "--shiny", action="store_true", help="build sheets from Shiny captures"
    )
    parser.add_argument(
        "--layout",
        choices=("both", "2d", "voxel"),
        default="both",
        help="build both renderers or only one captured layout",
    )
    args = parser.parse_args()
    output = args.output or args.source
    layouts = ("2d", "voxel") if args.layout == "both" else (args.layout,)
    for layout in layouts:
        suffix = "_shiny" if args.shiny else ""
        build(
            args.source,
            layout,
            output / f"mega_gallery_{layout}{suffix}.png",
            args.shiny,
        )
    print(
        f"Built {len(layouts)} review sheet(s) from "
        f"{len(FORMS) * len(layouts)} live screenshots"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
