#!/usr/bin/env python3
"""Build Gorochu's six-pose walker from Ascendant's bundled Raichu base.

The Raichu-derived silhouette keeps the same grounding, direction readability
and gait timing as the Kanto follower family.  Gorochu remains recognizable
through its red-orange/slate palettes, central horn and dark back markings.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
RAICHU = ROOT / "assets" / "followers_kanto" / "follower_026.png"
SOURCE_NORMAL = ROOT / "assets" / "followers" / "gorochu.png"
SOURCE_SHINY = ROOT / "assets" / "followers" / "shiny" / "gorochu.png"
RUNTIME_NORMAL = (
    ROOT / "assets" / "followers_runtime" / "normal" / "follower_GOROCHU.png"
)
RUNTIME_SHINY = (
    ROOT / "assets" / "followers_runtime" / "shiny" / "follower_GOROCHU.png"
)

RAICHU_INK = (0, 0, 0, 255)
RAICHU_BODY = (234, 119, 60, 255)
RAICHU_ACCENT = (247, 226, 104, 255)

NORMAL = {
    RAICHU_INK: (58, 35, 32, 255),
    RAICHU_BODY: (232, 74, 38, 255),
    RAICHU_ACCENT: (255, 170, 43, 255),
}
SHINY = {
    RAICHU_INK: (29, 38, 52, 255),
    RAICHU_BODY: (80, 96, 120, 255),
    RAICHU_ACCENT: (255, 170, 43, 255),
}
CREAM = (255, 230, 184, 255)

# Runtime sheet order is down, up, side, then the alternate gait pose for
# those directions.  Each overlay uses only the mapped palette plus cream.
HORNS = {
    0: ((7, 0, "accent"), (7, 1, "ink"), (8, 1, "ink"),
        (7, 2, "ink"), (8, 2, "ink"), (7, 3, "ink"), (8, 3, "ink")),
    1: ((7, 0, "accent"), (7, 1, "ink"), (8, 1, "ink"),
        (7, 2, "ink"), (8, 2, "ink"), (7, 3, "ink"), (8, 3, "ink")),
    2: ((6, 1, "accent"), (6, 2, "ink"), (7, 2, "ink"),
        (5, 3, "ink"), (6, 3, "ink"), (7, 3, "ink")),
    3: ((7, 1, "accent"), (7, 2, "ink"), (8, 2, "ink"),
        (7, 3, "ink"), (8, 3, "ink"), (7, 4, "ink"), (8, 4, "ink")),
    4: ((7, 1, "accent"), (7, 2, "ink"), (8, 2, "ink"),
        (7, 3, "ink"), (8, 3, "ink"), (7, 4, "ink"), (8, 4, "ink")),
    5: ((6, 2, "accent"), (6, 3, "ink"), (7, 3, "ink"),
        (5, 4, "ink"), (6, 4, "ink"), (7, 4, "ink")),
}

BACK_MARKINGS = {
    1: ((7, 7), (8, 8), (7, 9), (8, 10)),
    2: ((7, 8), (8, 9), (7, 10)),
    4: ((7, 8), (8, 9), (7, 10), (8, 11)),
    5: ((7, 9), (8, 10), (7, 11)),
}

# build_follower_runtime_assets.py converts this historic horizontal source
# order back to runtime order with (4, 2, 0, 5, 3, 1).
HORIZONTAL_FROM_RUNTIME = (2, 5, 1, 4, 0, 3)


def recolor(frame: Image.Image, palette: dict[tuple[int, ...], tuple[int, ...]]) -> Image.Image:
    out = Image.new("RGBA", frame.size, (0, 0, 0, 0))
    for y in range(frame.height):
        for x in range(frame.width):
            value = frame.getpixel((x, y))
            out.putpixel((x, y), palette.get(value, value))
    return out


def cream_belly(frame: Image.Image, index: int, accent: tuple[int, ...]) -> None:
    for y in range(16):
        for x in range(16):
            if frame.getpixel((x, y)) != accent:
                continue
            front = index in (0, 3) and y >= 9 and 3 <= x <= 12
            side = index in (2, 5) and y >= 10 and x <= 8
            if front or side:
                frame.putpixel((x, y), CREAM)


def build_variant(base: Image.Image, palette: dict[tuple[int, ...], tuple[int, ...]]) -> Image.Image:
    runtime = Image.new("RGBA", (16, 96), (0, 0, 0, 0))
    for index in range(6):
        source = base.crop((0, index * 16, 16, index * 16 + 16))
        frame = recolor(source, palette)
        cream_belly(frame, index, palette[RAICHU_ACCENT])
        for x, y, role in HORNS[index]:
            frame.putpixel((x, y), palette[RAICHU_ACCENT]
                           if role == "accent" else palette[RAICHU_INK])
        for x, y in BACK_MARKINGS.get(index, ()):
            frame.putpixel((x, y), palette[RAICHU_INK])
        runtime.alpha_composite(frame, (0, index * 16))
    return runtime


def horizontal(runtime: Image.Image) -> Image.Image:
    sheet = Image.new("RGBA", (96, 16), (0, 0, 0, 0))
    for target, source in enumerate(HORIZONTAL_FROM_RUNTIME):
        frame = runtime.crop((0, source * 16, 16, source * 16 + 16))
        sheet.alpha_composite(frame, (target * 16, 0))
    return sheet


def save(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, format="PNG", compress_level=9)


def main() -> int:
    with Image.open(RAICHU) as opened:
        base = opened.convert("RGBA")
    if base.size != (16, 96):
        raise ValueError(f"{RAICHU}: expected 16x96, got {base.size}")
    normal = build_variant(base, NORMAL)
    shiny = build_variant(base, SHINY)
    save(normal, RUNTIME_NORMAL)
    save(shiny, RUNTIME_SHINY)
    save(horizontal(normal), SOURCE_NORMAL)
    save(horizontal(shiny), SOURCE_SHINY)
    print("Built Raichu-derived Gorochu normal/shiny source and runtime walkers")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
