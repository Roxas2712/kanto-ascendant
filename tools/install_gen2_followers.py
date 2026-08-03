#!/usr/bin/env python3
"""Install species-accurate Gen-2-style Johto follower sheets.

The source sheets come from PokeWilds and contain six 16x16 poses in a
96x16 row. Kanto Ascendant converts them into Gen1 Recomp's 16x96 layout on
first use and shares that derived sheet between the 2D and voxel renderers.
"""

from __future__ import annotations

import argparse
import tempfile
import urllib.request
from pathlib import Path

from install_crystal_sprites import SPECIES, png_size

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "assets" / "followers"
BASE = (
    "https://raw.githubusercontent.com/SheerSt/pokewilds/main/"
    "pokemon/pokemon/{name}/{filename}"
)
PROJECT = "https://github.com/SheerSt/pokewilds"


def fetch(name: str, shiny: bool) -> bytes:
    filename = "overworld-shiny.png" if shiny else "overworld.png"
    url = BASE.format(name=name, filename=filename)
    request = urllib.request.Request(
        url,
        headers={
            "User-Agent": "kanto-ascendant-gen2-follower-installer/1.0",
            "Referer": PROJECT,
        },
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        body = response.read()
    width, height = png_size(body)
    if (width, height) != (96, 16):
        raise ValueError(
            f"{name}: expected a 96x16 six-frame sheet, got {width}x{height}"
        )
    return body


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Download Gen-2-style follower sheets for Johto #152-251."
    )
    parser.add_argument(
        "--force", action="store_true", help="replace already installed files"
    )
    args = parser.parse_args()

    DEST.mkdir(parents=True, exist_ok=True)
    (DEST / "shiny").mkdir(parents=True, exist_ok=True)
    installed = 0
    for crystal_name in SPECIES:
        name = crystal_name.replace("-", "_")
        if name == "unown":
            print(
                "use Crystal normal/shiny front sprites for the floating "
                "Unown follower"
            )
            continue
        for shiny in (False, True):
            directory = DEST / "shiny" if shiny else DEST
            target = directory / f"{name}.png"
            if target.exists() and not args.force:
                print(f"keep {target.relative_to(ROOT)}")
                continue
            body = fetch(name, shiny)
            with tempfile.NamedTemporaryFile(
                dir=directory, prefix=".download-", suffix=".png", delete=False
            ) as handle:
                handle.write(body)
                temp = Path(handle.name)
            temp.replace(target)
            print(f"installed {target.relative_to(ROOT)} (96x16)")
            installed += 1

    print(
        f"Gen-2 follower install complete ({installed} downloaded). "
        "Restart the game after changing assets."
    )
    print(f"Sprite source and contributor credits: {PROJECT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
