#!/usr/bin/env python3
"""Import approved local Journeys Ball masters into the mod runtime tree.

No runtime code reads Downloads. This importer copies only the twelve ball
masters used by Ascendant and their matching open poses, then writes a
machine-readable source/hash inventory next to the release documentation.
"""

from __future__ import annotations

import hashlib
import json
import os
import shutil
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path(os.environ.get("KASC_JOURNEYS_SOURCE", "Pokemon Journeys V18"))
SOURCE_DIR = SOURCE / "Graphics" / "Battle animations"
DEST = ROOT / "assets" / "journeys_balls"
INVENTORY = ROOT / "docs" / "JOURNEYS_BALL_ASSET_INVENTORY.json"

# Pokemon Essentials/Journeys ball sheets: 0..4 are the five regular balls,
# 17..23 are Fast through Moon in the supplied PBS item ordering.
BALLS = {
    "POKE_BALL": 0,
    "GREAT_BALL": 1,
    "ULTRA_BALL": 2,
    "MASTER_BALL": 3,
    "SAFARI_BALL": 4,
    "FAST_BALL": 17,
    "LEVEL_BALL": 18,
    "LURE_BALL": 19,
    "HEAVY_BALL": 20,
    "LOVE_BALL": 21,
    "FRIEND_BALL": 22,
    "MOON_BALL": 23,
}


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def png_dimensions(path: Path) -> tuple[int, int]:
    # PNG IHDR starts at bytes 16..24; no third-party dependency required.
    raw = path.read_bytes()
    if raw[:8] != b"\x89PNG\r\n\x1a\n" or raw[12:16] != b"IHDR":
        raise ValueError(f"not a PNG with IHDR: {path}")
    return int.from_bytes(raw[16:20], "big"), int.from_bytes(raw[20:24], "big")


def main() -> None:
    if not SOURCE_DIR.is_dir():
        raise SystemExit(f"Journeys source directory missing: {SOURCE_DIR}")
    DEST.mkdir(parents=True, exist_ok=True)
    rows = []
    for item, index in BALLS.items():
        files = []
        for suffix, role, expected in (("", "closed_sheet", (256, 64)),
                                       ("_open", "open_master", (32, 64))):
            source = SOURCE_DIR / f"ball_{index:02d}{suffix}.png"
            if not source.is_file():
                raise SystemExit(f"missing required Journeys {role}: {source}")
            dimensions = png_dimensions(source)
            if dimensions != expected:
                raise SystemExit(f"unexpected {role} dimensions {dimensions}: {source}")
            target = DEST / f"{item.lower()}{suffix}.png"
            shutil.copy2(source, target)
            if digest(source) != digest(target):
                raise SystemExit(f"copy hash mismatch: {source} -> {target}")
            files.append({
                "role": role,
                "source": str(source.relative_to(SOURCE)),
                "runtime": str(target.relative_to(ROOT)),
                "sha256": digest(source),
                "width": dimensions[0],
                "height": dimensions[1],
            })
        rows.append({ "item": item, "journeys_ball_index": index, "files": files })
    INVENTORY.write_text(json.dumps({
        "format": 1,
        "provenance": "user-local Pokemon Journeys V18 / Pokemon Essentials graphics",
        "source_root": SOURCE.name,
        "notes": [
            "closed sheets have eight authored, distinct 32x64 animation phases",
            "runtime uses only copied assets under assets/journeys_balls and never reads Downloads",
        ],
        "balls": rows,
    }, indent=2) + "\n")


if __name__ == "__main__":
    main()
