#!/usr/bin/env python3
"""Build renderer-ready 16x96 Johto follower sheets for release packages."""

from __future__ import annotations

from collections import deque
from pathlib import Path

from PIL import Image

from install_crystal_sprites import SPECIES


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets" / "followers"
CRYSTAL = ROOT / "assets" / "crystal"
DEST = ROOT / "assets" / "followers_runtime"
FOLLOWER_ORDER = (4, 2, 0, 5, 3, 1)


def clear_connected_background(source: Image.Image) -> Image.Image:
    image = source.convert("RGBA")
    pixels = image.load()
    width, height = image.size
    background = pixels[0, 0]
    queue: deque[tuple[int, int]] = deque()
    visited: set[tuple[int, int]] = set()

    for x in range(width):
        queue.append((x, 0))
        queue.append((x, height - 1))
    for y in range(height):
        queue.append((0, y))
        queue.append((width - 1, y))

    while queue:
        x, y = queue.popleft()
        if (x, y) in visited or pixels[x, y] != background:
            continue
        visited.add((x, y))
        pixels[x, y] = (0, 0, 0, 0)
        if x > 0:
            queue.append((x - 1, y))
        if x + 1 < width:
            queue.append((x + 1, y))
        if y > 0:
            queue.append((x, y - 1))
        if y + 1 < height:
            queue.append((x, y + 1))
    return image


def horizontal_sheet(source: Path) -> Image.Image:
    with Image.open(source) as opened:
        image = opened.convert("RGBA")
    if image.size != (96, 16):
        raise ValueError(f"{source}: expected 96x16, got {image.size}")
    output = Image.new("RGBA", (16, 96), (0, 0, 0, 0))
    for target_frame, source_frame in enumerate(FOLLOWER_ORDER):
        frame = image.crop((source_frame * 16, 0, source_frame * 16 + 16, 16))
        output.paste(frame, (0, target_frame * 16))
    return output


def unown_sheet(source: Path) -> Image.Image:
    with Image.open(source) as opened:
        image = clear_connected_background(opened)
    alpha = image.getchannel("A")
    bounds = alpha.getbbox()
    if not bounds:
        raise ValueError(f"{source}: empty Unown image")
    icon = image.crop(bounds)
    scale = min(14 / icon.width, 14 / icon.height)
    size = (
        max(1, round(icon.width * scale)),
        max(1, round(icon.height * scale)),
    )
    icon = icon.resize(size, Image.Resampling.NEAREST)
    frame = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    frame.alpha_composite(icon, ((16 - icon.width) // 2, 16 - icon.height))
    output = Image.new("RGBA", (16, 96), (0, 0, 0, 0))
    for index in range(6):
        output.alpha_composite(frame, (0, index * 16))
    return output


def main() -> int:
    written = 0
    for shiny in (False, True):
        variant = "shiny" if shiny else "normal"
        target_dir = DEST / variant
        target_dir.mkdir(parents=True, exist_ok=True)
        for crystal_name in SPECIES:
            species = crystal_name.replace("-", "_")
            if species == "unown":
                suffix = "_front_shiny.png" if shiny else "_front.png"
                image = unown_sheet(CRYSTAL / f"unown{suffix}")
            else:
                directory = SOURCE / "shiny" if shiny else SOURCE
                image = horizontal_sheet(directory / f"{species}.png")
            target = target_dir / f"follower_{species.upper()}.png"
            image.save(target, format="PNG", compress_level=9)
            written += 1
    print(f"Built {written} renderer-ready follower sheets in {DEST}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
