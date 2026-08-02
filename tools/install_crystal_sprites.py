#!/usr/bin/env python3
"""Install optional Pokémon Crystal battle sprites from Pokémon Database.

Pokémon Database asks users to save images instead of hotlinking them. This
tool does exactly that for a personal installation. The downloaded game art is
deliberately excluded from source/release archives; the original four-shade
sprites remain the distributable fallback.
"""

from __future__ import annotations

import argparse
import struct
import tempfile
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "assets" / "crystal"
BASE = "https://img.pokemondb.net/sprites/crystal"
SPECIES = ("raikou", "entei", "suicune", "lugia", "ho-oh", "celebi")
VIEWS = {
    "front": "normal/{name}.png",
    "back": "back-normal/{name}.png",
}


def png_size(body: bytes) -> tuple[int, int]:
    if not body.startswith(b"\x89PNG\r\n\x1a\n") or len(body) < 24:
        raise ValueError("response is not a PNG")
    return struct.unpack(">II", body[16:24])


def fetch(url: str, page: str) -> bytes:
    request = urllib.request.Request(
        url,
        headers={
            "User-Agent": "kanto-ascendant-crystal-installer/1.0",
            "Referer": page,
        },
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        body = response.read()
    width, height = png_size(body)
    if not (16 <= width <= 128 and 16 <= height <= 128):
        raise ValueError(f"unexpected sprite dimensions {width}x{height}")
    return body


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Download optional Crystal front/back sprites for the six legends."
    )
    parser.add_argument(
        "--force", action="store_true", help="replace already installed files"
    )
    args = parser.parse_args()

    DEST.mkdir(parents=True, exist_ok=True)
    installed = 0
    for name in SPECIES:
        page = f"https://pokemondb.net/sprites/{name}"
        local_name = name.replace("-", "_")
        for view, pattern in VIEWS.items():
            target = DEST / f"{local_name}_{view}.png"
            if target.exists() and not args.force:
                print(f"keep {target.relative_to(ROOT)}")
                continue
            url = f"{BASE}/{pattern.format(name=name)}"
            body = fetch(url, page)
            # Atomic replacement: an interrupted request never leaves a
            # truncated PNG for the engine to load at the next boot.
            with tempfile.NamedTemporaryFile(
                dir=DEST, prefix=".download-", suffix=".png", delete=False
            ) as handle:
                handle.write(body)
                temp = Path(handle.name)
            temp.replace(target)
            width, height = png_size(body)
            print(f"installed {target.relative_to(ROOT)} ({width}x{height})")
            installed += 1

    print(
        f"Crystal sprite install complete ({installed} downloaded). "
        "Restart the game after changing assets."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
