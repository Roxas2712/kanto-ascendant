#!/usr/bin/env python3
"""Build Gorochu's fail-closed 64 px 2D battle sprite matrix.

Front geometry comes from the exact P-Infinity wiki PNGs: their native 2x
pixel grid is decimated to the authored 80 px basis and then reduced to 64 px
with an explicit hard nearest-pixel sampler.  The repaired edition back is the
reviewed 5.4.0 rear sprite enlarged with the same hard sampler and recoloured
into the wiki palette.  No bilinear filtering, antialiasing or halo colours are
used.

The complete opaque body, dark tail root and yellow lightning blade are one
fixed connected component in all six frames.  Only detached yellow/white
charge clusters build and decay around it.  Normal, shiny and four-neutral-
shade classic variants share identical frame masks.
"""

from __future__ import annotations

import argparse
import hashlib
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
CANVAS_SIZE = (64, 64)
WIKI_BASIS_SIZE = (80, 80)
FRAME_COUNT = 6
DEX = "1026"
TRANSPARENT = (0, 0, 0, 0)

SOURCE_DIR = ROOT / "assets/sources/gorochu"
SOURCE_FILES = {
    "wiki_front_normal": SOURCE_DIR / "pinfinity_wiki_732_front_normal.png",
    "wiki_back_normal": SOURCE_DIR / "pinfinity_wiki_732_back_normal.png",
    "wiki_front_shiny": SOURCE_DIR / "pinfinity_wiki_732_front_shiny.png",
    "wiki_back_shiny": SOURCE_DIR / "pinfinity_wiki_732_back_shiny.png",
    "edition_front_normal": SOURCE_DIR / "pinfinity_v540_front_normal_56.png",
    "edition_front_shiny": SOURCE_DIR / "pinfinity_v540_front_shiny_56.png",
    "edition_back_normal": SOURCE_DIR / "pinfinity_v540_back_normal_56.png",
    "edition_back_shiny": SOURCE_DIR / "pinfinity_v540_back_shiny_56.png",
}
SOURCE_SHA256 = {
    "wiki_front_normal": "b2402d1fd6d6370571d0df59cadc978558785788f9b17144211d5ea9c0e9d498",
    "wiki_back_normal": "1f3102fbfeed10979d02361fcda182e9317df9b79690f6b521c0075f08c6e88e",
    "wiki_front_shiny": "aa794f5f6ba794a1de7f14e569ff1156249a4e83ab5b87c355c0a5d383ba5ed5",
    "wiki_back_shiny": "9a31e2e71e295452ab0f8c0650a4a46bfeb0d96cbed18fa13bb97c58f22e75c4",
    "edition_front_normal": "5f09edea0a186df794a549a5a8d2db2d42a96df7fab90beff9cdc8c27eb40d16",
    "edition_front_shiny": "605f2f9ccbb973de0ce5e7c20b994db7f716eae4d153fa718262da140159e274",
    "edition_back_normal": "6ca9669687ca68ebfb9ebfc99eaa6644dc312fc4e18c701f83dab33f069886b1",
    "edition_back_shiny": "942bed4b1e789ca0db45d221ec67e734f9f849030de0ea0eee29805760d31292",
}

# Exact P-Infinity normal slots used by both 64 px sides.
BLACK = (0, 0, 0, 255)
DARK_FUR = (75, 35, 27, 255)
MID_FUR = (117, 56, 42, 255)
DARK_RED = (157, 47, 35, 255)
MAIN_FUR = (217, 84, 46, 255)
TAN_FUR = (182, 122, 82, 255)
LIGHT_FUR = (245, 139, 69, 255)
GOLD = (248, 184, 0, 255)
LIGHT_GOLD = (248, 216, 88, 255)
CREAM = (224, 200, 160, 255)
PALE = (248, 232, 208, 255)

SHINY_MAP = {
    BLACK: (0, 0, 0, 255),
    DARK_FUR: (32, 32, 32, 255),
    MID_FUR: (50, 50, 50, 255),
    DARK_RED: (75, 76, 141, 255),
    MAIN_FUR: (96, 88, 186, 255),
    TAN_FUR: (83, 83, 83, 255),
    LIGHT_FUR: (180, 143, 239, 255),
    GOLD: (248, 183, 0, 255),
    LIGHT_GOLD: (248, 215, 88, 255),
    CREAM: (224, 200, 160, 255),
    PALE: (248, 232, 208, 255),
    (224, 157, 129, 255): (224, 157, 129, 255),
    (250, 235, 150, 255): (250, 235, 150, 255),
}

EDITION_DARK = (40, 25, 25, 255)
EDITION_BROWN = (76, 45, 43, 255)
EDITION_ORANGE = (229, 68, 35, 255)
EDITION_GOLD = (255, 170, 40, 255)
EDITION_CREAM = (255, 229, 183, 255)
EDITION_PALETTE = {
    EDITION_DARK,
    EDITION_BROWN,
    EDITION_ORANGE,
    EDITION_GOLD,
    EDITION_CREAM,
}

# Yellow/white charge cadence: off -> build -> peak -> decay.  Every cluster
# remains at least one transparent pixel away from the fixed body/tail mask.
ARC_DOT = ((0, 0, "light"), (1, 1, "gold"))
ARC_ZIG = ((0, 0, "gold"), (1, 1, "light"), (1, 2, "gold"), (2, 3, "light"))
ARC_RISE = ((0, 4, "gold"), (1, 3, "light"), (1, 2, "gold"), (2, 1, "light"), (2, 0, "gold"))
CHARGE_SPECS = {
    "front": (
        (),
        ((10, 22, ARC_DOT),),
        ((6, 21, ARC_ZIG),),
        ((2, 21, ARC_RISE), (55, 12, ARC_ZIG)),
        ((7, 22, ARC_ZIG), (44, 3, ARC_DOT)),
        ((11, 22, ARC_DOT),),
    ),
    "back": (
        (),
        ((52, 12, ARC_DOT),),
        ((48, 12, ARC_ZIG),),
        ((43, 11, ARC_RISE), (2, 24, ARC_DOT)),
        ((48, 14, ARC_ZIG), (35, 4, ARC_DOT)),
        ((52, 13, ARC_DOT),),
    ),
}


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def clean_transparency(image: Image.Image) -> Image.Image:
    source = image.convert("RGBA")
    output = Image.new("RGBA", source.size, TRANSPARENT)
    source_pixels = source.load()
    target_pixels = output.load()
    for y in range(source.height):
        for x in range(source.width):
            pixel = source_pixels[x, y]
            if pixel[3] not in (0, 255):
                raise ValueError(f"non-binary source alpha {pixel[3]} at {(x, y)}")
            target_pixels[x, y] = pixel if pixel[3] else TRANSPARENT
    return output


def read_clean(path: Path) -> Image.Image:
    if not path.is_file():
        raise FileNotFoundError(path)
    with Image.open(path) as opened:
        return clean_transparency(opened)


def validate_sources() -> None:
    for name, path in SOURCE_FILES.items():
        actual = sha256(path)
        expected = SOURCE_SHA256[name]
        if actual != expected:
            raise ValueError(f"{path}: expected source SHA-256 {expected}, got {actual}")

    for side in ("front", "back"):
        for variant in ("normal", "shiny"):
            image = read_clean(SOURCE_FILES[f"wiki_{side}_{variant}"])
            if image.height != 160 or image.width < 160:
                raise ValueError(f"wiki {side}/{variant}: expected at least 160x160")
            if any(image.getpixel((x, y))[3] for y in range(160) for x in range(160, image.width)):
                raise ValueError(f"wiki {side}/{variant}: unexpected art outside authored 160 px grid")
            for y in range(0, 160, 2):
                for x in range(0, 160, 2):
                    block = {image.getpixel((x + dx, y + dy)) for dy in (0, 1) for dx in (0, 1)}
                    if len(block) != 1:
                        raise ValueError(f"wiki {side}/{variant}: broken native 2x grid at {(x, y)}")

    for side in ("front", "back"):
        for variant in ("normal", "shiny"):
            image = read_clean(SOURCE_FILES[f"edition_{side}_{variant}"])
            if image.size != (56, 56):
                raise ValueError(f"edition {side}/{variant}: reviewed source is no longer native 56 px")


def decimate_wiki(path: Path) -> Image.Image:
    """Select one exact pixel from each authored 2x block to recover 80 px."""

    source = read_clean(path)
    output = Image.new("RGBA", WIKI_BASIS_SIZE, TRANSPARENT)
    source_pixels = source.load()
    target_pixels = output.load()
    for y in range(WIKI_BASIS_SIZE[1]):
        for x in range(WIKI_BASIS_SIZE[0]):
            target_pixels[x, y] = source_pixels[x * 2, y * 2]
    return output


def hard_nearest(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    """Nearest-centre integer sampling with no interpolation or new colours."""

    output = Image.new("RGBA", size, TRANSPARENT)
    source_pixels = image.load()
    target_pixels = output.load()
    for y in range(size[1]):
        source_y = min(image.height - 1, ((2 * y + 1) * image.height) // (2 * size[1]))
        for x in range(size[0]):
            source_x = min(image.width - 1, ((2 * x + 1) * image.width) // (2 * size[0]))
            target_pixels[x, y] = source_pixels[source_x, source_y]
    return output


def placed(image: Image.Image, offset: tuple[int, int]) -> Image.Image:
    source_count = sum(1 for alpha in image.getchannel("A").getdata() if alpha)
    output = Image.new("RGBA", CANVAS_SIZE, TRANSPARENT)
    output.alpha_composite(image, offset)
    target_count = sum(1 for alpha in output.getchannel("A").getdata() if alpha)
    if source_count != target_count:
        raise ValueError(f"placement {offset} clipped opaque pixels")
    return output


def map_palette(image: Image.Image, mapping: dict[tuple[int, ...], tuple[int, ...]]) -> Image.Image:
    output = Image.new("RGBA", image.size, TRANSPARENT)
    source_pixels = image.load()
    target_pixels = output.load()
    for y in range(image.height):
        for x in range(image.width):
            pixel = source_pixels[x, y]
            if pixel[3]:
                try:
                    target_pixels[x, y] = mapping[pixel]
                except KeyError as error:
                    raise ValueError(f"unmapped Gorochu colour {pixel} at {(x, y)}") from error
    return output


def neutral_palette(image: Image.Image) -> Image.Image:
    output = Image.new("RGBA", image.size, TRANSPARENT)
    source_pixels = image.load()
    target_pixels = output.load()
    for y in range(image.height):
        for x in range(image.width):
            red, green, blue, alpha = source_pixels[x, y]
            if not alpha:
                continue
            luminance = (299 * red + 587 * green + 114 * blue) // 1000
            shade = 0 if luminance < 32 else 85 if luminance < 96 else 170 if luminance < 210 else 255
            target_pixels[x, y] = (shade, shade, shade, 255)
    return output


def front_bases() -> tuple[Image.Image, Image.Image]:
    normal = placed(hard_nearest(decimate_wiki(SOURCE_FILES["wiki_front_normal"]), CANVAS_SIZE), (1, 1))
    shiny = placed(hard_nearest(decimate_wiki(SOURCE_FILES["wiki_front_shiny"]), CANVAS_SIZE), (1, 1))
    if normal.getchannel("A").tobytes() != shiny.getchannel("A").tobytes():
        raise ValueError("wiki front normal/shiny masks diverged")
    return normal, shiny


def edition_back_to_wiki_palette() -> Image.Image:
    source = read_clean(SOURCE_FILES["edition_back_normal"])
    if {pixel for pixel in source.getdata() if pixel[3]} != EDITION_PALETTE:
        raise ValueError("reviewed edition back palette changed")
    output = Image.new("RGBA", source.size, TRANSPARENT)
    source_pixels = source.load()
    target_pixels = output.load()
    for y in range(source.height):
        for x in range(source.width):
            pixel = source_pixels[x, y]
            if not pixel[3]:
                continue
            accent = (x >= 40 and y >= 20) or (y < 17 and 12 <= x <= 36)
            if pixel == EDITION_DARK:
                target_pixels[x, y] = BLACK
            elif pixel == EDITION_BROWN:
                target_pixels[x, y] = DARK_FUR
            elif pixel == EDITION_ORANGE:
                target_pixels[x, y] = MAIN_FUR
            elif pixel == EDITION_GOLD:
                target_pixels[x, y] = GOLD if accent else LIGHT_FUR
            elif pixel == EDITION_CREAM:
                target_pixels[x, y] = LIGHT_GOLD if accent else TAN_FUR
            else:
                raise ValueError(f"unexpected edition back colour {pixel}")
    return output


def back_bases() -> tuple[Image.Image, Image.Image]:
    normal = placed(hard_nearest(edition_back_to_wiki_palette(), CANVAS_SIZE), (0, 3))
    shiny = map_palette(normal, SHINY_MAP)
    return normal, shiny


def opaque_mask(image: Image.Image) -> set[tuple[int, int]]:
    return {
        (x, y)
        for y in range(image.height)
        for x in range(image.width)
        if image.getpixel((x, y))[3]
    }


def add_charge_clusters(
    base: Image.Image,
    specs: tuple[tuple[int, int, tuple[tuple[int, int, str], ...]], ...],
    gold: tuple[int, ...],
    light: tuple[int, ...],
) -> Image.Image:
    output = base.copy()
    pixels = output.load()
    base_mask = opaque_mask(base)
    palette = {"gold": gold, "light": light}
    for origin_x, origin_y, pattern in specs:
        for dx, dy, slot in pattern:
            x, y = origin_x + dx, origin_y + dy
            if not (1 <= x <= 62 and 1 <= y <= 62):
                raise ValueError(f"charge pixel outside safe canvas at {(x, y)}")
            if pixels[x, y][3]:
                raise ValueError(f"charge cluster overlaps another opaque pixel at {(x, y)}")
            distance = min(max(abs(x - bx), abs(y - by)) for bx, by in base_mask)
            if distance < 2:
                raise ValueError(f"charge cluster touches fixed body/tail at {(x, y)}")
            pixels[x, y] = palette[slot]
    return output


def build_frames(side: str) -> dict[str, list[Image.Image]]:
    normal_base, shiny_base = front_bases() if side == "front" else back_bases()
    specs = CHARGE_SPECS[side]
    normal = [add_charge_clusters(normal_base, frame_specs, GOLD, LIGHT_GOLD) for frame_specs in specs]
    shiny = [
        add_charge_clusters(shiny_base, frame_specs, SHINY_MAP[GOLD], SHINY_MAP[LIGHT_GOLD])
        for frame_specs in specs
    ]
    grayscale = [neutral_palette(frame) for frame in normal]
    return {"normal": normal, "shiny": shiny, "grayscale": grayscale}


def write_png(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, "PNG", optimize=False, compress_level=9)


def write_frames(frames: list[Image.Image], target: Path) -> None:
    if len(frames) != FRAME_COUNT:
        raise ValueError(f"expected {FRAME_COUNT} frames, got {len(frames)}")
    target.mkdir(parents=True, exist_ok=True)
    for stale in target.glob("*.png"):
        stale.unlink()
    for index, frame in enumerate(frames, 1):
        write_png(frame, target / f"{index:03d}.png")


def checker_cell(size: tuple[int, int], tile: int = 8) -> Image.Image:
    cell = Image.new("RGBA", size, (232, 232, 232, 255))
    draw = ImageDraw.Draw(cell)
    for y in range(0, size[1], tile):
        for x in range(0, size[0], tile):
            if (x // tile + y // tile) % 2:
                draw.rectangle((x, y, x + tile - 1, y + tile - 1), fill=(205, 205, 205, 255))
    return cell


def write_contact_sheet(matrix: dict[tuple[str, str], list[Image.Image]], path: Path) -> None:
    scale = 4
    sprite_size = CANVAS_SIZE[0] * scale
    label_height = 24
    margin = 12
    rows = [(variant, side) for variant in ("normal", "shiny", "grayscale") for side in ("front", "back")]
    sheet = Image.new(
        "RGBA",
        (margin * 2 + FRAME_COUNT * sprite_size, margin * 2 + len(rows) * (sprite_size + label_height)),
        (242, 242, 242, 255),
    )
    draw = ImageDraw.Draw(sheet)
    for row, (variant, side) in enumerate(rows):
        top = margin + row * (sprite_size + label_height)
        draw.text((margin + 4, top + 4), f"64PX {variant.upper()} {side.upper()}", fill=(0, 0, 0, 255))
        sprite_top = top + label_height
        for column, frame in enumerate(matrix[(side, variant)]):
            left = margin + column * sprite_size
            sheet.alpha_composite(checker_cell((sprite_size, sprite_size)), (left, sprite_top))
            sheet.alpha_composite(frame.resize((sprite_size, sprite_size), Image.Resampling.NEAREST), (left, sprite_top))
            draw.text((left + 4, sprite_top + 4), f"{column + 1:03d}", fill=(0, 0, 0, 255))
    path.parent.mkdir(parents=True, exist_ok=True)
    sheet.convert("RGB").save(path, "PNG", optimize=False, compress_level=9)


def build(output_root: Path, contact_sheet: Path | None = None) -> list[Path]:
    validate_sources()
    matrix: dict[tuple[str, str], list[Image.Image]] = {}
    for side in ("front", "back"):
        for variant, frames in build_frames(side).items():
            matrix[(side, variant)] = frames

    written: list[Path] = []
    for side in ("front", "back"):
        for variant in ("normal", "shiny", "grayscale"):
            target = output_root / "assets/crystal_animated" / side / variant / DEX
            write_frames(matrix[(side, variant)], target)
            written.extend(target / f"{index:03d}.png" for index in range(1, FRAME_COUNT + 1))

    static_assets = {
        "gorochu_front.png": matrix[("front", "normal")][0],
        "gorochu_front_shiny.png": matrix[("front", "shiny")][0],
        "gorochu_back.png": matrix[("back", "normal")][0],
        "gorochu_back_shiny.png": matrix[("back", "shiny")][0],
    }
    for filename, image in static_assets.items():
        target = output_root / "assets/crystal" / filename
        write_png(image, target)
        written.append(target)

    if contact_sheet is not None:
        write_contact_sheet(matrix, contact_sheet)
    return written


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-root", type=Path, default=ROOT)
    parser.add_argument("--contact-sheet", type=Path)
    args = parser.parse_args()
    output_root = args.output_root.resolve()
    contact_sheet = args.contact_sheet.resolve() if args.contact_sheet else None
    written = build(output_root, contact_sheet)
    digest = hashlib.sha256("".join(sha256(path) for path in sorted(written)).encode()).hexdigest()
    print(f"Built {len(written)} connected-tail Gorochu 64 px PNGs; matrix digest {digest}")
    if contact_sheet is not None:
        print(f"Contact sheet: {contact_sheet}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
