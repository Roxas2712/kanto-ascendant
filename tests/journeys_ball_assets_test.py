#!/usr/bin/env python3
"""Integrity/provenance test for imported user-local Journeys Ball art."""

from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
INV = ROOT / "docs" / "JOURNEYS_BALL_ASSET_INVENTORY.json"
EXPECTED = {
    "POKE_BALL": 0, "GREAT_BALL": 1, "ULTRA_BALL": 2,
    "MASTER_BALL": 3, "SAFARI_BALL": 4, "FAST_BALL": 17,
    "LEVEL_BALL": 18, "LURE_BALL": 19, "HEAVY_BALL": 20,
    "LOVE_BALL": 21, "FRIEND_BALL": 22, "MOON_BALL": 23,
}


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def png_dimensions(path: Path) -> tuple[int, int]:
    data = path.read_bytes()
    assert data[:8] == b"\x89PNG\r\n\x1a\n" and data[12:16] == b"IHDR"
    return int.from_bytes(data[16:20], "big"), int.from_bytes(data[20:24], "big")


inventory = json.loads(INV.read_text())
assert inventory["format"] == 1
assert "Pokemon Journeys V18" in inventory["source_root"]
source_root = os.environ.get("KASC_JOURNEYS_SOURCE")
rows = {row["item"]: row for row in inventory["balls"]}
assert set(rows) == set(EXPECTED)

for item, index in EXPECTED.items():
    row = rows[item]
    assert row["journeys_ball_index"] == index
    files = {file["role"]: file for file in row["files"]}
    assert set(files) == {"closed_sheet", "open_master"}
    for role, expected_size in (("closed_sheet", (256, 64)), ("open_master", (32, 64))):
        file = files[role]
        runtime = ROOT / file["runtime"]
        assert runtime.is_file(), f"missing runtime asset {runtime}"
        assert png_dimensions(runtime) == expected_size
        assert sha(runtime) == file["sha256"], f"hash drift for {item} {role}"
        assert not Path(file["source"]).is_absolute(), "provenance path must be portable"
        if source_root:
            source = Path(source_root) / file["source"]
            assert source.is_file(), f"missing recorded source {source}"
            assert sha(source) == file["sha256"], f"source hash drift for {item} {role}"

        # Runtime paths are checked-in copies; the source location belongs in
        # provenance only, never in runtime Lua.
        assert "/Downloads/" not in file["runtime"]

    # The closed Journeys master is a real eight-phase sequence.  This guards
    # against the former frozen-frame integration and its false inventory note.
    with Image.open(ROOT / files["closed_sheet"]["runtime"]) as sheet:
        phases = [
            sheet.convert("RGBA").crop((i * 32, 0, (i + 1) * 32, 64)).tobytes()
            for i in range(8)
        ]
        assert len(set(phases)) == 8, f"{item} does not expose 8 distinct phases"

print("journeys_ball_assets_test: PASS (12 balls, 24 hash-verified masters, 96 distinct phases)")
