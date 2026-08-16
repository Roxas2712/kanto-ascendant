#!/usr/bin/env python3
"""Build preview-only Gorochu front sprites in an authentic Crystal palette.

This script never writes product assets.  It compares three 56 px logical
sources against a genuine Crystal sprite: the historical five-colour sprite,
the P-Infinity wiki geometry reduced to the same palette, and the separately
generated anatomy concept reduced to a hard pixel grid.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/sources/gorochu"
OUT = ROOT / "qa/rc28_manual_fixes_20260814/images/gorochu_crystal_primary_candidate"
TRANSPARENT = (0, 0, 0, 0)
PALETTE = (
    (0, 0, 0, 255),
    (75, 35, 27, 255),
    (217, 84, 46, 255),
    (248, 184, 0, 255),
    (248, 232, 208, 255),
)


def nearest_colour(pixel: tuple[int, int, int, int]) -> tuple[int, int, int, int]:
    red, green, blue, _ = pixel
    return min(
        PALETTE,
        key=lambda colour: (red - colour[0]) ** 2
        + (green - colour[1]) ** 2
        + (blue - colour[2]) ** 2,
    )


def clean(image: Image.Image, threshold: int = 96) -> Image.Image:
    source = image.convert("RGBA")
    output = Image.new("RGBA", source.size, TRANSPARENT)
    source_pixels = source.load()
    target_pixels = output.load()
    for y in range(source.height):
        for x in range(source.width):
            pixel = source_pixels[x, y]
            if pixel[3] >= threshold:
                target_pixels[x, y] = nearest_colour(pixel)
    return output


def fit_56(image: Image.Image, maximum: tuple[int, int] = (54, 54)) -> Image.Image:
    source = image.convert("RGBA")
    bounds = source.getchannel("A").getbbox()
    if bounds is None:
        raise ValueError("empty source")
    crop = source.crop(bounds)
    scale = min(maximum[0] / crop.width, maximum[1] / crop.height)
    size = (max(1, round(crop.width * scale)), max(1, round(crop.height * scale)))
    reduced = crop.resize(size, Image.Resampling.LANCZOS)
    reduced = clean(reduced)
    output = Image.new("RGBA", (56, 56), TRANSPARENT)
    output.alpha_composite(reduced, ((56 - size[0]) // 2, 56 - size[1]))
    return output


def decimate_wiki() -> Image.Image:
    source = Image.open(SOURCE / "pinfinity_wiki_732_front_normal.png").convert("RGBA")
    basis = Image.new("RGBA", (80, 80), TRANSPARENT)
    for y in range(80):
        for x in range(80):
            basis.putpixel((x, y), source.getpixel((x * 2, y * 2)))
    return fit_56(basis)


def generated_concept(filename: str = "gorochu_crystal_primary_imagegen_reference_alpha.png") -> Image.Image:
    source = Image.open(SOURCE / filename).convert("RGBA")
    return fit_56(source)


def historical() -> Image.Image:
    return clean(Image.open(SOURCE / "pinfinity_v540_front_normal_56.png"))


def write(image: Image.Image, name: str) -> Path:
    path = OUT / name
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, "PNG", optimize=False, compress_level=9)
    return path


def contact(candidates: list[tuple[str, Image.Image]]) -> None:
    scale = 8
    cell = 56 * scale
    label = 42
    margin = 16
    sheet = Image.new(
        "RGBA", (margin * 2 + cell * len(candidates), margin * 2 + label + cell),
        (240, 240, 240, 255),
    )
    draw = ImageDraw.Draw(sheet)
    for index, (name, image) in enumerate(candidates):
        left = margin + index * cell
        for y in range(0, cell, 16):
            for x in range(0, cell, 16):
                colour = (214, 214, 214, 255) if (x // 16 + y // 16) % 2 else (238, 238, 238, 255)
                draw.rectangle((left + x, margin + label + y, left + x + 15, margin + label + y + 15), fill=colour)
        draw.text((left + 4, margin + 8), name, fill=(0, 0, 0, 255))
        sheet.alpha_composite(
            image.resize((cell, cell), Image.Resampling.NEAREST),
            (left, margin + label),
        )
    sheet.convert("RGB").save(OUT / "gorochu_crystal_primary_candidates.png", "PNG")


def main() -> int:
    candidates = [
        ("A HISTORICAL 56", historical()),
        ("B WIKI 5-COLOR 56", decimate_wiki()),
        ("C NEW ANATOMY POSE A", generated_concept()),
        (
            "D NEW ANATOMY POSE B",
            generated_concept("gorochu_crystal_primary_imagegen_pose_b_alpha.png"),
        ),
    ]
    for letter, (_, image) in zip(("a", "b", "c", "d"), candidates):
        write(image, f"candidate_{letter}.png")
    contact(candidates)
    print(OUT / "gorochu_crystal_primary_candidates.png")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
