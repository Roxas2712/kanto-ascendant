#!/usr/bin/env python3
"""Validate and normalize the bundled Johto sprite packages.

Crystal sheets arrive on an opaque color-0 battle background. Converting only
the edge-connected background to transparent pixels preserves the sprite while
making every renderer consume the same release asset directly.
"""

from __future__ import annotations

from collections import deque
from pathlib import Path

from PIL import Image

from install_crystal_sprites import SPECIES, VIEWS


ROOT = Path(__file__).resolve().parents[1]
CRYSTAL = ROOT / "assets" / "crystal"
FOLLOWERS = ROOT / "assets" / "followers"


def normalize_crystal(path: Path) -> None:
    with Image.open(path) as source:
        image = source.convert("RGBA")
    width, height = image.size
    if not (16 <= width <= 128 and 16 <= height <= 128):
        raise ValueError(f"{path}: unexpected Crystal size {width}x{height}")

    pixels = image.load()
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

    image.save(path, format="PNG", optimize=True)


def validate_follower(path: Path) -> None:
    with Image.open(path) as image:
        if image.size != (96, 16):
            raise ValueError(f"{path}: expected 96x16, got {image.size}")


def main() -> int:
    crystal_paths = []
    follower_paths = []
    for crystal_name in SPECIES:
        stem = crystal_name.replace("-", "_")
        for view in VIEWS:
            crystal_paths.append(CRYSTAL / f"{stem}_{view}.png")
        if stem != "unown":
            follower_paths.extend((
                FOLLOWERS / f"{stem}.png",
                FOLLOWERS / "shiny" / f"{stem}.png",
            ))

    missing = [
        path.relative_to(ROOT)
        for path in crystal_paths + follower_paths
        if not path.is_file()
    ]
    if missing:
        raise FileNotFoundError(
            "missing bundled sprites:\n" + "\n".join(map(str, missing))
        )

    for path in crystal_paths:
        normalize_crystal(path)
    for path in follower_paths:
        validate_follower(path)

    print(
        f"Bundled sprite QA PASS: {len(crystal_paths)} Crystal + "
        f"{len(follower_paths)} follower PNGs"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
