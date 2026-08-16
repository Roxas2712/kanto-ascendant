#!/usr/bin/env python3
"""Build Gorochu's 56 px Crystal-style Voxel front animation.

The existing illustrated 96 px Voxel cycle is intentionally not touched.  It
remains the automatic runtime fallback.  This builder produces a separate
five-colour, nearest-neighbour primary lane for front-facing Voxel cards.
"""

from __future__ import annotations

import argparse
import hashlib
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = ROOT / "assets/sources/gorochu"
SOURCE_FILES = {
    "pose_a": SOURCE_DIR / "gorochu_crystal_primary_imagegen_reference_alpha.png",
    "pose_b": SOURCE_DIR / "gorochu_crystal_primary_imagegen_pose_b_alpha.png",
}
SOURCE_SHA256 = {
    "pose_a": "7414b58179ef548a099b7338e1b4190cff87da362682237985f2df2b0f43b9cd",
    "pose_b": "05556b8dcf9cc5cf91f6c99530c0b21e7cf24fcce77e6264251303782f49e217",
}
SIZE = (56, 56)
TRANSPARENT = (0, 0, 0, 0)
NORMAL = (
    (0, 0, 0, 255),
    (75, 35, 27, 255),
    (217, 84, 46, 255),
    (248, 184, 0, 255),
    (248, 232, 208, 255),
)
SHINY = (
    (20, 28, 38, 255),
    (40, 51, 66, 255),
    (99, 112, 127, 255),
    (244, 155, 33, 255),
    (255, 224, 173, 255),
)
SHINY_MAP = dict(zip(NORMAL, SHINY))

# Two authored logical poses plus small detached charge clusters form the
# six-frame cadence.  Body/tail geometry is never globally translated.
FRAME_PLAN = (
    ("a", ()),
    ("a", ((4, 23, 3), (5, 22, 4))),
    ("b", ((3, 20, 3),)),
    ("b", ((2, 18, 3), (3, 17, 4), (49, 8, 3), (50, 9, 4))),
    ("b", ((47, 6, 3), (48, 7, 4))),
    ("a", ((51, 12, 3),)),
)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def nearest_colour(pixel: tuple[int, int, int, int]) -> tuple[int, int, int, int]:
    red, green, blue, _ = pixel
    return min(
        NORMAL,
        key=lambda colour: (red - colour[0]) ** 2
        + (green - colour[1]) ** 2
        + (blue - colour[2]) ** 2,
    )


def logical_pose(path: Path) -> Image.Image:
    source = Image.open(path).convert("RGBA")
    bounds = source.getchannel("A").getbbox()
    if bounds is None:
        raise ValueError(f"empty source: {path}")
    crop = source.crop(bounds)
    scale = min(54 / crop.width, 54 / crop.height)
    target_size = (
        max(1, round(crop.width * scale)),
        max(1, round(crop.height * scale)),
    )
    sampled = crop.resize(target_size, Image.Resampling.LANCZOS)
    reduced = Image.new("RGBA", target_size, TRANSPARENT)
    for y in range(sampled.height):
        for x in range(sampled.width):
            pixel = sampled.getpixel((x, y))
            if pixel[3] >= 96:
                reduced.putpixel((x, y), nearest_colour(pixel))
    output = Image.new("RGBA", SIZE, TRANSPARENT)
    output.alpha_composite(reduced, ((56 - target_size[0]) // 2, 56 - target_size[1]))
    return output


def add_charge(base: Image.Image, specs: tuple[tuple[int, int, int], ...]) -> Image.Image:
    output = base.copy()
    for x, y, palette_index in specs:
        if not (1 <= x <= 54 and 1 <= y <= 54):
            raise ValueError(f"charge outside safe canvas at {(x, y)}")
        if output.getpixel((x, y))[3]:
            raise ValueError(f"charge overlaps Gorochu at {(x, y)}")
        output.putpixel((x, y), NORMAL[palette_index])
    return output


def recolour(image: Image.Image) -> Image.Image:
    output = Image.new("RGBA", SIZE, TRANSPARENT)
    for y in range(56):
        for x in range(56):
            pixel = image.getpixel((x, y))
            if pixel[3]:
                output.putpixel((x, y), SHINY_MAP[pixel])
    return output


def frames() -> dict[str, list[Image.Image]]:
    for name, path in SOURCE_FILES.items():
        actual = sha256(path)
        if actual != SOURCE_SHA256[name]:
            raise ValueError(f"{path}: expected {SOURCE_SHA256[name]}, got {actual}")
    poses = {
        "a": logical_pose(SOURCE_FILES["pose_a"]),
        "b": logical_pose(SOURCE_FILES["pose_b"]),
    }
    normal = [add_charge(poses[pose], charge) for pose, charge in FRAME_PLAN]
    shiny = [recolour(frame) for frame in normal]
    return {"normal": normal, "shiny": shiny}


def write_png(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, "PNG", optimize=False, compress_level=9)


def write_contact(matrix: dict[str, list[Image.Image]], path: Path) -> None:
    scale, margin, label = 6, 12, 22
    cell = 56 * scale
    sheet = Image.new("RGBA", (margin * 2 + cell * 6, margin * 2 + (cell + label) * 2), (242, 242, 242, 255))
    draw = ImageDraw.Draw(sheet)
    for row, variant in enumerate(("normal", "shiny")):
        top = margin + row * (cell + label)
        draw.text((margin, top + 4), f"56PX CRYSTAL PRIMARY {variant.upper()}", fill=(0, 0, 0, 255))
        sprite_top = top + label
        for column, frame in enumerate(matrix[variant]):
            left = margin + column * cell
            draw.rectangle((left, sprite_top, left + cell - 1, sprite_top + cell - 1), fill=(220, 220, 220, 255))
            sheet.alpha_composite(frame.resize((cell, cell), Image.Resampling.NEAREST), (left, sprite_top))
            draw.text((left + 4, sprite_top + 4), f"{column + 1:03d}", fill=(0, 0, 0, 255))
    path.parent.mkdir(parents=True, exist_ok=True)
    sheet.convert("RGB").save(path, "PNG", optimize=False, compress_level=9)


def build(output_root: Path, contact_sheet: Path | None = None) -> list[Path]:
    matrix = frames()
    written = []
    for variant in ("normal", "shiny"):
        target = output_root / f"assets/voxel/gorochu/crystal/{variant}"
        target.mkdir(parents=True, exist_ok=True)
        for stale in target.glob("*.png"):
            stale.unlink()
        for index, frame in enumerate(matrix[variant], 1):
            path = target / f"{index:03d}.png"
            write_png(frame, path)
            written.append(path)
    if contact_sheet:
        write_contact(matrix, contact_sheet)
    return written


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-root", type=Path, default=ROOT)
    parser.add_argument("--contact-sheet", type=Path)
    args = parser.parse_args()
    written = build(args.output_root.resolve(), args.contact_sheet.resolve() if args.contact_sheet else None)
    digest = hashlib.sha256("".join(sha256(path) for path in sorted(written)).encode()).hexdigest()
    print(f"Built {len(written)} Gorochu 56 px Voxel Crystal primary frames; digest {digest}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
