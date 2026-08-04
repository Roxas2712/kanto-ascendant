#!/usr/bin/env python3
"""Install authentic Crystal player-side sprites for Kanto #001-151.

PokeAPI mirrors Crystal's native 48x48 back sprites on an opaque background.
The release assets are edge-keyed to transparency and placed on the same
56x56 battle canvas as Kanto Ascendant's bundled Johto back sprites.
"""

from __future__ import annotations

import argparse
import io
import tempfile
import urllib.request
from collections import deque
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "assets" / "crystal" / "kanto"
BASE = (
    "https://raw.githubusercontent.com/PokeAPI/sprites/master/"
    "sprites/pokemon/versions/generation-ii/crystal/back"
)


def fetch(dex: int, shiny: bool) -> bytes:
    variant = "shiny/" if shiny else ""
    request = urllib.request.Request(
        f"{BASE}/{variant}{dex}.png",
        headers={"User-Agent": "kanto-ascendant-crystal-backs/1.0"},
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        body = response.read()
    if not body.startswith(b"\x89PNG\r\n\x1a\n"):
        raise ValueError(f"Crystal #{dex:03d} response is not a PNG")
    return body


def clear_connected_background(image: Image.Image) -> Image.Image:
    image = image.convert("RGBA")
    pixels = image.load()
    background = pixels[0, 0]
    queue: deque[tuple[int, int]] = deque()
    visited: set[tuple[int, int]] = set()

    for x in range(image.width):
        queue.append((x, 0))
        queue.append((x, image.height - 1))
    for y in range(image.height):
        queue.append((0, y))
        queue.append((image.width - 1, y))

    while queue:
        x, y = queue.popleft()
        if (x, y) in visited or pixels[x, y] != background:
            continue
        visited.add((x, y))
        pixels[x, y] = (0, 0, 0, 0)
        if x > 0:
            queue.append((x - 1, y))
        if x + 1 < image.width:
            queue.append((x + 1, y))
        if y > 0:
            queue.append((x, y - 1))
        if y + 1 < image.height:
            queue.append((x, y + 1))
    return image


def prepare(body: bytes, dex: int) -> Image.Image:
    with Image.open(io.BytesIO(body)) as source:
        image = clear_connected_background(source)
    if image.size != (48, 48):
        raise ValueError(
            f"Crystal #{dex:03d} has unexpected dimensions {image.size}"
        )
    if image.getbbox() is None:
        raise ValueError(f"Crystal #{dex:03d} is fully transparent")

    canvas = Image.new("RGBA", (56, 56), (0, 0, 0, 0))
    canvas.alpha_composite(image, (4, 8))
    return canvas


def validate(path: Path) -> None:
    with Image.open(path) as image:
        if image.size != (56, 56) or image.mode != "RGBA":
            raise ValueError(
                f"{path.relative_to(ROOT)} must be a transparent 56x56 RGBA PNG"
            )
        if image.getbbox() is None:
            raise ValueError(f"{path.relative_to(ROOT)} is fully transparent")


def install(target: Path, image: Image.Image) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(
        dir=target.parent, prefix=".download-", suffix=".png", delete=False
    ) as handle:
        temporary = Path(handle.name)
    try:
        image.save(temporary, format="PNG", optimize=True)
        validate(temporary)
        temporary.replace(target)
    finally:
        if temporary.exists():
            temporary.unlink()


def main() -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Download and normalize Crystal normal/shiny Kanto back sprites."
        )
    )
    parser.add_argument(
        "--force", action="store_true", help="replace already installed files"
    )
    args = parser.parse_args()

    downloaded = 0
    for dex in range(1, 152):
        for shiny in (False, True):
            suffix = "_back_shiny.png" if shiny else "_back.png"
            target = DEST / f"{dex:03d}{suffix}"
            if target.exists() and not args.force:
                validate(target)
                continue
            install(target, prepare(fetch(dex, shiny), dex))
            downloaded += 1
            print(f"installed {target.relative_to(ROOT)}")

    print(
        "Kanto Crystal back-sprite install complete "
        f"({downloaded} downloaded, 302 validated)."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
